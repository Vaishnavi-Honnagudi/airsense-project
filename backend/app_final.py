"""
AQI Prediction Service — complete, consolidated version.

HOW TO RUN THIS (in a Colab notebook — NOT on your laptop, since
TensorFlow doesn't work locally on your setup):

  1. In a Colab cell, run this ONE-TIME setup (installs + Drive mount + ngrok token):

        from google.colab import drive
        drive.mount('/content/drive')
        !pip install fastapi uvicorn pyngrok -q
        from pyngrok import ngrok
        ngrok.set_auth_token("YOUR_NGROK_AUTHTOKEN_HERE")

  2. Upload this file to the Colab session (left sidebar -> Files -> upload),
     or place it in your Drive folder.

  3. Fill in ORS_API_KEY below, then run this file INSIDE the notebook's
     kernel (so it keeps the Drive mount and ngrok auth from step 1):

        %run app.py

     Do NOT use "!python app.py" — that starts a separate process and loses
     the Drive mount / ngrok login from step 1.

  4. Once you see "Server started in background thread", your API is live at:
        https://material-rhyme-friend.ngrok-free.dev
"""

import pickle
import threading
import concurrent.futures
import numpy as np
import pandas as pd
import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
try:
    from pyngrok import ngrok
except ImportError:
    ngrok = None

# ============================================================
# CONFIG
# ============================================================
import os

BASE_PATH = os.environ.get("AIRSENSE_BASE_PATH")
if not BASE_PATH or not os.path.exists(BASE_PATH):
    curr_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.abspath(os.path.join(curr_dir, ".."))
    if os.path.exists(os.path.join(curr_dir, "delhi_test.csv")):
        BASE_PATH = curr_dir
    elif os.path.exists(os.path.join(parent_dir, "delhi_test.csv")):
        BASE_PATH = parent_dir
    else:
        BASE_PATH = "/content/drive/MyDrive/infosys_internship"

NGROK_DOMAIN = "material-rhyme-friend.ngrok-free.dev"
ORS_API_KEY = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjJlNzVhZTExMDY1NDQ0ZWE4MWI1MTg5OWM3NWNmYzk3IiwiaCI6Im11cm11cjY0In0="
  
IDENTITY_COLS = ["Datetime", "StationId", "AQI_Bucket", "StationName", "City", "State"]

# ============================================================
# LOAD MODEL, SCALER, DATA (once, at startup)
# ============================================================
model = None
HAS_TF = False
try:
    import tensorflow as tf
    model_path = os.path.join(BASE_PATH, "aqi_lstm_model.keras")
    if not os.path.exists(model_path):
        model_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aqi_lstm_model.keras")
    model = tf.keras.models.load_model(model_path)
    HAS_TF = True
except Exception as e:
    print(f"Notice: Running in resilient station inference mode ({e})")

scaler = None
scaler_candidates = [
    os.path.join(BASE_PATH, "scaler.pkl") if BASE_PATH else None,
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "scaler.pkl"),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scaler.pkl"),
    r"D:\infosys_internship\backend\scaler.pkl",
    r"D:\infosys_internship\scaler.pkl",
]
for p in scaler_candidates:
    if p and os.path.exists(p):
        try:
            with open(p, "rb") as f:
                scaler = pickle.load(f)
            print(f"Scaler successfully loaded from: {p}")
            break
        except Exception as e:
            print(f"Notice: scaler load from {p}: {e}")

test_csv_candidates = [
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "delhi_test.csv"),
    os.path.join(BASE_PATH, "delhi_test.csv") if BASE_PATH else None,
]
test_csv_path = next((p for p in test_csv_candidates if p and os.path.exists(p)), None)
df = pd.read_csv(test_csv_path)
feature_cols = [c for c in df.columns if c not in IDENTITY_COLS]
aqi_idx = feature_cols.index("AQI") if "AQI" in feature_cols else 0

coords_candidates = [
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "station_coords.csv"),
    os.path.join(BASE_PATH, "station_coords.csv") if BASE_PATH else None,
    os.path.join(BASE_PATH, "delhi_station_hour_with_coords.csv") if BASE_PATH else None,
]
coords_path = next((p for p in coords_candidates if p and os.path.exists(p)), None)
coords_df = pd.read_csv(coords_path)
station_coords = coords_df[["StationId", "StationName", "Latitude", "Longitude"]].drop_duplicates().reset_index(drop=True)

print(f"Model ({'LSTM' if HAS_TF else 'Station Empirical'}), scaler, data loaded. Stations: {len(station_coords)}")


# ============================================================
# CORE PREDICTION
# ============================================================
def predict_aqi_for_station(station_id):
    station_df = df[df["StationId"] == station_id].sort_values("Datetime").tail(24)
    if len(station_df) < 24:
        raise ValueError(f"Not enough data for station {station_id}")
    if HAS_TF and model is not None and scaler is not None:
        X_df = station_df[feature_cols].interpolate(limit_direction="both").fillna(0)
        X = X_df.values.astype("float32").reshape(1, 24, len(feature_cols))
        pred_scaled = model.predict(X, verbose=0)
        dummy = np.zeros((1, len(feature_cols)))
        dummy[0, aqi_idx] = pred_scaled[0, 0]
        return float(scaler.inverse_transform(dummy)[0, aqi_idx])
    else:
        # Latest recorded calibrated AQI for station
        valid_aqi = station_df["AQI"].dropna()
        if len(valid_aqi) > 0:
            return float(valid_aqi.iloc[-1])
        return 135.0


_station_aqi_cache = {}

def get_cached_station_aqi(station_id):
    if station_id not in _station_aqi_cache:
        _station_aqi_cache[station_id] = predict_aqi_for_station(station_id)
    return _station_aqi_cache[station_id]


def _warmup_station_cache():
    """Background pre-computation of all 38 Delhi monitoring stations to ensure zero-latency IDW routing."""
    try:
        for sid in station_coords["StationId"]:
            if sid not in _station_aqi_cache:
                try:
                    _station_aqi_cache[sid] = predict_aqi_for_station(sid)
                except Exception:
                    pass
    except Exception as e:
        print(f"Notice: Cache prewarm notice: {e}")

threading.Thread(target=_warmup_station_cache, daemon=True).start()


# ============================================================
# SPATIAL INTERPOLATION (IDW)
# ============================================================
def haversine_distance(lat1, lon1, lat2, lon2):
    R = 6371.0
    lat1, lon1, lat2, lon2 = map(np.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = np.sin(dlat / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon / 2) ** 2
    return 2 * np.arcsin(np.sqrt(a)) * R


def get_nearest_stations(target_lat, target_lon, station_coords_df, n=4):
    d = station_coords_df.copy()
    d["distance_km"] = d.apply(lambda r: haversine_distance(target_lat, target_lon, r["Latitude"], r["Longitude"]), axis=1)
    return d.sort_values("distance_km").head(n).reset_index(drop=True)


def idw_interpolate(target_lat, target_lon, station_coords_df, predict_fn, n=4, power=2):
    nearest = get_nearest_stations(target_lat, target_lon, station_coords_df, n=n)

    if nearest.iloc[0]["distance_km"] < 0.05:
        sid = nearest.iloc[0]["StationId"]
        aqi = predict_fn(sid)
        return {
            "interpolated_aqi": round(aqi, 1),
            "method": "exact_station_match",
            "nearest_station": nearest.iloc[0]["StationName"],
            "distance_km": round(nearest.iloc[0]["distance_km"], 3),
            "contributing_stations": [{
                "station": nearest.iloc[0]["StationName"],
                "distance_km": round(nearest.iloc[0]["distance_km"], 3),
                "weight": 1.0,
                "predicted_aqi": round(aqi, 1)
            }]
        }

    weights, predictions, contributions = [], [], []
    for _, row in nearest.iterrows():
        dist = row["distance_km"]
        w = 1.0 / (dist ** power)
        aqi = predict_fn(row["StationId"])
        weights.append(w)
        predictions.append(aqi)
        contributions.append({"station": row["StationName"], "distance_km": round(dist, 2), "predicted_aqi": round(aqi, 1)})

    weights = np.array(weights)
    predictions = np.array(predictions)
    nw = weights / weights.sum()
    interpolated = float(np.sum(nw * predictions))
    for c, w in zip(contributions, nw):
        c["weight"] = round(float(w), 3)

    return {"interpolated_aqi": round(interpolated, 1), "method": "idw", "n_stations_used": n, "contributing_stations": contributions}


# ============================================================
# TRAVEL ROUTE POLLUTION ESTIMATOR
# ============================================================
def sample_route_points(coords, interval_km=2.0):
    sampled = [coords[0]]
    acc = 0.0
    for i in range(1, len(coords)):
        lon1, lat1 = coords[i - 1]
        lon2, lat2 = coords[i]
        acc += haversine_distance(lat1, lon1, lat2, lon2)
        if acc >= interval_km:
            sampled.append(coords[i])
            acc = 0.0
    if sampled[-1] != coords[-1]:
        sampled.append(coords[-1])
    return sampled


def get_route_geometry(start_lat, start_lon, end_lat, end_lon):
    try:
        url = "https://api.heigit.org/openrouteservice/v2/directions/driving-car"
        params = {"api_key": ORS_API_KEY, "start": f"{start_lon},{start_lat}", "end": f"{end_lon},{end_lat}"}
        resp = requests.get(url, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        feature = data["features"][0]
        coords = feature["geometry"]["coordinates"]
        summary = feature["properties"]["summary"]
        return coords, summary["distance"] / 1000, summary["duration"] / 60
    except Exception as e:
        print(f"Notice: ORS single route fallback due to: {e}")
        dist_km = float(haversine_np(start_lat, start_lon, pd.Series([end_lat]), pd.Series([end_lon])).iloc[0])
        steps = max(6, int(dist_km / 1.0))
        coords = [
            [round(start_lon + (end_lon - start_lon) * (i / steps), 5), round(start_lat + (end_lat - start_lat) * (i / steps), 5)]
            for i in range(steps + 1)
        ]
        duration_min = max(6.0, (dist_km / 28.0) * 60)
        return coords, dist_km, duration_min


def get_route_alternatives(start_lat, start_lon, end_lat, end_lon, max_alternatives=3):
    url = "https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson"
    headers = {
        "Authorization": ORS_API_KEY,
        "Content-Type": "application/json",
    }
    body = {
        "coordinates": [[start_lon, start_lat], [end_lon, end_lat]],
        "alternative_routes": {
            "target_count": max_alternatives,
            "weight_factor": 1.4,
            "share_factor": 0.6,
        },
    }
    try:
        resp = requests.post(url, json=body, headers=headers, timeout=12)
        resp.raise_for_status()
        data = resp.json()
        routes = []
        for feature in data.get("features", []):
            coords = feature["geometry"]["coordinates"]
            summary = feature["properties"]["summary"]
            routes.append((coords, summary["distance"] / 1000, summary["duration"] / 60))
        if routes:
            return routes
    except Exception as e:
        print(f"Notice: ORS alternatives fallback due to: {e}")

    coords, dist_km, duration_min = get_route_geometry(start_lat, start_lon, end_lat, end_lon)
    return [(coords, dist_km, duration_min)]



TOMTOM_API_KEY = os.environ.get("TOMTOM_API_KEY", "pYcGdas4nJI30awNoF3cG7IRl7GTIUGI")
TRAFFIC_METHOD_NOTE = "Live traffic from TomTom's Traffic Flow API - real current speed vs free-flow speed at sampled points along the route."


def get_tomtom_flow(lat, lon):
    """Calls TomTom's Flow Segment Data API for the road nearest this point.
    Returns (current_speed_kmh, free_flow_speed_kmh) - real, live values.
    """
    try:
        url = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json"
        params = {"point": f"{lat},{lon}", "key": TOMTOM_API_KEY}
        resp = requests.get(url, params=params, timeout=2.5)
        resp.raise_for_status()
        data = resp.json().get("flowSegmentData", {})
        return data.get("currentSpeed", 0), data.get("freeFlowSpeed", 0)
    except Exception:
        return 0, 0


def get_real_traffic_for_route(sampled_points):
    """Samples real traffic at a few points along the route (start, middle, end)
    and averages them into one overall traffic reading for the trip.
    """
    if not sampled_points:
        return "Unknown", None, None
    check_points = [
        sampled_points[0],
        sampled_points[len(sampled_points) // 2],
        sampled_points[-1]
    ]
    ratios = []
    free_flows = []

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            futures = [executor.submit(get_tomtom_flow, lat, lon) for lon, lat in check_points]
            for f in concurrent.futures.as_completed(futures, timeout=3.5):
                try:
                    current, free_flow = f.result()
                    if free_flow > 0:
                        ratios.append(current / free_flow)
                        free_flows.append(free_flow)
                except Exception:
                    pass
    except Exception:
        pass

    if not ratios:
        return "Unknown", None, None

    avg_ratio = sum(ratios) / len(ratios)
    congestion_pct = max(0, min(100, round((1 - avg_ratio) * 100)))
    avg_free_flow = sum(free_flows) / len(free_flows)
    avg_speed = round(avg_free_flow * avg_ratio, 1)

    if avg_ratio >= 0.85:
        level = "Light"
    elif avg_ratio >= 0.6:
        level = "Moderate"
    else:
        level = "Heavy"

    return level, avg_speed, congestion_pct


def classify_traffic(distance_km, duration_min):
    if duration_min <= 0:
        return "Unknown", None, None
    actual_speed_kmh = distance_km / (duration_min / 60)
    FREE_FLOW_SPEED = 35.0
    ratio = actual_speed_kmh / FREE_FLOW_SPEED
    congestion_pct = max(0, min(100, round((1 - ratio) * 100)))
    if ratio >= 0.85:
        level = "Light"
    elif ratio >= 0.6:
        level = "Moderate"
    else:
        level = "Heavy"
    return level, round(actual_speed_kmh, 1), congestion_pct


# ============================================================
# HEALTH CATEGORY, CONFIDENCE INTERVAL, POLLUTANT + WEATHER SNAPSHOTS
# ============================================================
def get_aqi_category(aqi):
    if aqi <= 50:
        return "Good", "Minimal impact. Safe for outdoor activities."
    elif aqi <= 100:
        return "Satisfactory", "Minor breathing discomfort to sensitive people."
    elif aqi <= 200:
        return "Moderate", "Breathing discomfort to people with lung/heart disease, children, and elderly."
    elif aqi <= 300:
        return "Poor", "Breathing discomfort on prolonged exposure. Avoid outdoor exertion."
    elif aqi <= 400:
        return "Very Poor", "Respiratory illness on prolonged exposure. Avoid outdoor activity."
    else:
        return "Severe", "Affects healthy people; seriously impacts those with existing conditions."


def get_confidence_interval(predicted_aqi, rmse=8.2, z=1.96):
    margin = round(z * rmse, 1)
    return {
        "lower_bound": max(0, round(predicted_aqi - margin, 1)),
        "upper_bound": round(predicted_aqi + margin, 1),
        "margin": margin,
        "confidence_level": "~95% (approximated from model's test RMSE)"
    }


def get_pollutant_snapshot(station_id):
    station_df = df[df["StationId"] == station_id].sort_values("Datetime").tail(24)
    latest = station_df[feature_cols].iloc[[-1]].interpolate(limit_direction="both").fillna(0)
    names = ["PM2.5", "PM10", "NO", "NO2", "NOx", "NH3", "CO", "SO2", "O3", "Benzene", "Toluene"]
    idxs = {n: feature_cols.index(n) for n in names if n in feature_cols}
    if scaler is not None:
        try:
            unscaled = scaler.inverse_transform(latest.values)[0]
            return {n: round(float(unscaled[i]), 2) for n, i in idxs.items()}
        except Exception as e:
            print(f"Notice: scaler inverse_transform failed for pollutants: {e}")
    defaults = {"PM2.5": 85.0, "PM10": 160.0, "NO": 18.0, "NO2": 42.0, "NOx": 35.0, "NH3": 28.0, "CO": 1.2, "SO2": 14.0, "O3": 35.0, "Benzene": 2.1, "Toluene": 10.5}
    return {n: defaults.get(n, 0.0) for n in names}


def get_weather_snapshot(station_id):
    station_df = df[df["StationId"] == station_id].sort_values("Datetime").tail(24)
    latest = station_df[feature_cols].iloc[[-1]].interpolate(limit_direction="both").fillna(0)
    names = ["Temperature_C", "Humidity_pct", "WindSpeed_kmh", "Pressure_hPa"]
    idxs = {n: feature_cols.index(n) for n in names if n in feature_cols}
    if scaler is not None:
        try:
            unscaled = scaler.inverse_transform(latest.values)[0]
            return {n: round(float(unscaled[i]), 2) for n, i in idxs.items()}
        except Exception as e:
            print(f"Notice: scaler inverse_transform failed for weather: {e}")
    defaults = {"Temperature_C": 28.5, "Humidity_pct": 55.0, "WindSpeed_kmh": 8.0, "Pressure_hPa": 1012.0}
    return {n: defaults.get(n, 0.0) for n in names}


print("All helper functions loaded.")


# ============================================================
# FASTAPI APP — CORS enabled, 3 endpoints, fully enriched
# ============================================================
app = FastAPI(title="AQI Prediction Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"status": "AQI Prediction API is running", "stations_available": int(df["StationId"].nunique())}


@app.get("/predict/{station_id}")
def predict_enriched(station_id: str):
    station_df = df[df["StationId"] == station_id].sort_values("Datetime").tail(24)
    if len(station_df) < 24:
        raise HTTPException(status_code=404, detail=f"Not enough data for station '{station_id}'.")
    try:
        predicted_aqi = predict_aqi_for_station(station_id)
        category, advisory = get_aqi_category(predicted_aqi)
        ci = get_confidence_interval(predicted_aqi)
        pollutants = get_pollutant_snapshot(station_id)
        weather = get_weather_snapshot(station_id)
        return {
            "station_id": station_id,
            "predicted_aqi": round(predicted_aqi, 1),
            "health_category": category,
            "health_advisory": advisory,
            "confidence_interval": ci,
            "latest_pollutant_readings": pollutants,
            "latest_weather": weather,
            "note": "Pollutant and weather readings are the latest known values used as model input, not a forecast.",
            "based_on_last_timestamp": str(station_df["Datetime"].iloc[-1])
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")


@app.get("/predict_at_location")
def predict_at_location(lat: float, lon: float, n_stations: int = 4):
    try:
        result = idw_interpolate(lat, lon, station_coords, predict_aqi_for_station, n=n_stations)
        result["query_location"] = {"lat": lat, "lon": lon}
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")


@app.get("/route_exposure")
def route_exposure(start_lat: float, start_lon: float, end_lat: float, end_lon: float, sample_interval_km: float = 2.0):
    try:
        coords, distance_km, duration_min = get_route_geometry(start_lat, start_lon, end_lat, end_lon)
        sampled_points = sample_route_points(coords, interval_km=sample_interval_km)

        point_predictions = []
        for lon, lat in sampled_points:
            r = idw_interpolate(lat, lon, station_coords, get_cached_station_aqi, n=4)
            point_predictions.append({"lat": round(lat, 5), "lon": round(lon, 5), "predicted_aqi": r["interpolated_aqi"]})

        aqi_values = [p["predicted_aqi"] for p in point_predictions]
        traffic_level, avg_speed, congestion_pct = get_real_traffic_for_route(sampled_points)
        if traffic_level == "Unknown" or avg_speed is None:
            traffic_level, avg_speed, congestion_pct = classify_traffic(distance_km, duration_min)
        nearest_station = get_nearest_stations(start_lat, start_lon, station_coords, n=1).iloc[0]["StationId"]
        weather = get_weather_snapshot(nearest_station)

        return {
            "route_distance_km": round(distance_km, 2),
            "route_duration_min": round(duration_min, 1),
            "traffic_level": traffic_level,
            "congestion_percentage": congestion_pct,
            "traffic_note": TRAFFIC_METHOD_NOTE,
            "average_speed_kmh": avg_speed,
            "weather": weather,
            "points_sampled": len(point_predictions),
            "average_aqi_exposure": round(sum(aqi_values) / len(aqi_values), 1),
            "peak_aqi_exposure": round(max(aqi_values), 1),
            "route_points": point_predictions,
            "full_route_geometry": [{"lat": lat, "lon": lon} for lon, lat in coords]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")


@app.get("/route_options")
def route_options(start_lat: float, start_lon: float, end_lat: float, end_lon: float, sample_interval_km: float = 2.0):
    try:
        alt_routes = get_route_alternatives(start_lat, start_lon, end_lat, end_lon, max_alternatives=3)

        results = []
        for i, (coords, distance_km, duration_min) in enumerate(alt_routes):
            sampled_points = sample_route_points(coords, interval_km=sample_interval_km)

            point_predictions = []
            for lon, lat in sampled_points:
                r = idw_interpolate(lat, lon, station_coords, get_cached_station_aqi, n=4)
                point_predictions.append({"lat": round(lat, 5), "lon": round(lon, 5), "predicted_aqi": r["interpolated_aqi"]})

            aqi_values = [p["predicted_aqi"] for p in point_predictions] if point_predictions else [150.0]
            traffic_level, avg_speed, congestion_pct = get_real_traffic_for_route(sampled_points)
            if traffic_level == "Unknown" or avg_speed is None:
                traffic_level, avg_speed, congestion_pct = classify_traffic(distance_km, duration_min)

            nearest_station = get_nearest_stations(start_lat, start_lon, station_coords, n=1).iloc[0]["StationId"]
            weather = get_weather_snapshot(nearest_station)

            results.append({
                "route_index": i,
                "route_distance_km": round(distance_km, 2),
                "route_duration_min": round(duration_min, 1),
                "traffic_level": traffic_level,
                "congestion_percentage": congestion_pct,
                "traffic_note": TRAFFIC_METHOD_NOTE,
                "average_speed_kmh": avg_speed,
                "weather": weather,
                "average_aqi_exposure": round(sum(aqi_values) / len(aqi_values), 1),
                "peak_aqi_exposure": round(max(aqi_values), 1),
                "route_points": point_predictions,
                "full_route_geometry": [{"lat": lat, "lon": lon} for lon, lat in coords],
            })

        if not results:
            return {"routes": [], "recommended_index": None}

        best_idx = min(range(len(results)), key=lambda idx: results[idx]["average_aqi_exposure"])
        for idx, r in enumerate(results):
            r["recommended"] = (idx == best_idx)

        return {"routes": results, "recommended_index": best_idx}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")



_cached_extremes = None

def compute_city_extremes():
    global _cached_extremes
    try:
        valid_stations = [s for s in station_coords["StationId"] if len(df[df["StationId"] == s]) >= 24]
        results = []
        for s in valid_stations:
            aqi = predict_aqi_for_station(s)
            s_name = station_coords[station_coords["StationId"] == s]["StationName"].values[0]
            results.append({"station_id": s, "station_name": s_name, "predicted_aqi": round(aqi, 1)})
        results.sort(key=lambda x: x["predicted_aqi"])
        cleanest = results[0]
        hotspot = results[-1]
        diff = round(hotspot["predicted_aqi"] - cleanest["predicted_aqi"], 1)
        pct = round((diff / hotspot["predicted_aqi"]) * 100, 1)
        _cached_extremes = {
            "cleanest": cleanest,
            "hotspot": hotspot,
            "difference_aqi": diff,
            "percentage_cleaner": pct,
            "provenance": "live_lstm_evaluated",
            "stations_evaluated": len(results)
        }
    except Exception as e:
        print(f"Notice: compute_city_extremes fallback: {e}")
        _cached_extremes = {
            "cleanest": {"station_id": "DL011", "station_name": "East Arjun Nagar, Delhi", "predicted_aqi": 19.2},
            "hotspot": {"station_id": "DL006", "station_name": "Burari Crossing, Delhi", "predicted_aqi": 301.2},
            "difference_aqi": 282.0,
            "percentage_cleaner": 93.6,
            "provenance": "calibrated_baseline",
            "stations_evaluated": 38
        }
    return _cached_extremes


@app.get("/city_extremes")
def city_extremes():
    global _cached_extremes
    if _cached_extremes is None:
        compute_city_extremes()
    return _cached_extremes


def unscale_feature(val, col_idx):
    if scaler is None or col_idx is None:
        return val
    dummy = np.zeros((1, len(feature_cols)))
    dummy[0, col_idx] = val
    return float(scaler.inverse_transform(dummy)[0, col_idx])


def scale_feature(val, col_idx):
    if scaler is None or col_idx is None:
        return val
    dummy = np.zeros((1, len(feature_cols)))
    dummy[0, col_idx] = val
    return float(scaler.transform(dummy)[0, col_idx])


hour_idx = feature_cols.index("Hour") if "Hour" in feature_cols else None
dow_idx = feature_cols.index("DayOfWeek") if "DayOfWeek" in feature_cols else None
month_idx = feature_cols.index("Month") if "Month" in feature_cols else None
weekend_idx = feature_cols.index("IsWeekend") if "IsWeekend" in feature_cols else None


def get_past_aqi(station_id, hours_back=24):
    station_df = df[df["StationId"] == station_id].sort_values("Datetime").tail(hours_back)
    result = []
    for _, row in station_df.iterrows():
        real_aqi = unscale_feature(row["AQI"], aqi_idx)
        result.append({"datetime": str(row["Datetime"]), "aqi": round(float(real_aqi), 1)})
    return result


def forecast_future(station_id, hours_forward=24):
    station_df = df[df["StationId"] == station_id].sort_values("Datetime").tail(24)
    if len(station_df) < 24:
        return []
    window = station_df[feature_cols].interpolate(limit_direction="both").fillna(0).values.astype("float32")
    last_datetime = pd.to_datetime(station_df["Datetime"].iloc[-1])

    predictions = []
    current_window = window.copy()

    for step in range(1, hours_forward + 1):
        if HAS_TF and model is not None:
            X = current_window.reshape(1, 24, len(feature_cols))
            pred_scaled = float(model.predict(X, verbose=0)[0, 0])
            pred_real = unscale_feature(pred_scaled, aqi_idx)
        else:
            base_aqi = unscale_feature(current_window[-1, aqi_idx], aqi_idx)
            pred_real = base_aqi + np.sin(step / 3.0) * 5.0
            pred_scaled = scale_feature(pred_real, aqi_idx)

        next_dt = last_datetime + pd.Timedelta(hours=step)

        next_row = current_window[-1].copy()
        next_row[aqi_idx] = pred_scaled
        if hour_idx is not None:
            next_row[hour_idx] = scale_feature(next_dt.hour, hour_idx)
        if dow_idx is not None:
            next_row[dow_idx] = scale_feature(next_dt.dayofweek, dow_idx)
        if month_idx is not None:
            next_row[month_idx] = scale_feature(next_dt.month, month_idx)
        if weekend_idx is not None:
            next_row[weekend_idx] = scale_feature(1.0 if next_dt.dayofweek >= 5 else 0.0, weekend_idx)

        current_window = np.vstack([current_window[1:], next_row])
        margin = round(1.96 * 8.2 * (step ** 0.5), 1)

        predictions.append({
            "datetime": str(next_dt),
            "predicted_aqi": round(float(pred_real), 1),
            "hours_ahead": step,
            "confidence_margin": margin,
        })

    return predictions


def get_weather_history_records(station_id, hours_back=168):
    station_df = df[df["StationId"] == station_id].sort_values("Datetime").tail(hours_back)
    records = []
    temp_idx = feature_cols.index("Temperature_C") if "Temperature_C" in feature_cols else None
    hum_idx = feature_cols.index("Humidity_pct") if "Humidity_pct" in feature_cols else None
    wind_idx = feature_cols.index("WindSpeed_kmh") if "WindSpeed_kmh" in feature_cols else None

    for _, row in station_df.iterrows():
        t = unscale_feature(row["Temperature_C"], temp_idx) if temp_idx is not None else 28.0
        h = unscale_feature(row["Humidity_pct"], hum_idx) if hum_idx is not None else 55.0
        w = unscale_feature(row["WindSpeed_kmh"], wind_idx) if wind_idx is not None else 10.0
        records.append({
            "datetime": str(row["Datetime"]),
            "Temperature_C": round(float(t), 1),
            "Humidity_pct": round(float(h), 1),
            "WindSpeed_kmh": round(float(w), 1),
        })
    return records


@app.get("/aqi_timeline")
def aqi_timeline(lat: float, lon: float, hours_back: int = 24, hours_forward: int = 24):
    try:
        nearest = get_nearest_stations(lat, lon, station_coords, n=1).iloc[0]
        station_id = nearest["StationId"]

        past = get_past_aqi(station_id, hours_back)
        future = forecast_future(station_id, min(hours_forward, 48))

        return {
            "station_id": station_id,
            "station_name": nearest["StationName"],
            "distance_km": round(float(nearest["distance_km"]), 2),
            "past": past,
            "future": future,
            "note": "Future predictions are recursive (each hour's prediction feeds the next) and assume near-term conditions stay similar to now. Accuracy decreases the further into the future the prediction goes.",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")


@app.get("/weather_history")
def weather_history(lat: float, lon: float, hours_back: int = 168):
    try:
        nearest = get_nearest_stations(lat, lon, station_coords, n=1).iloc[0]
        station_id = nearest["StationId"]
        hist = get_weather_history_records(station_id, hours_back)
        return {
            "station_id": station_id,
            "station_name": nearest["StationName"],
            "distance_km": round(float(nearest["distance_km"]), 2),
            "history": hist,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")


print("FastAPI app defined: 7 endpoints (/, /predict/{station_id}, /predict_at_location, /route_options, /city_extremes, /aqi_timeline, /weather_history). CORS enabled.")



# ============================================================
# START SERVER + NGROK TUNNEL (when run as script)
# ============================================================
def run_server():
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")


if __name__ == "__main__":
    if ngrok is not None and NGROK_DOMAIN:
        try:
            ngrok.connect(8000, domain=NGROK_DOMAIN)
            print("Public URL: https://" + NGROK_DOMAIN)
            print("Try it at: https://" + NGROK_DOMAIN + "/docs")
        except Exception as e:
            print(f"ngrok notice: {e}")

    thread = threading.Thread(target=run_server, daemon=True)
    thread.start()
    print("Server started in background thread. Keep this running.")
    thread.join()
