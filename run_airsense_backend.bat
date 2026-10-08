@echo off
title AirSense FastAPI ML Backend
cd /d "D:\infosys_internship\backend"
echo ========================================================
echo Starting AirSense Live LSTM Prediction Server...
echo Host: http://127.0.0.1:8000
echo Docs: http://127.0.0.1:8000/docs
echo ========================================================
python -m uvicorn app_final:app --host 0.0.0.0 --port 8000
pause
