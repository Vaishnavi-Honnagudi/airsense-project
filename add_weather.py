"""
Fetches historical hourly weather for Delhi (temperature, humidity, wind,
pressure) via the free Meteostat library (v2 API), and merges it onto your
existing AQI + coordinates file by matching Datetime.

First install meteostat:
    pip install meteostat

Then run:
    python add_weather.py

Note: Delhi's AQI stations are all within the same metro area, so rather
than querying weather separately per station (slow + mostly redundant,
since Meteostat pulls from the same nearby real weather stations either
way), this fetches ONE central-Delhi weather series and applies it to
every station's rows for the matching hour.
"""

import pandas as pd
from meteostat import hourly, config

# Your date range is ~5.5 years, which exceeds meteostat's default 3-year
# safety limit for a single hourly request. Since this is a one-off
# historical pull (not something hammering their servers repeatedly),
# it's safe to disable that guard here.
config.block_large_requests = False

INPUT_PATH = "delhi_station_hour_with_coords.csv"
OUTPUT_PATH = "delhi_station_hour_with_weather.csv"

# Real weather station for Delhi (New Delhi / Safdarjung) - a Point()
# object silently returns nothing here, since meteostat's default
# provider only works with real station IDs, not geo-interpolated points
DELHI_STATION_ID = "42182"

df = pd.read_csv(INPUT_PATH)
df["Datetime"] = pd.to_datetime(df["Datetime"])

start = df["Datetime"].min()
end = df["Datetime"].max()
print(f"Fetching Delhi weather from {start} to {end} ...")

# meteostat v2: hourly() returns a TimeSeries object; .fetch() gives the DataFrame
ts = hourly(DELHI_STATION_ID, start, end, timezone="Asia/Kolkata")
weather = ts.fetch()

if weather is None or weather.empty:
    raise RuntimeError("No weather data returned - check your date range or internet connection.")

weather = weather.reset_index()  # turns the 'time' index into a normal column
weather = weather.rename(columns={"time": "Datetime"})

# Drop timezone info so it matches your AQI file's plain (tz-naive) timestamps
try:
    weather["Datetime"] = weather["Datetime"].dt.tz_localize(None)
except TypeError:
    pass  # already tz-naive

# Keep the columns most relevant to your project
cols_needed = [c for c in ["temp", "rhum", "wspd", "pres"] if c in weather.columns]
weather = weather[["Datetime"] + cols_needed]
weather = weather.rename(
    columns={
        "temp": "Temperature_C",
        "rhum": "Humidity_pct",
        "wspd": "WindSpeed_kmh",
        "pres": "Pressure_hPa",
    }
)

merged = df.merge(weather, on="Datetime", how="left")
matched_exact = merged["Temperature_C"].notna().mean() * 100

if matched_exact < 50:
    # India is UTC+5:30 - a half-hour offset. Weather data converts to
    # times like 05:30, 06:30 IST, while AQI readings are on the hour
    # (01:00, 02:00...), so an exact match fails almost entirely. Fix:
    # match each AQI row to the NEAREST weather reading within 45 min.
    print(f"Exact match only got {matched_exact:.1f}% - falling back to "
          f"nearest-time matching (expected, due to the UTC+5:30 offset)...")

    df_sorted = df.sort_values("Datetime")
    weather_sorted = weather.sort_values("Datetime")

    merged = pd.merge_asof(
        df_sorted, weather_sorted,
        on="Datetime", direction="nearest",
        tolerance=pd.Timedelta("45min"),
    )
    merged = merged.sort_values(["StationId", "Datetime"]).reset_index(drop=True)

merged.to_csv(OUTPUT_PATH, index=False)

matched = merged["Temperature_C"].notna().mean() * 100
print(f"Done. {merged.shape[0]} rows saved to {OUTPUT_PATH}")
print(f"{matched:.1f}% of rows got a matching weather reading.")
if matched < 90:
    print("Note: some hours may be missing weather data - Meteostat "
          "coverage can have gaps, especially in older years. You may "
          "want to interpolate these afterward.")