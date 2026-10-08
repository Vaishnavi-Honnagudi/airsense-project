"""
Fetches CURRENT (live) AQI (from WAQI) and weather (from OpenWeatherMap)
for each of your Delhi stations, using the coordinates you already built.

Fill in your two API keys below, then run:
    pip install requests
    python fetch_live_data.py
"""

import pandas as pd
import requests
import time

# --- Fill these in ---
OPENWEATHER_API_KEY = os.environ.get("OPENWEATHER_API_KEY", "YOUR_OPENWEATHER_API_KEY")
WAQI_TOKEN = "b153bb4057fa861d8dd6703ada2a80564b464439"

# Uses the coordinates file you already built earlier
STATIONS_PATH = "delhi_station_hour_with_coords.csv"

df = pd.read_csv(STATIONS_PATH, low_memory=False)
stations = df[["StationId", "StationName", "Latitude", "Longitude"]].drop_duplicates()
print(f"Fetching live data for {len(stations)} stations...")

results = []

for _, row in stations.iterrows():
    station_id = row["StationId"]
    name = row["StationName"]
    lat, lon = row["Latitude"], row["Longitude"]

    entry = {"StationId": station_id, "StationName": name, "Latitude": lat, "Longitude": lon}

    # --- Weather (OpenWeatherMap current weather) ---
    try:
        w_url = "https://api.openweathermap.org/data/2.5/weather"
        w_params = {"lat": lat, "lon": lon, "appid": OPENWEATHER_API_KEY, "units": "metric"}
        w_resp = requests.get(w_url, params=w_params, timeout=10).json()
        entry["Temperature_C"] = w_resp.get("main", {}).get("temp")
        entry["Humidity_pct"] = w_resp.get("main", {}).get("humidity")
        entry["WindSpeed_ms"] = w_resp.get("wind", {}).get("speed")
        entry["Pressure_hPa"] = w_resp.get("main", {}).get("pressure")
        entry["WeatherDesc"] = w_resp.get("weather", [{}])[0].get("description")
    except Exception as e:
        print(f"  Weather error for {name}: {e}")

    # --- Live AQI (WAQI) ---
    try:
        a_url = f"https://api.waqi.info/feed/geo:{lat};{lon}/"
        a_resp = requests.get(a_url, params={"token": WAQI_TOKEN}, timeout=10).json()
        if a_resp.get("status") == "ok":
            data = a_resp["data"]
            entry["Live_AQI"] = data.get("aqi")
            iaqi = data.get("iaqi", {})
            entry["Live_PM2.5"] = iaqi.get("pm25", {}).get("v")
            entry["Live_PM10"] = iaqi.get("pm10", {}).get("v")
            entry["Live_NO2"] = iaqi.get("no2", {}).get("v")
            entry["Live_CO"] = iaqi.get("co", {}).get("v")
        else:
            print(f"  WAQI returned no data for {name}: {a_resp.get('data')}")
    except Exception as e:
        print(f"  AQI error for {name}: {e}")

    results.append(entry)
    print(f"OK  {name} -> AQI={entry.get('Live_AQI')}, Temp={entry.get('Temperature_C')}\u00b0C")

    time.sleep(1)  # be polite to both free APIs

live_df = pd.DataFrame(results)
live_df.to_csv("delhi_live_data.csv", index=False)
print(f"\nDone. Saved to delhi_live_data.csv")
