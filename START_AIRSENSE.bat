@echo off
title AirSense One-Click Launcher
echo ========================================================
echo          AIRSENSE DUAL-STACK DEMO LAUNCHER
echo ========================================================
echo.
echo [1/3] Starting Python FastAPI Backend on port 8000...
cd /d "%~dp0backend"
start /B python -m uvicorn app_final:app --host 127.0.0.1 --port 8000 > nul 2>&1

echo [2/3] Starting Web Frontend on port 5173...
cd /d "%~dp0airsense-frontend"
start /B npm run dev > nul 2>&1

echo [3/3] Opening AirSense in your default browser...
timeout /t 2 /nobreak > nul
start http://localhost:5173

echo.
echo ========================================================
echo  AirSense is now RUNNING!
echo  Web URL: http://localhost:5173
echo  Backend: http://127.0.0.1:8000
echo  (You can minimize this window. Press any key to close.)
echo ========================================================
pause > nul
