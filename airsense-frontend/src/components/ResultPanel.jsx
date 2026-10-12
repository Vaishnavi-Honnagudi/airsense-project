import { useMemo } from "react";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from "recharts";
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

      {data.latest_weather && (
        <>
          <div className="section-title">Microclimate at this coordinate</div>
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

      {((data.contributing_stations || data.nearest_stations || []).length > 0) && (
        <>
          <div className="section-title">Nearby stations used (IDW)</div>
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

function RouteCorridorChart({ routes, selectedIndex }) {
  const chartData = useMemo(() => {
    if (!routes || routes.length === 0) return [];
    const maxPts = Math.max(...routes.map((r) => (r.route_points || []).length), 2);
    const selectedRoute = routes[selectedIndex] || routes[0];
    const totalDist = Number(selectedRoute.route_distance_km || 5.0);

    const rows = [];
    for (let idx = 0; idx < maxPts; idx++) {
      const frac = idx / Math.max(1, maxPts - 1);
      const row = {
        checkpoint: idx === 0 ? "Start" : idx === maxPts - 1 ? "End" : `${(totalDist * frac).toFixed(1)}km`,
      };
      routes.forEach((r, rIdx) => {
        const pts = r.route_points || [];
        if (pts.length > 0) {
          const mappedIdx = Math.min(pts.length - 1, Math.round(frac * (pts.length - 1)));
          row[`route${rIdx + 1}`] = Number(pts[mappedIdx].predicted_aqi);
        }
      });
      rows.push(row);
    }
    return rows;
  }, [routes, selectedIndex]);

  if (chartData.length < 2) return null;

  const colors = ["#2E6E5E", "#E0533D", "#5C6B73"];

  return (
    <div className="timeline-chart-wrap" style={{ marginTop: 16 }}>
      <div className="section-title" style={{ marginTop: 0 }}>
        Corridor AQI exposure profile (Start ➔ Destination)
      </div>
      <p className="hint" style={{ marginTop: -4, marginBottom: 8 }}>
        Checkpoint-by-checkpoint PM2.5/AQI interpolation along each candidate road corridor.
      </p>
      <ResponsiveContainer width="100%" height={205}>
        <LineChart data={chartData} margin={{ top: 8, right: 10, left: 2, bottom: 2 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#EAE7DE" />
          <XAxis dataKey="checkpoint" tick={{ fontSize: 10, fill: "#6B7178" }} interval="preserveStartEnd" />
          <YAxis
            tick={{ fontSize: 10, fill: "#6B7178" }}
            width={36}
            domain={[
              (dMin) => Math.max(10, Math.floor((Number.isFinite(dMin) ? dMin : 50) - 12)),
              (dMax) => Math.ceil((Number.isFinite(dMax) ? dMax : 200) + 12),
            ]}
          />
          <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8, border: "1px solid #DAD6C9" }} />
          <Legend wrapperStyle={{ fontSize: 11 }} />
          {routes.map((r, i) => (
            <Line
              key={i}
              type="monotone"
              dataKey={`route${i + 1}`}
              name={`Route ${i + 1} (${r.corridor_label || "Corridor"})`}
              stroke={colors[i % colors.length]}
              strokeWidth={i === selectedIndex ? 3 : 1.6}
              strokeDasharray={i === selectedIndex ? undefined : "4 3"}
              dot={i === selectedIndex ? { r: 3 } : false}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

export function RouteOptionsResult({ routes, selectedIndex, onSelectRoute, onStartNavigation, healthNote, ageGroup }) {
  if (!routes || routes.length === 0) return null;
  const data = routes[selectedIndex] || routes[0];
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
                    Route {i + 1} {r.corridor_label ? `· ${r.corridor_label}` : ""}
                    {r.recommended && <span className="recommended-badge">Recommended</span>}
                  </span>
                  <span className="route-option-aqi" style={{ color: categoryColor(r.average_aqi_exposure) }}>
                    {r.average_aqi_exposure} AQI
                  </span>
                </div>
                <div className="route-option-meta">
                  {r.route_distance_km} km &middot; {r.route_duration_min} min &middot; {r.traffic_level} traffic ({r.congestion_percentage ?? 30}%)
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
        Average exposure across {data.corridor_label || `Route ${selectedIndex + 1}`} &middot; Peak {data.peak_aqi_exposure} AQI ({peakCategory})
      </div>

      {/* Interactive checkpoint-by-checkpoint AQI profile graph across the routes */}
      <RouteCorridorChart routes={routes} selectedIndex={selectedIndex} />

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

      {/* Dynamic Departure Window Optimizer with 8h forecast curve */}
      <CommuteOptimizer
        currentRouteAqi={data.average_aqi_exposure}
        baseDurationMins={data.route_duration_min}
        congestionPct={data.congestion_percentage ?? 34}
        corridorLabel={data.corridor_label || `Route ${selectedIndex + 1}`}
        routePoints={data.route_points || []}
        departureForecast={data.departure_forecast || null}
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