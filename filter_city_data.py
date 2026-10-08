"""
Filters station_hour.csv down to one city's stations and merges in
station metadata (name, city, state) from stations.csv.

Usage:
    python filter_city_data.py

Just change CITY_NAME below to pull a different city.
"""

import pandas as pd

CITY_NAME = "Delhi"  # change this to any city in stations.csv

STATION_HOUR_PATH = "station_hour.csv"
STATIONS_PATH = "stations.csv"
OUTPUT_PATH = f"{CITY_NAME.lower()}_station_hour.csv"

# Load station metadata (StationId, StationName, City, State, Status)
stations = pd.read_csv(STATIONS_PATH)

# Load the full hourly readings and merge in station info
readings = pd.read_csv(STATION_HOUR_PATH)
merged = readings.merge(
    stations[["StationId", "StationName", "City", "State"]],
    on="StationId",
    how="left",
)

# Filter to just the target city
city_data = merged[merged["City"] == CITY_NAME].copy()
city_data = city_data.sort_values(["StationId", "Datetime"])

city_data.to_csv(OUTPUT_PATH, index=False)

print(f"{CITY_NAME}: {city_data.shape[0]} rows, {city_data['StationId'].nunique()} stations")
print("Stations included:")
for name in sorted(city_data["StationName"].unique()):
    print(f"  - {name}")
