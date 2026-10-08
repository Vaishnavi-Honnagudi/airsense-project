"""
Adds time-based and rolling-average features to the cleaned Delhi dataset,
in preparation for the LSTM forecasting model (Weeks 3-4 of the spec).

Run:
    python feature_engineering.py
"""

import pandas as pd

INPUT_PATH = "delhi_cleaned.csv"
OUTPUT_PATH = "delhi_features.csv"

df = pd.read_csv(INPUT_PATH, low_memory=False)
df["Datetime"] = pd.to_datetime(df["Datetime"])
df = df.sort_values(["StationId", "Datetime"])

# --- Time-based features ---
# Pollution has strong daily/weekly cycles (rush hour, weekends), so the
# model needs to know "what time is it" beyond just the raw pollutant values
df["hour"] = df["Datetime"].dt.hour
df["day_of_week"] = df["Datetime"].dt.dayofweek  # 0 = Monday, 6 = Sunday
df["month"] = df["Datetime"].dt.month
df["is_weekend"] = (df["day_of_week"] >= 5).astype(int)

# --- Rolling averages ---
# Smooths out sensor noise and captures short/medium-term trends.
# Grouped by StationId so one station's history never leaks into another's.
roll_cols = [c for c in ["PM2.5", "PM10", "NO2", "CO", "SO2", "O3", "AQI",
                          "Temperature_C", "Humidity_pct", "WindSpeed_kmh"]
             if c in df.columns]

for col in roll_cols:
    df[f"{col}_roll3h"] = df.groupby("StationId")[col].transform(
        lambda s: s.rolling(window=3, min_periods=1).mean()
    )
    df[f"{col}_roll24h"] = df.groupby("StationId")[col].transform(
        lambda s: s.rolling(window=24, min_periods=1).mean()
    )

df.to_csv(OUTPUT_PATH, index=False)

print(f"Done. {df.shape[0]} rows, {df.shape[1]} columns saved to {OUTPUT_PATH}")
print(f"Added {4 + len(roll_cols)*2} new feature columns:")
print(f"  Time features: hour, day_of_week, month, is_weekend")
print(f"  Rolling features (3h & 24h) for: {', '.join(roll_cols)}")
