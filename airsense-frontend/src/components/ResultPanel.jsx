import { categorize, categoryColor, getAgeGroup, isConcerningForAgeGroup, getAdvisory } from "../lib/aqi";
import TrafficGauge from "./TrafficGauge";
import CommuteOptimizer from "./CommuteOptimizer";

function HealthAdvisory({ aqi, ageGroup, healthNote }) {
  const advisory = getAdvisory(aqi);
  const category = categorize(aqi);
  const hasNote = healthNote && healthNote.trim();
  const thresholdMet = isConcerningForAgeGroup(aqi, ageGroup);
  const concerning = thresholdMet || hasNote;
  const group = getAgeGroup(ageGroup);

  return (
    <div className="advisory-block">
      <div className="section-title">Health advisory</div>
      <p className="advisory-summary">{advisory.summary}</p>

      <ul className="advisory-actions">
        {advisory.actions.map((action, i) => (
          <li key={i}>{action}</li>
        ))}
      </ul>

      {concerning && (
        <div className="health-callout">
          <div className="health-callout-label">{thresholdMet ? `For ${group.label.toLowerCase()}s` : "Worth noting"}</div>
          <div className="health-callout-text">
            {thresholdMet ? (
              <>
                {group.note} Current reading is {category} ({aqi.toFixed(1)} AQI).
                {hasNote ? ` You also noted: "${healthNote.trim()}" — worth keeping in mind alongside the guidance above.` : ""}
              </>
            ) : (
              <>
                You noted: "{healthNote.trim()}". Current air quality is {category} ({aqi.toFixed(1)} AQI) — generally low risk, but keep this in mind if you notice any symptoms.
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export function LocationResult({ data, healthNote, ageGroup }) {
  if (!data) return null;
  const category = data.category || categorize(data.interpolated_aqi);
  const color = categoryColor(category);

  return (
    <div className="result">
      <div className="aqi-headline">
        <div className="aqi-number">{data.interpolated_aqi}</div>
        <div className="aqi-category-pill" style={{ background: color }}>
          {category}
        </div>
      </div>

      <HealthAdvisory aqi={data.interpolated_aqi} ageGroup={ageGroup} healthNote={healthNote} />

      {((data.contributing_stations || data.nearest_stations || []).length > 0) && (
        <>
          <div className="section-title">Nearby stations used</div>
          {(data.contributing_stations || data.nearest_stations || []).map((s, i) => (
            <div className="pollutant-row" key={i}>
              <span>{(s.station || s.station_name || "").replace(", Delhi", "")}</span>
              <span>
                {s.predicted_aqi} AQI &middot; {s.distance_km} km
              </span>
            </div>
          ))}
        </>
      )}
    </div>
  );
}

export function RouteOptionsResult({ routes, selectedIndex, onSelectRoute, onStartNavigation, healthNote, ageGroup }) {
  if (!routes || routes.length === 0) return null;
  const data = routes[selectedIndex];
  const avgCategory = categorize(data.average_aqi_exposure);
  const peakCategory = categorize(data.peak_aqi_exposure);

  return (
    <div className="result">
      {routes.length > 1 && (
        <>
          <div className="section-title" style={{ marginTop: 0 }}>
            {routes.length} route{routes.length > 1 ? "s" : ""} compared
          </div>
          <div className="route-option-list">
            {routes.map((r, i) => (
              <button
                key={i}
                className={`route-option-card ${i === selectedIndex ? "selected" : ""}`}
                onClick={() => onSelectRoute(i)}
              >
                <div className="route-option-top">
                  <span className="route-option-name">
                    Route {i + 1}
                    {r.recommended && <span className="recommended-badge">Recommended</span>}
                  </span>
                  <span className="route-option-aqi" style={{ color: categoryColor(r.average_aqi_exposure) }}>
                    {r.average_aqi_exposure} AQI
                  </span>
                </div>
                <div className="route-option-meta">
                  {r.route_distance_km} km &middot; {r.route_duration_min} min &middot; {r.traffic_level} traffic
                </div>
              </button>
            ))}
          </div>
        </>
      )}

      <div className="aqi-headline" style={{ marginTop: 18 }}>
        <div className="aqi-number">{data.average_aqi_exposure}</div>
        <div className="aqi-category-pill" style={{ background: categoryColor(avgCategory) }}>
          {avgCategory}
        </div>
      </div>
      <div className="advisory">
        Average exposure across the trip &middot; Peak {data.peak_aqi_exposure} AQI ({peakCategory})
      </div>

      <HealthAdvisory aqi={data.peak_aqi_exposure} ageGroup={ageGroup} healthNote={healthNote} />

      <div className="stat-grid">
        <StatCard k="Distance" v={`${data.route_distance_km} km`} />
        <StatCard k="Duration" v={`${data.route_duration_min} min`} />
      </div>

      <TrafficGauge level={data.traffic_level} congestionPct={data.congestion_percentage} avgSpeed={data.average_speed_kmh} />

      {data.weather && (
        <>
          <div className="section-title">Weather along route</div>
          <div className="pollutant-row">
            <span>Temperature</span>
            <span>{data.weather.Temperature_C}&deg;C</span>
          </div>
          <div className="pollutant-row">
            <span>Humidity</span>
            <span>{data.weather.Humidity_pct}%</span>
          </div>
          <div className="pollutant-row">
            <span>Wind speed</span>
            <span>{data.weather.WindSpeed_kmh} km/h</span>
          </div>
        </>
      )}

      {/* Dynamic Departure Window Optimizer matching mobile app */}
      <CommuteOptimizer
        currentRouteAqi={data.average_aqi_exposure}
        baseDurationMins={data.route_duration_min}
      />

      {/* Start Clean Navigation Button */}
      <button
        type="button"
        className="start-nav-btn"
        onClick={() => onStartNavigation && onStartNavigation(data)}
      >
        🧭 Start Clean Navigation HUD
      </button>
    </div>
  );
}

export function StationResult({ data, healthNote, ageGroup }) {
  if (!data) return null;
  const color = categoryColor(data.health_category);
  const pollutantEntries = Object.entries(data.latest_pollutant_readings || {});

  return (
    <div className="result">
      <div className="aqi-headline">
        <div className="aqi-number">{data.predicted_aqi}</div>
        <div className="aqi-category-pill" style={{ background: color }}>
          {data.health_category}
        </div>
      </div>

      <HealthAdvisory aqi={data.predicted_aqi} ageGroup={ageGroup} healthNote={healthNote} />

      <div className="stat-grid">
        <StatCard k="Confidence low" v={data.confidence_interval.lower_bound} />
        <StatCard k="Confidence high" v={data.confidence_interval.upper_bound} />
      </div>

      {data.latest_weather && (
        <>
          <div className="section-title">Latest weather</div>
          <div className="pollutant-row">
            <span>Temperature</span>
            <span>{data.latest_weather.Temperature_C}&deg;C</span>
          </div>
          <div className="pollutant-row">
            <span>Humidity</span>
            <span>{data.latest_weather.Humidity_pct}%</span>
          </div>
          <div className="pollutant-row">
            <span>Wind speed</span>
            <span>{data.latest_weather.WindSpeed_kmh} km/h</span>
          </div>
        </>
      )}

      <div className="section-title">Pollutant breakdown</div>
      {pollutantEntries.map(([name, value]) => (
        <div className="pollutant-row" key={name}>
          <span>{name}</span>
          <span>{value}</span>
        </div>
      ))}
    </div>
  );
}

function StatCard({ k, v }) {
  return (
    <div className="stat-card">
      <div className="k">{k}</div>
      <div className="v">{v}</div>
    </div>
  );
}