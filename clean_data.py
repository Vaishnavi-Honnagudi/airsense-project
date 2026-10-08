"""
Cleans the Delhi AQI + weather dataset:
  1. Fixes datetime type and sorts by station/time
  2. Drops Xylene (too sparse to use - ~90% missing)
  3. Interpolates missing pollutant/weather values per station (time-based)
  4. Removes duplicate (StationId, Datetime) rows, if any
  5. Caps AQI at 500 (India's official AQI scale max) and clips any
     negative pollutant/weather readings to 0 (sensor glitches)

Run:
    python clean_data.py
"""

import pandas as pd

INPUT_PATH = "delhi_station_hour_with_weather.csv"
OUTPUT_PATH = "delhi_cleaned.csv"

df = pd.read_csv(INPUT_PATH, low_memory=False)
before = len(df)

# --- Step 1: fix types & sort ---
df["Datetime"] = pd.to_datetime(df["Datetime"])
df = df.sort_values(["StationId", "Datetime"])

# --- Step 2: drop Xylene (too sparse) ---
if "Xylene" in df.columns:
    df = df.drop(columns=["Xylene"])
    print("Dropped Xylene column (too sparse to use).")

# Note: AQI_Bucket is kept in the file for reference, but should NOT be
# used as a model input feature - it's derived from AQI, so using it
# would be data leakage.

# --- Step 3: interpolate missing values, per station, over time ---
pollutant_cols = [c for c in ["PM2.5", "PM10", "NO", "NO2", "NOx", "NH3",
                               "CO", "SO2", "O3", "Benzene", "Toluene", "AQI"]
                   if c in df.columns]
weather_cols = [c for c in ["Temperature_C", "Humidity_pct",
                             "WindSpeed_kmh", "Pressure_hPa"]
                if c in df.columns]
interp_cols = pollutant_cols + weather_cols

def interpolate_station(group):
    group = group.set_index("Datetime")
    group[interp_cols] = group[interp_cols].interpolate(
        method="time", limit_direction="both"
    )
    return group.reset_index()

df = df.set_index("Datetime")
df[interp_cols] = df.groupby("StationId")[interp_cols].transform(
    lambda s: s.interpolate(method="time", limit_direction="both")
)
df = df.reset_index()

# --- Step 4: remove duplicates ---
dupes = df.duplicated(subset=["StationId", "Datetime"]).sum()
if dupes > 0:
    df = df.drop_duplicates(subset=["StationId", "Datetime"], keep="first")
    print(f"Removed {dupes} duplicate (StationId, Datetime) rows.")

# --- Step 5: handle outliers ---
# Cap AQI at 500 - India's official AQI scale max ("Severe+" category)
if "AQI" in df.columns:
    over_cap = (df["AQI"] > 500).sum()
    df["AQI"] = df["AQI"].clip(upper=500)
    if over_cap > 0:
        print(f"Capped {over_cap} rows where AQI exceeded 500.")

# Clip any negative readings to 0 (physically impossible, sensor glitches)
# - excludes Temperature, which can legitimately be negative
no_negative_cols = [c for c in interp_cols if c != "Temperature_C"]
for c in no_negative_cols:
    neg = (df[c] < 0).sum()
    if neg > 0:
        df[c] = df[c].clip(lower=0)
        print(f"Clipped {neg} negative values in {c} to 0.")

# --- Save ---
df.to_csv(OUTPUT_PATH, index=False)

after = len(df)
print(f"\nDone. {before} rows -> {after} rows saved to {OUTPUT_PATH}")
print("\nRemaining missing values (%):")
print((df[interp_cols].isna().mean() * 100).round(1))
