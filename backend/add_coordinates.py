"""
Adds latitude/longitude to each station by geocoding the station name
via OpenStreetMap's free Nominatim service.

First install geopy:
    pip install geopy

Then run:
    python add_coordinates.py

Note: Nominatim asks for a short delay between requests (1 request/sec)
and a real user_agent string - both are handled below. With ~38 Delhi
stations this takes under a minute.
"""

import pandas as pd
import time
from geopy.geocoders import Nominatim

INPUT_PATH = "delhi_station_hour.csv"
OUTPUT_PATH = "delhi_station_hour_with_coords.csv"

geolocator = Nominatim(user_agent="springboard-aqi-project", timeout=10)

# These didn't resolve via Nominatim - verified manually on Google Maps
MANUAL_OVERRIDES = {
    "IHBAS, Dilshad Garden, Delhi - CPCB": (28.682687, 77.304913),
    "Mandir Marg, Delhi - DPCC": (28.636181, 77.200386),
    "NSIT Dwarka, Delhi - CPCB": (28.610533, 77.035504),
    "Najafgarh, Delhi - DPCC": (28.609493, 76.981244),
    "North Campus, DU, Delhi - IMD": (28.687979, 77.209175),
}

df = pd.read_csv(INPUT_PATH)

# Only need to geocode each unique station once, not every row
unique_stations = df["StationName"].unique()
coords = {}

for name in unique_stations:
    if name in MANUAL_OVERRIDES:
        coords[name] = MANUAL_OVERRIDES[name]
        print(f"MANUAL {name} -> {MANUAL_OVERRIDES[name]}")
        continue

    # Station names look like "Anand Vihar, Delhi - DPCC" -
    # strip the trailing " - AGENCY" part, which confuses the geocoder
    query = name.split(" - ")[0]

    location = None
    for attempt in range(3):  # retry up to 3 times on timeout
        try:
            location = geolocator.geocode(query)
            break
        except Exception as e:
            print(f"  retry {attempt + 1}/3 for {name} ({e})")
            time.sleep(2)

    if location:
        coords[name] = (location.latitude, location.longitude)
        print(f"OK   {name} -> ({location.latitude}, {location.longitude})")
    else:
        coords[name] = (None, None)
        print(f"MISS {name} -> not found after retries, will need manual lookup")
    time.sleep(1)  # Nominatim's usage policy: max 1 request per second

df["Latitude"] = df["StationName"].map(lambda n: coords[n][0])
df["Longitude"] = df["StationName"].map(lambda n: coords[n][1])

df.to_csv(OUTPUT_PATH, index=False)

missing = [n for n, (lat, lon) in coords.items() if lat is None]
print(f"\nDone. {len(unique_stations) - len(missing)}/{len(unique_stations)} stations geocoded.")
if missing:
    print("These need manual coordinates (search station name + 'Delhi' on Google Maps):")
    for m in missing:
        print(f"  - {m}")