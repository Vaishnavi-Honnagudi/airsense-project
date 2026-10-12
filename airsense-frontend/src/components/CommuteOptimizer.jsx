import { useState, useMemo } from "react";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine, ResponsiveContainer } from "recharts";
import { categorize, categoryColor } from "../lib/aqi";
import { diurnalAqiMultiplier } from "../lib/fallback_engine";

export default function CommuteOptimizer({
  currentRouteAqi = 155,
  baseDurationMins = 28,
  congestionPct = 34,
  corridorLabel = "Green Canopy Bypass",
  routePoints = [],
  departureForecast = null,
}) {
  const [hourOffset, setHourOffset] = useState(2);

  const midPoint = useMemo(() => {
    if (Array.isArray(routePoints) && routePoints.length > 0) {
      const m = routePoints[Math.floor(routePoints.length / 2)];
      return { lat: Number(m.lat ?? 28.6315), lon: Number(m.lon ?? 77.2167) };
    }
    return { lat: 28.6315, lon: 77.2167 };
  }, [routePoints]);

  // Build route-specific 8-hour departure curve (+0h to +8h in 1h steps)
  const curveData = useMemo(() => {
    const now = new Date();
    const nowHr = now.getHours() + now.getMinutes() / 60;
    const nowMult = diurnalAqiMultiplier(nowHr, midPoint.lat, midPoint.lon);
    const seed = ((midPoint.lat * 173 + midPoint.lon * 289 + currentRouteAqi) % 6.28);

    const points = [];
    for (let h = 0; h <= 8; h++) {
      const depDate = new Date(now.getTime() + h * 3600 * 1000);
      const timeLabel = h === 0 ? "Now" : `+${h}h`;
      const clockStr = depDate.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });

      if (Array.isArray(departureForecast) && departureForecast[h]) {
        const item = departureForecast[h];
        points.push({
          hourOffset: h,
          label: timeLabel,
          clock: clockStr,
          aqi: Math.round(Number(item.projected_aqi)),
          duration: Math.round(Number(item.estimated_duration_min)),
          delay: Math.round(Number(item.traffic_delay_min ?? 6)),
        });
      } else {
        const futHr = (nowHr + h) % 24;
        const futMult = diurnalAqiMultiplier(futHr, midPoint.lat, midPoint.lon);
        const wave = 0.07 * Math.sin(h * 0.75 + seed);
        const projAqi = Math.round(
          Math.max(22, Math.min(485, currentRouteAqi * (futMult / Math.max(nowMult, 0.7)) * (1 + wave)))
        );
        const isRush = (futHr >= 8 && futHr <= 10.5) || (futHr >= 17.5 && futHr <= 20.5);
        const isNight = futHr >= 22 || futHr <= 5.5;
        const delayM = Math.max(1, Math.round((congestionPct * 0.24) * (isRush ? 1.4 : isNight ? 0.35 : 0.75)));
        points.push({
          hourOffset: h,
          label: timeLabel,
          clock: clockStr,
          aqi: projAqi,
          duration: Math.round(baseDurationMins + delayM),
          delay: delayM,
        });
      }
    }
    return points;
  }, [currentRouteAqi, baseDurationMins, congestionPct, midPoint, departureForecast]);

  const selectedSlot = curveData[Math.min(curveData.length - 1, Math.max(0, Math.round(hourOffset)))] || curveData[0];
  const bestSlot = useMemo(
    () => curveData.reduce((best, cur) => (cur.aqi < best.aqi ? cur : best), curveData[0]),
    [curveData]
  );

  const projectedAqi = selectedSlot.aqi;
  const totalDuration = selectedSlot.duration;
  const trafficDelayMins = selectedSlot.delay;
  const aqiColor = categoryColor(projectedAqi);
  const aqiCategory = categorize(projectedAqi);
  const aqiDeltaPct = Math.round(((currentRouteAqi - projectedAqi) / Math.max(currentRouteAqi, 1)) * 100);

  return (
    <div className="commute-optimizer-card">
      <div className="optimizer-top-row">
        <div className="optimizer-title">
          <span className="optimizer-icon">⏱️</span>
          <div>
            <strong>Departure Window Optimizer</strong>
            <div className="optimizer-sub">{corridorLabel} · Best window: {bestSlot.label} ({bestSlot.aqi} AQI)</div>
          </div>
        </div>
        {aqiDeltaPct > 0 ? (
          <span className="savings-badge">🌿 {aqiDeltaPct}% Cleaner</span>
        ) : aqiDeltaPct < 0 ? (
          <span className="savings-badge" style={{ background: "#FEE2E2", color: "#B91C1C" }}>
            ⚠️ +{Math.abs(aqiDeltaPct)}% Higher
          </span>
        ) : (
          <span className="savings-badge" style={{ background: "#EAE7DE", color: "#1C2530" }}>Baseline</span>
        )}
      </div>

      <div className="slider-control-row">
        <div className="slider-meta">
          <span>
            Leave: <strong>{hourOffset === 0 ? "Now" : `in +${hourOffset}h (${selectedSlot.clock})`}</strong>
          </span>
          <span className="slider-range-hint"> Now to +8h</span>
        </div>
        <input
          type="range"
          min="0"
          max="8"
          step="1"
          value={hourOffset}
          onChange={(e) => setHourOffset(parseInt(e.target.value, 10))}
          className="optimizer-slider"
        />
      </div>

      {/* Route-specific 8h departure forecast curve */}
      <div style={{ width: "100%", height: 145, marginTop: 6, marginBottom: 10 }}>
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={curveData} margin={{ top: 8, right: 10, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="depAqiGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#2E6E5E" stopOpacity={0.32} />
                <stop offset="95%" stopColor="#2E6E5E" stopOpacity={0.03} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#EAE7DE" />
            <XAxis dataKey="label" tick={{ fontSize: 10, fill: "#6B7178" }} />
            <YAxis
              tick={{ fontSize: 10, fill: "#6B7178" }}
              width={34}
              domain={[
                (dMin) => Math.max(10, Math.floor((Number.isFinite(dMin) ? dMin : 50) - 12)),
                (dMax) => Math.ceil((Number.isFinite(dMax) ? dMax : 200) + 12),
              ]}
            />
            <Tooltip
              formatter={(val, name) => [
                name === "aqi" ? `${val} AQI` : `${val} mins`,
                name === "aqi" ? "Projected Exposure" : "Est. Duration",
              ]}
              labelFormatter={(lbl, payload) => {
                const p = payload?.[0]?.payload;
                return p ? `Departure ${lbl} (${p.clock}) · ${p.duration} mins` : lbl;
              }}
              contentStyle={{ fontSize: 11.5, borderRadius: 8, border: "1px solid #DAD6C9" }}
            />
            <ReferenceLine x={selectedSlot.label} stroke="#E0533D" strokeWidth={2} strokeDasharray="3 3" />
            <Area
              type="monotone"
              dataKey="aqi"
              stroke="#2E6E5E"
              strokeWidth={2.2}
              fill="url(#depAqiGrad)"
              dot={{ r: 3, fill: "#2E6E5E" }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      <div className="optimizer-stats-grid">
        <div className="opt-stat">
          <div className="opt-stat-label">PROJECTED AQI</div>
          <div className="opt-stat-val" style={{ color: aqiColor }}>
            {projectedAqi} <span className="opt-unit">AQI</span>
          </div>
          <div className="opt-stat-sub" style={{ backgroundColor: aqiColor }}>{aqiCategory}</div>
        </div>

        <div className="opt-stat">
          <div className="opt-stat-label">EST. COMMUTE DURATION</div>
          <div className="opt-stat-val">{totalDuration} mins</div>
          <div className="opt-stat-sub traffic-sub">
            {trafficDelayMins <= 5 ? "⚡ Free Flow" : `+${trafficDelayMins}m congestion`}
          </div>
        </div>
      </div>

      <div className="optimizer-insight">
        {bestSlot.hourOffset === hourOffset ? (
          <span>
            ✨ <strong>Optimal Window Selected:</strong> Leaving at {selectedSlot.clock} minimizes corridor PM2.5 inhalation ({bestSlot.aqi} AQI).
          </span>
        ) : (
          <span>
            💡 <strong>AI Commute Tip:</strong> Shifting departure to <strong>{bestSlot.label} ({bestSlot.clock})</strong> drops route exposure to <strong>{bestSlot.aqi} AQI</strong> ({bestSlot.duration} mins travel).
          </span>
        )}
      </div>
    </div>
  );
}
