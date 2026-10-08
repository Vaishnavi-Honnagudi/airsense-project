# AirSense Backend — Environmental Intelligence Pipeline & FastAPI Server

This directory contains the machine learning data pipeline, trained deep learning model, and FastAPI inference server for the AirSense Delhi Air Quality Intelligence System.

## Architecture

```
backend/
├── app_final.py              # FastAPI inference server (IDW spatial interpolation & multi-route comparison)
├── aqi_lstm_model.keras      # Trained Long Short-Term Memory (LSTM) deep learning model
├── scaler.pkl                # Fitted MinMaxScaler for model feature normalization
├── clean_data.py             # Data cleansing & missing value imputation
├── add_coordinates.py        # DPCC monitoring station geocoding
├── add_weather.py            # Hourly weather integration (temperature, humidity, wind)
├── feature_engineering.py    # Lag features, rolling averages, diurnal cyclical encodings
├── scale_and_split.py        # Train/test temporal split & feature scaling
├── retrain_model.py          # Continuous retraining pipeline with incremental logs
├── track_live_data.py        # Periodic DPCC telemetry scraper
├── fetch_live_data.py        # Live CPCB data fetcher
├── stations.csv              # Official Delhi DPCC monitoring station coordinates
└── requirements.txt          # Python dependencies
```

## Running the Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn app_final:app --host 0.0.0.0 --port 8000 --reload
```

## Primary Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/predict/{station_id}` | Station-specific LSTM AQI forecast |
| `GET` | `/predict_at_location` | Arbitrary GPS coordinate AQI via Inverse Distance Weighting (IDW) |
| `GET` | `/route_options` | Multi-route clean corridor optimization (ORS + traffic + spatial AQI) |
| `GET` | `/aqi_timeline` | 24-hour historical + forecast trend |
| `GET` | `/weather_history` | Multi-day atmospheric weather records |
