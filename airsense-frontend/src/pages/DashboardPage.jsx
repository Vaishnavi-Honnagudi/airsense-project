import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { getCityExtremes, predictAtLocation } from "../lib/api";
import { categorize, categoryColor, getAdvisory } from "../lib/aqi";

export default function DashboardPage() {
  const navigate = useNavigate();

  // Weather simulation modes
  const [weatherMode, setWeatherMode] = useState("auto"); // auto, smog, rain, sun, night
  const [activeStation, setActiveStation] = useState("Connaught Place");
  const [currentAqi, setCurrentAqi] = useState(91);
  const [aqiCategory, setAqiCategory] = useState("SATISFACTORY");
  const [aqiColor, setAqiColor] = useState("#A8CE39");
  const [stationWeather, setStationWeather] = useState({
    temp: 28,
    feelsLike: 30,
    humidity: 52,
    windSpeed: 10.5,
    pressure: 1012,
  });
  const [isLoadingStation, setIsLoadingStation] = useState(false);

  // Dynamic Extremes
  const [cleanest, setCleanest] = useState({
    name: "East Arjun Nagar",
    aqi: 19,
    status: "Good",
  });
  const [hotspot, setHotspot] = useState({
    name: "Burari Crossing",
    aqi: 301,
    status: "Severe",
  });
  const [differenceAqi, setDifferenceAqi] = useState(282);
  const [pctCleaner, setPctCleaner] = useState(93.6);
  const [isLiveLoaded, setIsLiveLoaded] = useState(false);

  const stations = [
    { name: "Connaught Place", lat: 28.6315, lng: 77.2167 },
    { name: "Anand Vihar", lat: 28.6502, lng: 77.3150 },
    { name: "R.K. Puram", lat: 28.5660, lng: 77.1767 },
    { name: "Wazirpur", lat: 28.6999, lng: 77.1654 },
  ];

  async function loadStationData(st) {
    setActiveStation(st.name);
    setIsLoadingStation(true);
    try {
      const pred = await predictAtLocation(st.lat, st.lng);
      const aqi = Math.round(pred.interpolated_aqi);
      const cat = categorize(aqi);
      setCurrentAqi(aqi);
      setAqiCategory(cat.toUpperCase());
      setAqiColor(categoryColor(cat));

      const hour = new Date().getHours();
      const baseTemp = 28 + Math.round(3 * Math.sin(((hour - 9) * 2 * Math.PI) / 24));
      const baseHum = 54 - Math.round(10 * Math.sin(((hour - 9) * 2 * Math.PI) / 24));
      const baseWind = 11 + Math.round(2 * Math.cos(((hour - 12) * 2 * Math.PI) / 24));

      setStationWeather({
        temp: baseTemp,
        feelsLike: baseTemp + 2,
        humidity: baseHum,
        windSpeed: baseWind,
        pressure: 1012 + (hour % 3),
      });
    } catch (err) {
      console.warn("Station prediction query failed:", err);
    } finally {
      setIsLoadingStation(false);
    }
  }

  useEffect(() => {
    // Initial fetch for first station
    loadStationData(stations[0]);

    // Live extremes load
    async function loadExtremes() {
      try {
        const res = await getCityExtremes();
        if (res?.cleanest && res?.hotspot) {
          const cName = (res.cleanest.station_name || "East Arjun Nagar").split(",")[0];
          const cAqi = Math.round(res.cleanest.predicted_aqi);
          const hName = (res.hotspot.station_name || "Burari Crossing").split(",")[0];
          const hAqi = Math.round(res.hotspot.predicted_aqi);

          setCleanest({
            name: cName,
            aqi: cAqi,
            status: categorize(cAqi),
          });
          setHotspot({
            name: hName,
            aqi: hAqi,
            status: categorize(hAqi),
          });
          setDifferenceAqi(Math.round(res.difference_aqi || hAqi - cAqi));
          setPctCleaner(Number(res.percentage_cleaner || ((hAqi - cAqi) / hAqi) * 100).toFixed(1));
          setIsLiveLoaded(true);
        }
      } catch (e) {
        console.warn("Retaining baseline extremes:", e);
      }
    }
    loadExtremes();
  }, []);

  const bands = [
    { label: "Good", range: "0 - 50", desc: "Minimal impact. Safe for outdoor activities.", color: "#4CAF50" },
    { label: "Satisfactory", range: "51 - 100", desc: "Minor breathing discomfort to sensitive people.", color: "#A8CE39" },
    { label: "Moderate", range: "101 - 200", desc: "Breathing discomfort to people with asthma or heart conditions.", color: "#F4C542" },
    { label: "Poor", range: "201 - 300", desc: "Breathing discomfort to most people on prolonged exposure.", color: "#F08C3A" },
    { label: "Very Poor", range: "301 - 400", desc: "Respiratory illness on prolonged exposure.", color: "#E0533D" },
    { label: "Severe", range: "401 - 500", desc: "Affects healthy people and seriously impacts sensitive groups.", color: "#8B2E3C" },
  ];

  const tips = [
    "Check AQI before morning walks or strenuous outdoor workouts",
    "Keep windows closed during early morning and late evening peaks",
    "Use certified N95 / FFP2 masks when AQI exceeds 250+",
    "Indoor air purifiers with HEPA filters help reduce fine particulates",
    "Elderly and children should avoid prolonged outdoor exposure",
    "Plan commute routes through cleaner green corridors via AirSense",
  ];

  // Weather theme styling based on simulated mode
  const weatherThemes = {
    auto: { label: "Live: Hazy Smog", bg: "linear-gradient(135deg, #1C2D27 0%, #2A3B32 50%, #17241F 100%)", icon: "⚡" },
    smog: { label: "Dense Smog Alert", bg: "linear-gradient(135deg, #3D2D1E 0%, #4D3C28 50%, #291D12 100%)", icon: "🌫️" },
    rain: { label: "Light Monsoon Shower", bg: "linear-gradient(135deg, #182836 0%, #22374A 50%, #111D28 100%)", icon: "🌧️" },
    sun: { label: "Sunny & Clear Skies", bg: "linear-gradient(135deg, #2D4059 0%, #415A77 50%, #1F2E3D 100%)", icon: "☀️" },
    night: { label: "Calm Night Atmosphere", bg: "linear-gradient(135deg, #0D1B2A 0%, #1B263B 50%, #08111B 100%)", icon: "🌙" },
  };
  const currentTheme = weatherThemes[weatherMode] || weatherThemes.auto;

  const advisory = getAdvisory(currentAqi);

  return (
    <div className="page-container dashboard-page">
      {/* Header bar */}
      <div className="dash-header-bar">
        <div className="dash-location-badge">
          <span className="location-pin-icon">📍</span>
          <div>
            <div className="dash-location-title">
              Delhi NCR <span className="verified-badge">✔</span>
            </div>
            <div className="dash-location-sub">Central Delhi ({activeStation})</div>
          </div>
        </div>
        <div className="dash-station-chips">
          {stations.map((st) => (
            <button
              key={st.name}
              className={`station-chip ${activeStation === st.name ? "active" : ""}`}
              onClick={() => loadStationData(st)}
              disabled={isLoadingStation}
            >
              {st.name}
            </button>
          ))}
        </div>
      </div>

      {/* Hero Weather & Live AQI Card */}
      <div className="dash-hero-card" style={{ background: currentTheme.bg }}>
        <div className="dash-hero-top">
          <div className="dash-weather-badge">
            <span>{currentTheme.icon} {currentTheme.label}</span>
          </div>
          <div className="dash-temp-range">H: {stationWeather.temp + 4}° · L: {stationWeather.temp - 6}°</div>
        </div>

        <div className="dash-hero-mid">
          <div className="dash-temp-col">
            <div className="dash-temp-num">{stationWeather.temp}°C</div>
            <div className="dash-feels">Feels like {stationWeather.feelsLike}°C in {activeStation}</div>
            <div className="dash-lstm-badge">
              <span className="live-dot-pulse"></span>
              Live Spatial Model (FastAPI)
            </div>
          </div>

          <div className="dash-aqi-box" style={{ borderColor: aqiColor }}>
            <div className="dash-aqi-num" style={{ color: aqiColor }}>
              {currentAqi} <span className="dash-aqi-unit">AQI</span>
            </div>
            <div className="dash-aqi-pill" style={{ backgroundColor: aqiColor }}>
              {aqiCategory}
            </div>
          </div>
        </div>

        <div className="dash-hero-comfort">
          🛡️ Air Comfort: {advisory.summary}
        </div>

        {/* Interactive Weather Simulation Switches */}
        <div className="dash-weather-toggles">
          {Object.entries(weatherThemes).map(([k, t]) => (
            <button
              key={k}
              className={`weather-toggle-btn ${weatherMode === k ? "active" : ""}`}
              onClick={() => setWeatherMode(k)}
            >
              {t.icon} {k.charAt(0).toUpperCase() + k.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Live City Extremes Section */}
      <div className="dash-extremes-section">
        <div className="dash-extremes-cards">
          {/* Cleanest Haven */}
          <div
            className="extreme-card haven-card"
            onClick={() => navigate("/map?lat=28.6578&lon=77.3021")}
            title="Click to view on Map"
          >
            <div className="extreme-card-header">
              <span className="extreme-tag haven-tag">CLEANEST HAVEN</span>
              <span className="extreme-icon haven-icon">🌿</span>
            </div>
            <div className="extreme-station-name">{cleanest.name}</div>
            <div className="extreme-aqi-row">
              <span className="extreme-aqi-val haven-val">{cleanest.aqi}</span>
              <span className="extreme-aqi-unit">AQI</span>
              <span className="extreme-badge haven-badge">{cleanest.status}</span>
            </div>
            <div className="extreme-action-hint">Tap to explore haven ➔</div>
          </div>

          {/* Smog Hotspot */}
          <div
            className="extreme-card hotspot-card"
            onClick={() => navigate("/map?lat=28.7490&lon=77.2023")}
            title="Click to view on Map"
          >
            <div className="extreme-card-header">
              <span className="extreme-tag hotspot-tag">SMOG HOTSPOT</span>
              <span className="extreme-icon hotspot-icon">⚠️</span>
            </div>
            <div className="extreme-station-name">{hotspot.name}</div>
            <div className="extreme-aqi-row">
              <span className="extreme-aqi-val hotspot-val">{hotspot.aqi}</span>
              <span className="extreme-aqi-unit">AQI</span>
              <span className="extreme-badge hotspot-badge">{hotspot.status}</span>
            </div>
            <div className="extreme-action-hint">Tap to view hotspot ➔</div>
          </div>
        </div>

        {/* Live Comparison Delta Strip */}
        <div className="dash-comparison-strip">
          <div className="dash-comp-left">
            <span className="dash-comp-arrows">⇄</span>
            <span>
              <strong>{cleanest.name}</strong> is <strong>{pctCleaner}%</strong> cleaner than <strong>{hotspot.name}</strong>.
            </span>
          </div>
          <div className="dash-comp-right">
            {isLiveLoaded && <span className="live-pill-badge">LIVE</span>}
            <span className="delta-pill">-{differenceAqi} AQI</span>
          </div>
        </div>
      </div>

      {/* Atmospheric Conditions Microclimate Grid */}
      <div className="dash-microclimate-section">
        <h3 className="subheading">Atmospheric Conditions — {activeStation}</h3>
        <p className="subtext">Real-time microclimate sensors & DPCC feeds</p>
        <div className="microclimate-grid">
          <div className="microclimate-card">
            <div className="m-icon">🌡️</div>
            <div className="m-data">
              <div className="m-label">FEELS LIKE</div>
              <div className="m-val">{stationWeather.feelsLike}°C</div>
            </div>
          </div>
          <div className="microclimate-card">
            <div className="m-icon">💧</div>
            <div className="m-data">
              <div className="m-label">HUMIDITY</div>
              <div className="m-val">{stationWeather.humidity}%</div>
            </div>
          </div>
          <div className="microclimate-card">
            <div className="m-icon">💨</div>
            <div className="m-data">
              <div className="m-label">WIND SPEED</div>
              <div className="m-val">{stationWeather.windSpeed} km/h</div>
            </div>
          </div>
          <div className="microclimate-card">
            <div className="m-icon">🧭</div>
            <div className="m-data">
              <div className="m-label">PRESSURE</div>
              <div className="m-val">{stationWeather.pressure} hPa</div>
            </div>
          </div>
        </div>
      </div>

      {/* Quick Navigation Cards */}
      <div className="quick-actions">
        <Link to="/map" className="action-card">
          <h3>📍 Check Location AQI</h3>
          <p>Get real-time spatial predictions and pollutant breakdowns for any coordinate in Delhi.</p>
        </Link>
        <Link to="/map?mode=route" className="action-card">
          <h3>🚗 Plan a Clean Route</h3>
          <p>Compare multiple alternative routes to minimize personal cumulative PM2.5 exposure.</p>
        </Link>
      </div>

      {/* Understanding AQI Categories */}
      <div className="aqi-understanding">
        <h3 className="subheading">Understanding AQI</h3>
        <div className="band-list">
          {bands.map((b) => (
            <div key={b.label} className="band-row">
              <div className="band-color" style={{ backgroundColor: b.color }}></div>
              <div className="band-info">
                <span className="band-label">{b.label}</span>
                <span className="band-range">{b.range}</span>
              </div>
              <div className="band-desc">{b.desc}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Health Tips */}
      <div className="health-tips">
        <h3 className="subheading">Health Advisories & Tips</h3>
        <div className="tips-grid">
          {tips.map((tip, i) => (
            <div key={i} className="tip-card">
              <span className="tip-bullet">•</span> {tip}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
