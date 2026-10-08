"""
Weekly retraining pipeline for the AQI LSTM forecasting model.

Purpose: as new sensor data accumulates (e.g. from the live tracking
pipeline, once it has been running long enough to build proper 24-hour
sequences), this script fine-tunes the existing model on the new batch
rather than retraining from scratch - faster, and keeps what the model
already learned.

Expects:
  - A NEW_DATA_PATH CSV with the SAME columns as delhi_features.csv
    (i.e. already cleaned + feature-engineered, but NOT yet scaled -
    real units, same as delhi_features.csv).
  - The existing trained model (aqi_lstm_model.keras) and the
    ORIGINAL scaler (scaler.pkl) - the new data is scaled using the
    EXISTING scaler (transform, not fit_transform), so old and new
    data stay on the same scale.

Run this whenever a new batch of labeled data is ready (weekly, or
whenever there's enough new data to be worth a retrain).
"""

import os
import pickle
import shutil
from datetime import datetime

import numpy as np
import pandas as pd
import tensorflow as tf

BASE_PATH = "."  # adjust to your Drive/folder path when running
MODEL_PATH = os.path.join(BASE_PATH, "aqi_lstm_model.keras")
SCALER_PATH = os.path.join(BASE_PATH, "scaler.pkl")
NEW_DATA_PATH = os.path.join(BASE_PATH, "new_data_batch.csv")  # <-- point this at your new data
TEST_DATA_PATH = os.path.join(BASE_PATH, "delhi_test.csv")  # held-out set, for before/after comparison

IDENTITY_COLS = ["Datetime", "StationId", "AQI_Bucket", "StationName", "City", "State"]
SEQUENCE_LENGTH = 24
FINE_TUNE_EPOCHS = 5
FINE_TUNE_LR = 0.0001  # low learning rate - fine-tuning, not training from scratch

LOG_PATH = os.path.join(BASE_PATH, "retraining_log.csv")


def build_sequences(df, feature_cols, aqi_idx, seq_len=24):
    """Groups by station, builds (X, y) sequences: past seq_len hours -> next AQI value."""
    X_list, y_list = [], []
    for station_id, group in df.groupby("StationId"):
        group = group.sort_values("Datetime")
        values = group[feature_cols].values.astype("float32")
        if len(values) <= seq_len:
            continue
        for i in range(len(values) - seq_len):
            X_list.append(values[i:i + seq_len])
            y_list.append(values[i + seq_len, aqi_idx])
    return np.array(X_list), np.array(y_list)


def evaluate(model, X, y, scaler, feature_cols, aqi_idx):
    """Returns MAE and RMSE in real AQI units (unscaled)."""
    preds_scaled = model.predict(X, verbose=0).flatten()

    def unscale_aqi(vals):
        dummy = np.zeros((len(vals), len(feature_cols)))
        dummy[:, aqi_idx] = vals
        return scaler.inverse_transform(dummy)[:, aqi_idx]

    preds_real = unscale_aqi(preds_scaled)
    y_real = unscale_aqi(y)

    mae = float(np.mean(np.abs(preds_real - y_real)))
    rmse = float(np.sqrt(np.mean((preds_real - y_real) ** 2)))
    return mae, rmse


def main():
    print(f"=== Retraining run started: {datetime.now().isoformat()} ===")

    if not os.path.exists(NEW_DATA_PATH):
        print(f"No new data batch found at {NEW_DATA_PATH}. Nothing to retrain on. Exiting.")
        print("(This is expected until enough new live-tracked data has accumulated to build 24-hour sequences.)")
        return

    print("Loading existing model and scaler...")
    model = tf.keras.models.load_model(MODEL_PATH)
    with open(SCALER_PATH, "rb") as f:
        scaler = pickle.load(f)

    print("Loading new data batch...")
    new_df = pd.read_csv(NEW_DATA_PATH)
    feature_cols = [c for c in new_df.columns if c not in IDENTITY_COLS]
    aqi_idx = feature_cols.index("AQI")

    if len(feature_cols) != model.input_shape[-1]:
        raise ValueError(
            f"Column mismatch: new data has {len(feature_cols)} feature columns, "
            f"model expects {model.input_shape[-1]}. Check that new_data_batch.csv "
            f"has the same schema as delhi_features.csv."
        )

    # Scale new data using the EXISTING scaler - do not refit
    new_df_scaled = new_df.copy()
    new_df_scaled[feature_cols] = scaler.transform(new_df[feature_cols])

    X_new, y_new = build_sequences(new_df_scaled, feature_cols, aqi_idx, SEQUENCE_LENGTH)
    print(f"Built {len(X_new)} new training sequences from the new batch.")

    if len(X_new) == 0:
        print("Not enough new data to build even one 24-hour sequence per station. Exiting.")
        return

    # Load held-out test set for before/after comparison
    test_df = pd.read_csv(TEST_DATA_PATH)
    X_test, y_test = build_sequences(test_df, feature_cols, aqi_idx, SEQUENCE_LENGTH)

    print("Evaluating model BEFORE fine-tuning...")
    mae_before, rmse_before = evaluate(model, X_test, y_test, scaler, feature_cols, aqi_idx)
    print(f"  Before: MAE={mae_before:.2f}, RMSE={rmse_before:.2f}")

    print(f"Fine-tuning on new data for {FINE_TUNE_EPOCHS} epochs (lr={FINE_TUNE_LR})...")
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=FINE_TUNE_LR), loss="mse")
    model.fit(X_new, y_new, epochs=FINE_TUNE_EPOCHS, batch_size=64, verbose=1)

    print("Evaluating model AFTER fine-tuning...")
    mae_after, rmse_after = evaluate(model, X_test, y_test, scaler, feature_cols, aqi_idx)
    print(f"  After:  MAE={mae_after:.2f}, RMSE={rmse_after:.2f}")

    # Only save the new version if it didn't get meaningfully worse
    regressed = mae_after > mae_before * 1.10  # allow up to 10% wiggle room
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    if regressed:
        print(f"WARNING: model got noticeably worse after fine-tuning (MAE {mae_before:.2f} -> {mae_after:.2f}).")
        print("NOT overwriting the production model. Saving the fine-tuned version separately for inspection.")
        new_model_path = os.path.join(BASE_PATH, f"aqi_lstm_model_REJECTED_{timestamp}.keras")
        model.save(new_model_path)
    else:
        print("Fine-tuned model looks fine or improved - saving as the new production model.")
        versioned_path = os.path.join(BASE_PATH, f"aqi_lstm_model_{timestamp}.keras")
        model.save(versioned_path)
        # keep the "live" filename pointing at the latest good model, but preserve the old one too
        shutil.copy(MODEL_PATH, os.path.join(BASE_PATH, f"aqi_lstm_model_PREVIOUS_{timestamp}.keras"))
        model.save(MODEL_PATH)  # overwrite the live model
        print(f"Live model updated: {MODEL_PATH}")
        print(f"Previous version backed up as: aqi_lstm_model_PREVIOUS_{timestamp}.keras")

    # Log this run
    log_entry = pd.DataFrame([{
        "timestamp": datetime.now().isoformat(),
        "new_sequences_used": len(X_new),
        "mae_before": round(mae_before, 3),
        "mae_after": round(mae_after, 3),
        "rmse_before": round(rmse_before, 3),
        "rmse_after": round(rmse_after, 3),
        "accepted": not regressed
    }])
    if os.path.exists(LOG_PATH):
        log_entry.to_csv(LOG_PATH, mode="a", header=False, index=False)
    else:
        log_entry.to_csv(LOG_PATH, index=False)
    print(f"Logged this run to {LOG_PATH}")

    print(f"=== Retraining run finished: {datetime.now().isoformat()} ===")


if __name__ == "__main__":
    main()
