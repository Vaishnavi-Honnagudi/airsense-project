"""
Scales the features and splits the dataset chronologically into
train/test sets, ready for the LSTM model (Weeks 3-4).

Run:
    pip install scikit-learn   (if not already installed)
    python scale_and_split.py
"""

import pandas as pd
import pickle
from sklearn.preprocessing import MinMaxScaler

INPUT_PATH = "delhi_features.csv"
TRAIN_PATH = "delhi_train.csv"
TEST_PATH = "delhi_test.csv"
SCALER_PATH = "scaler.pkl"

df = pd.read_csv(INPUT_PATH, low_memory=False)
df["Datetime"] = pd.to_datetime(df["Datetime"])
df = df.sort_values("Datetime").reset_index(drop=True)

# --- Chronological split (80/20 by ROW COUNT, not calendar range) ---
# Note: the number of active Delhi stations grew a lot over the years
# (10 in 2015 -> 38 by 2018+), so splitting by calendar date alone gives
# an uneven row split. Splitting by row count instead gives a clean 80/20
# while still keeping strict time order (no shuffling, no future leakage).
split_idx = int(len(df) * 0.8)
cutoff_date = df["Datetime"].iloc[split_idx]

train = df[df["Datetime"] < cutoff_date].copy()
test = df[df["Datetime"] >= cutoff_date].copy()

print(f"Split cutoff: {cutoff_date}")
print(f"Train: {len(train)} rows ({len(train)/len(df)*100:.1f}%)")
print(f"Test:  {len(test)} rows ({len(test)/len(df)*100:.1f}%)")

# --- Identify which columns to scale ---
# Exclude pure identity/metadata columns - these aren't model inputs
exclude_cols = ["StationId", "StationName", "City", "State", "Datetime", "AQI_Bucket"]
feature_cols = [c for c in df.columns if c not in exclude_cols]

# --- Scale (fit ONLY on train, to avoid leaking test info into training) ---
scaler = MinMaxScaler()
train[feature_cols] = scaler.fit_transform(train[feature_cols])
test[feature_cols] = scaler.transform(test[feature_cols])

# Save the scaler - you'll need this later to convert model predictions
# back into real AQI values (e.g. 0.42 -> actual AQI of 187)
with open(SCALER_PATH, "wb") as f:
    pickle.dump(scaler, f)

train.to_csv(TRAIN_PATH, index=False)
test.to_csv(TEST_PATH, index=False)

print(f"\nSaved: {TRAIN_PATH}, {TEST_PATH}, and {SCALER_PATH} (needed to unscale predictions later)")
print(f"Scaled {len(feature_cols)} feature columns (excluded identity columns: {', '.join(exclude_cols)})")
