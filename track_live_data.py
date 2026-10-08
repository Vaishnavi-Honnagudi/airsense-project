"""
Tracks live AQI, weather, and traffic (route duration) for Delhi.
Appends a timestamped snapshot to a log file EVERY time you run it -
so running this periodically (e.g. a few times a day) builds an actual
tracked history, not just a one-off snapshot.

Fill in your 3 API keys below, then run:
    pip install requests
    python track_live_data.py
"""

import pandas as pd
import requests
import time
from datetime import datetime

# --- Fill these in ---
OPENWEATHER_API_KEY = os.environ.get("OPENWEATHER_API_KEY", "YOUR_OPENWEATHER_API_KEY")
WAQI_TOKEN = "b153bb4057fa861d8dd6703ada2a80564b464439"
ORS_API_KEY = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjJlNzVhZTExMDY1NDQ0ZWE4MWI1MTg5OWM3NWNmYzk3IiwiaCI6Im11cm11cjY0In0="


STATIONS_PATH = "delhi_station_hour_with_coords.csv"
AQI_WEATHER_LOG = "aqi_weather_log.csv"
TRAFFIC_LOG = "traffic_log.csv"

# A few representative routes spanning different parts of Delhi, using
# station coordinates you already geocoded - gives spatial coverage
# similar to your AQI station grid. (lon, lat) order - ORS requires
# longitude first, unlike most other APIs.
ROUTES = [
    {"name": "North-South (Alipur to RK Puram)",
     "start": (77.138667, 28.7973118), "end": (77.1855231, 28.5503805)},
    {"name": "East-West (Anand Vihar to Dwarka Sector 8)",
     "start": (77.3155317, 28.6466157), "end": (77.0670366, 28.5656109)},
    {"name": "Central-North (ITO to Alipur)",
     "start": (77.2410437, 28.6281909), "end": (77.138667, 28.7973118)},
]

now = datetime.now()
timestamp = now.strftime("%Y-%m-%d %H:%M:%S")

# ============ WEATHER + AQI ============
df = pd.read_csv(STATIONS_PATH, low_memory=False)
stations = df[["StationId", "StationName", "Latitude", "Longitude"]].drop_duplicates()
print(f"[{timestamp}] Fetching AQI + weather for {len(stations)} stations...")

aqi_weather_rows = []
for _, row in stations.iterrows():
    lat, lon = row["Latitude"], row["Longitude"]
    entry = {"Timestamp": timestamp, "StationId": row["StationId"], "StationName": row["StationName"]}

    try:
        w = requests.get("https://api.openweathermap.org/data/2.5/weather",
                          params={"lat": lat, "lon": lon, "appid": OPENWEATHER_API_KEY, "units": "metric"},
                          timeout=10).json()
        entry["Temperature_C"] = w.get("main", {}).get("temp")
        entry["Humidity_pct"] = w.get("main", {}).get("humidity")
        entry["WindSpeed_ms"] = w.get("wind", {}).get("speed")
    except Exception as e:
        print(f"  Weather error: {e}")

    try:
        a = requests.get(f"https://api.waqi.info/feed/geo:{lat};{lon}/",
                          params={"token": WAQI_TOKEN}, timeout=10).json()
        if a.get("status") == "ok":
            data = a["data"]
            # cap at 500 to match your training data's scale
            entry["Live_AQI"] = min(data.get("aqi", 0), 500)
    except Exception as e:
        print(f"  AQI error: {e}")

    aqi_weather_rows.append(entry)
    time.sleep(1)

new_aqi_df = pd.DataFrame(aqi_weather_rows)
try:
    existing = pd.read_csv(AQI_WEATHER_LOG)
    combined = pd.concat([existing, new_aqi_df], ignore_index=True)
except FileNotFoundError:
    combined = new_aqi_df
combined.to_csv(AQI_WEATHER_LOG, index=False)
print(f"Logged {len(new_aqi_df)} AQI/weather rows -> {AQI_WEATHER_LOG} ({len(combined)} total rows so far)")

# ============ TRAFFIC (route duration as a congestion proxy) ============
print(f"\n[{timestamp}] Fetching traffic (route durations)...")

traffic_rows = []
for route in ROUTES:
    entry = {"Timestamp": timestamp, "Route": route["name"]}
    try:
        start_str = f"{route['start'][0]},{route['start'][1]}"
        end_str = f"{route['end'][0]},{route['end'][1]}"
        resp = requests.get(
            "https://api.heigit.org/openrouteservice/v2/directions/driving-car",
            params={"api_key": ORS_API_KEY, "start": start_str, "end": end_str},
            timeout=15,
        )
        if resp.status_code != 200:
            print(f"  Traffic error for {route['name']}: HTTP {resp.status_code} - {resp.text[:300]}")
        else:
            data = resp.json()
            summary = data["features"][0]["properties"]["summary"]
            entry["Duration_min"] = round(summary["duration"] / 60, 1)
            entry["Distance_km"] = round(summary["distance"] / 1000, 1)
            print(f"  OK  {route['name']} -> {entry['Duration_min']} min, {entry['Distance_km']} km")
    except Exception as e:
        print(f"  Traffic error for {route['name']}: {e}")
    traffic_rows.append(entry)
    time.sleep(1.5)  # ORS free tier: 40 requests/min limit

new_traffic_df = pd.DataFrame(traffic_rows)
try:
    existing_t = pd.read_csv(TRAFFIC_LOG)
    combined_t = pd.concat([existing_t, new_traffic_df], ignore_index=True)
except FileNotFoundError:
    combined_t = new_traffic_df
combined_t.to_csv(TRAFFIC_LOG, index=False)
print(f"Logged {len(new_traffic_df)} traffic rows -> {TRAFFIC_LOG} ({len(combined_t)} total rows so far)")

print("\nDone. Run this script again later (e.g. a few times a day) to keep building history.")