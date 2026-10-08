import { useCallback, useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import { useAppContext } from "../context/AppContext";
import MapView from "../components/MapView";
import LocationSearch from "../components/LocationSearch";
import { LocationResult, RouteOptionsResult } from "../components/ResultPanel";
import AqiTimelineChart from "../components/AqiTimelineChart";
import WeatherHistoryChart from "../components/WeatherHistoryChart";
import CleanNavigationHud from "../components/CleanNavigationHud";
import { predictAtLocation, routeOptions, getAqiTimeline, getWeatherHistory } from "../lib/api";

export default function MapPage() {
  const [searchParams] = useSearchParams();
  const initialMode = searchParams.get("mode") === "route" ? "route" : "location";
  const [mode, setMode] = useState(initialMode);

  const { ageGroup, healthNote, addHistoryEntry } = useAppContext();

  const [selectedPoint, setSelectedPoint] = useState(null);
  const [locationResult, setLocationResult] = useState(null);
  const [timeline, setTimeline] = useState(null);
  const [timelineLoading, setTimelineLoading] = useState(false);
  const [weatherHistory, setWeatherHistory] = useState(null);
  const [weatherLoading, setWeatherLoading] = useState(false);

  const [routeStart, setRouteStart] = useState(null);
  const [routeEnd, setRouteEnd] = useState(null);
  const [routes, setRoutes] = useState(null);
  const [selectedRouteIndex, setSelectedRouteIndex] = useState(0);

  const [status, setStatus] = useState("");
  const [statusIsError, setStatusIsError] = useState(false);
  const [loading, setLoading] = useState(false);
  const [locating, setLocating] = useState(false);
  const [isNavigating, setIsNavigating] = useState(false);
  const [navRouteData, setNavRouteData] = useState(null);

  // Update mode if URL changes
  useEffect(() => {
    const urlMode = searchParams.get("mode") === "route" ? "route" : "location";
    if (urlMode !== mode) {
      switchMode(urlMode);
    }
  }, [searchParams]);

  function switchMode(next) {
    setMode(next);
    setSelectedPoint(null);
    setLocationResult(null);
    setRouteStart(null);
    setRouteEnd(null);
    setRoutes(null);
    setSelectedRouteIndex(0);
    setStatus("");
  }

  const handleClick = useCallback(
    (lat, lng) => {
      setStatus("");
      if (mode === "location") {
        setSelectedPoint({ lat, lng });
        setLocationResult(null);
        return;
      }

      setRouteStart((currentStart) => {
        if (!currentStart) return { lat, lng };
        return currentStart;
      });

      setRouteEnd((currentEnd) => {
        if (!routeStart) return null;
        if (routeStart && !currentEnd) return { lat, lng };
        return null;
      });

      if (routeStart && routeEnd) {
        setRouteStart({ lat, lng });
        setRouteEnd(null);
        setRoutes(null);
        setSelectedRouteIndex(0);
      }
    },
    [mode, routeStart, routeEnd]
  );

  function handleLocationSearchSelect(lat, lon, label) {
    setSelectedPoint({ lat, lng: lon, label });
    setLocationResult(null);
    setStatus("");
  }

  function handleStartSearchSelect(lat, lon, label) {
    setRouteStart({ lat, lng: lon, label });
    setRoutes(null);
    setSelectedRouteIndex(0);
    setStatus("");
  }

  function handleEndSearchSelect(lat, lon, label) {
    setRouteEnd({ lat, lng: lon, label });
    setRoutes(null);
    setSelectedRouteIndex(0);
    setStatus("");
  }

  function locateCurrentPosition(target) {
    if (!navigator.geolocation) {
      setStatus("Geolocation isn't supported in this browser.");
      setStatusIsError(true);
      return;
    }
    setLocating(true);
    setStatus("Detecting your current location…");
    setStatusIsError(false);

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        if (target === "location") {
          setSelectedPoint({ lat: latitude, lng: longitude, label: "Current Location" });
          setLocationResult(null);
        } else if (target === "start") {
          setRouteStart({ lat: latitude, lng: longitude, label: "Current Location" });
          setRoutes(null);
          setSelectedRouteIndex(0);
        } else if (target === "end") {
          setRouteEnd({ lat: latitude, lng: longitude, label: "Current Location" });
          setRoutes(null);
          setSelectedRouteIndex(0);
        }
        setStatus("");
        setLocating(false);
      },
      (err) => {
        setStatus(`Couldn't get your location — ${err.message}`);
        setStatusIsError(true);
        setLocating(false);
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  async function submitLocation() {
    if (!selectedPoint) return;
    setLoading(true);
    setStatus("Fetching prediction…");
    setStatusIsError(false);
    setTimeline(null);
    setWeatherHistory(null);
    try {
      const data = await predictAtLocation(selectedPoint.lat, selectedPoint.lng);
      setLocationResult(data);
      setStatus("");
      
      addHistoryEntry({
        type: 'location',
        aqi: data.interpolated_aqi,
        locationLabel: selectedPoint.label || `${selectedPoint.lat.toFixed(4)}, ${selectedPoint.lng.toFixed(4)}`
      });
    } catch (err) {
      setStatus(`Couldn't reach the API — ${err.message}`);
      setStatusIsError(true);
    } finally {
      setLoading(false);
    }
  }

  async function fetchTimeline() {
    if (!selectedPoint) return;
    setTimelineLoading(true);
    setStatus("Building AQI trend — the future forecast takes a few extra seconds…");
    setStatusIsError(false);
    try {
      const data = await getAqiTimeline(selectedPoint.lat, selectedPoint.lng, 24, 24);
      setTimeline(data);
      setStatus("");
    } catch (err) {
      setStatus(`Couldn't reach the API — ${err.message}`);
      setStatusIsError(true);
    } finally {
      setTimelineLoading(false);
    }
  }

  async function fetchWeatherHistory() {
    if (!selectedPoint) return;
    setWeatherLoading(true);
    setStatus("Fetching weather history…");
    setStatusIsError(false);
    try {
      const data = await getWeatherHistory(selectedPoint.lat, selectedPoint.lng, 168);
      setWeatherHistory(data);
      setStatus("");
    } catch (err) {
      setStatus(`Couldn't reach the API — ${err.message}`);
      setStatusIsError(true);
    } finally {
      setWeatherLoading(false);
    }
  }

  async function submitRoute() {
    if (!routeStart || !routeEnd) return;
    setLoading(true);
    setStatus("Comparing routes — this takes a few seconds…");
    setStatusIsError(false);
    try {
      const data = await routeOptions(routeStart.lat, routeStart.lng, routeEnd.lat, routeEnd.lng);
      const routeList = data.routes || [];
      const recIdx = (data.recommended_index != null && data.recommended_index >= 0 && data.recommended_index < routeList.length)
        ? data.recommended_index
        : 0;

      setRoutes(routeList);
      setSelectedRouteIndex(recIdx);
      setStatus("");
      
      if (routeList.length > 0 && routeList[recIdx]) {
        addHistoryEntry({
          type: 'route',
          aqi: routeList[recIdx].average_aqi_exposure,
          locationLabel: `${routeStart.label || 'Start'} to ${routeEnd.label || 'End'}`
        });
      }
    } catch (err) {
      setStatus(`Couldn't reach the API — ${err.message}`);
      setStatusIsError(true);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="map-page-layout">
      <div className="panel map-panel">
        <div className="mode-switch">
          <button className={`mode-btn ${mode === "location" ? "active" : ""}`} onClick={() => switchMode("location")}>
            Check location
          </button>
          <button className={`mode-btn ${mode === "route" ? "active" : ""}`} onClick={() => switchMode("route")}>
            Plan route
          </button>
        </div>

        {mode === "location" ? (
          <>
            <div className="field-label">Search, use current location, or click the map</div>
            <div className="search-with-locate">
              <LocationSearch
                placeholder="e.g. Connaught Place, Karol Bagh…"
                onSelect={(lat, lon, label) => handleLocationSearchSelect(lat, lon, label)}
                dotColor="#2E6E5E"
              />
              <button className="locate-btn" onClick={() => locateCurrentPosition("location")} disabled={locating} title="Use current location">
                📍
              </button>
            </div>

            <div className="field-label" style={{ marginTop: 14 }}>Selected point</div>
            <div className="point-display">
              {selectedPoint ? (
                <span>{selectedPoint.label || `${selectedPoint.lat.toFixed(4)}, ${selectedPoint.lng.toFixed(4)}`}</span>
              ) : (
                <span className="empty">Not selected yet</span>
              )}
            </div>
            <p className="hint">Estimates AQI at any point in Delhi by blending predictions from the nearest monitoring stations.</p>
            <button className="primary" disabled={!selectedPoint || loading} onClick={submitLocation}>
              Get AQI at this point
            </button>
          </>
        ) : (
          <>
            <div className="field-label">Start point</div>
            <div className="search-with-locate">
              <LocationSearch placeholder="Search or click map for start" onSelect={(lat, lon, label) => handleStartSearchSelect(lat, lon, label)} dotColor="#2E6E5E" />
              <button className="locate-btn" onClick={() => locateCurrentPosition("start")} disabled={locating} title="Use current location">
                📍
              </button>
            </div>
            <div className="point-display" style={{ marginTop: 6 }}>
              {routeStart ? (
                <span>{routeStart.label || `${routeStart.lat.toFixed(4)}, ${routeStart.lng.toFixed(4)}`}</span>
              ) : (
                <span className="empty">Not selected yet</span>
              )}
            </div>

            <div className="field-label" style={{ marginTop: 14 }}>Destination</div>
            <LocationSearch placeholder="Search or click map for destination" onSelect={(lat, lon, label) => handleEndSearchSelect(lat, lon, label)} dotColor="#E0533D" />
            <div className="point-display" style={{ marginTop: 6 }}>
              {routeEnd ? (
                <span>{routeEnd.label || `${routeEnd.lat.toFixed(4)}, ${routeEnd.lng.toFixed(4)}`}</span>
              ) : (
                <span className="empty">Not selected yet</span>
              )}
            </div>

            <p className="hint">Search by name, use 📍 for your current location, or click the map. Compares up to 3 route options.</p>
            <button className="primary" disabled={!routeStart || !routeEnd || loading} onClick={submitRoute}>
              Compare routes
            </button>
          </>
        )}

        {status && <div className={`status-line ${statusIsError ? "error" : ""}`}>{status}</div>}

        {mode === "location" ? (
          <LocationResult data={locationResult} healthNote={healthNote} ageGroup={ageGroup} />
        ) : (
          <RouteOptionsResult
            routes={routes}
            selectedIndex={selectedRouteIndex}
            onSelectRoute={setSelectedRouteIndex}
            onStartNavigation={(routeData) => {
              setNavRouteData(routeData);
              setIsNavigating(true);
            }}
            healthNote={healthNote}
            ageGroup={ageGroup}
          />
        )}

        {mode === "location" && locationResult && (
          <>
            <button
              className="secondary"
              disabled={timelineLoading}
              onClick={fetchTimeline}
              style={{ marginTop: 14 }}
            >
              {timelineLoading ? "Loading trend…" : "View 24h AQI trend (past + forecast)"}
            </button>
            <AqiTimelineChart data={timeline} />

            <button
              className="secondary"
              disabled={weatherLoading}
              onClick={fetchWeatherHistory}
              style={{ marginTop: 10 }}
            >
              {weatherLoading ? "Loading weather…" : "View weather history (hourly/daily)"}
            </button>
            <WeatherHistoryChart data={weatherHistory} />
          </>
        )}
      </div>

      <div className="map-container" style={{ position: "relative" }}>
        <MapView
          mode={mode}
          onMapClick={handleClick}
          locationResult={locationResult}
          selectedPoint={selectedPoint}
          routeStart={routeStart}
          routeEnd={routeEnd}
          routes={routes}
          selectedRouteIndex={selectedRouteIndex}
          onSelectRoute={setSelectedRouteIndex}
        />

        {isNavigating && navRouteData && (
          <CleanNavigationHud
            startLabel={routeStart?.label || "Origin"}
            destinationLabel={routeEnd?.label || "Destination"}
            routeAqi={navRouteData.average_aqi_exposure}
            distanceKm={navRouteData.route_distance_km}
            durationMins={navRouteData.route_duration_min}
            onExit={() => setIsNavigating(false)}
          />
        )}
      </div>
    </div>
  );
}
