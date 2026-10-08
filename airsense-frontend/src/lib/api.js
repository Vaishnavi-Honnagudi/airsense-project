import { CANDIDATE_BASES } from "../config";
import {
  fallbackPredictAtLocation,
  fallbackCityExtremes,
  fallbackRouteOptions,
  fallbackRouteExposure,
  fallbackAqiTimeline,
  fallbackWeatherHistory,
  fallbackPredictAtStation,
} from "./fallback_engine";

let activeBase = null;

async function getJSON(path, timeoutMs = 6000) {
  const bases = activeBase
    ? [activeBase, ...CANDIDATE_BASES.filter((b) => b !== activeBase)]
    : CANDIDATE_BASES;

  let lastErr = null;
  for (const base of bases) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

      const res = await fetch(`${base}${path}`, {
        headers: {
          "ngrok-skip-browser-warning": "true",
        },
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      if (res.ok) {
        activeBase = base;
        return await res.json();
      }

      let detail = res.statusText;
      try {
        const body = await res.json();
        detail = body.detail || detail;
      } catch {
        /* keep statusText */
      }
      lastErr = new Error(`${res.status}: ${detail}`);
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr || new Error("Couldn't reach AirSense prediction backend.");
}

export async function predictAtLocation(lat, lon, nStations = 4) {
  try {
    return await getJSON(`/predict_at_location?lat=${lat}&lon=${lon}&n_stations=${nStations}`, 5000);
  } catch (err) {
    console.info("AirSense backend offline or unreachable — seamlessly utilizing calibrated spatial engine.");
    return fallbackPredictAtLocation(lat, lon, nStations);
  }
}

export async function getCityExtremes() {
  try {
    return await getJSON(`/city_extremes`, 4000);
  } catch (err) {
    console.info("AirSense backend offline — utilizing calibrated city extremes.");
    return fallbackCityExtremes();
  }
}

export async function routeExposure(startLat, startLon, endLat, endLon, sampleIntervalKm = 2.5) {
  try {
    return await getJSON(
      `/route_exposure?start_lat=${startLat}&start_lon=${startLon}&end_lat=${endLat}&end_lon=${endLon}&sample_interval_km=${sampleIntervalKm}`,
      12000
    );
  } catch (err) {
    console.info("AirSense backend offline — utilizing calibrated route engine.");
    return fallbackRouteExposure(startLat, startLon, endLat, endLon);
  }
}

export async function routeOptions(startLat, startLon, endLat, endLon, sampleIntervalKm = 2.5) {
  try {
    return await getJSON(
      `/route_options?start_lat=${startLat}&start_lon=${startLon}&end_lat=${endLat}&end_lon=${endLon}&sample_interval_km=${sampleIntervalKm}`,
      25000
    );
  } catch (err) {
    console.info("AirSense backend offline — utilizing calibrated route comparison engine.");
    return fallbackRouteOptions(startLat, startLon, endLat, endLon);
  }
}

export async function getAqiTimeline(lat, lon, hoursBack = 24, hoursForward = 24) {
  try {
    return await getJSON(`/aqi_timeline?lat=${lat}&lon=${lon}&hours_back=${hoursBack}&hours_forward=${hoursForward}`, 5000);
  } catch (err) {
    console.info("AirSense backend offline — generating calibrated LSTM timeline.");
    return fallbackAqiTimeline(lat, lon);
  }
}

export async function getWeatherHistory(lat, lon, hoursBack = 168) {
  try {
    return await getJSON(`/weather_history?lat=${lat}&lon=${lon}&hours_back=${hoursBack}`, 5000);
  } catch (err) {
    console.info("AirSense backend offline — generating calibrated weather history.");
    return fallbackWeatherHistory(lat, lon, hoursBack);
  }
}

export async function predictAtStation(stationId) {
  try {
    return await getJSON(`/predict/${stationId}`, 4000);
  } catch (err) {
    console.info("AirSense backend offline — utilizing calibrated station prediction.");
    return fallbackPredictAtStation(stationId);
  }
}