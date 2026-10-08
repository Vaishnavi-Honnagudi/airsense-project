# AirSense — Frontend

React + Leaflet.js frontend for the AQI prediction system. Connects to the
FastAPI backend running on Colab.

## Setup

1. Install Node.js if you don't have it (v18+): https://nodejs.org
2. Open a terminal in this folder and run:
   ```
   npm install
   npm run dev
   ```
3. Open the URL it prints (usually http://localhost:5173).

## Before running: update the backend URL

Open src/config.js and make sure API_BASE matches your current ngrok URL:
```js
export const API_BASE = "https://material-rhyme-friend.ngrok-free.dev";
```

## Before running: enable CORS on the backend

Your Colab FastAPI service needs to allow requests from this frontend, or
the browser will block them. Add this in Colab, right after `app = FastAPI(...)`:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

Then restart the Colab runtime (Runtime -> Restart session) and re-run all
setup cells in order, so this takes effect before the server starts.

## How to use

- Check location mode: click anywhere on the Delhi map to get a predicted
  AQI at that exact point (blended from the nearest monitoring stations).
- Plan route mode: click once for your starting point, once for your
  destination -- this fetches the real driving route and shows average/peak
  pollution exposure, traffic level, and weather along the way.

## Project structure

```
src/
  config.js              -- backend URL, change this if ngrok URL changes
  lib/
    api.js                -- fetch wrappers for the 3 backend endpoints
    aqi.js                 -- AQI category/color helpers (shared)
  components/
    MapView.jsx            -- Leaflet map, click handling, route/marker drawing
    ResultPanel.jsx         -- result cards (location + route views)
  App.jsx                  -- main app state and layout
  styles.css               -- all styling
```

## Building for deployment (later)

```
npm run build
```
This produces a dist/ folder of static files that can be deployed to
any static host (Vercel, Netlify, GitHub Pages, etc.) when you're ready.
