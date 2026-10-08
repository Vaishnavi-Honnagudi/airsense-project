import { useState } from "react";
import { categorize, categoryColor } from "../lib/aqi";

export default function CommuteOptimizer({ currentRouteAqi = 180, baseDurationMins = 35 }) {
  const [hourOffset, setHourOffset] = useState(2); // default +2 hours

  const now = new Date();
  const departureDate = new Date(now.getTime() + hourOffset * 60 * 60 * 1000);
  const targetHour = departureDate.getHours();

  let aqiFactor = 0.90;
  let trafficDelayMins = 10;

  if (targetHour >= 18 && targetHour <= 20) {
    // Peak evening rush + ground inversion
    aqiFactor = 1.15;
    trafficDelayMins = 18;
  } else if (targetHour >= 21 || targetHour <= 1) {
    // Night dispersion, less vehicular congestion
    aqiFactor = 0.72;
    trafficDelayMins = 3;
  } else if (targetHour >= 13 && targetHour <= 16) {
    // Afternoon solar dispersion
    aqiFactor = 0.78;
    trafficDelayMins = 6;
  } else {
    aqiFactor = 0.90;
    trafficDelayMins = 10;
  }

  const projectedAqi = Math.round(Math.min(480, Math.max(40, currentRouteAqi * aqiFactor)));
  const totalDuration = baseDurationMins + trafficDelayMins;
  const aqiColor = categoryColor(projectedAqi);
  const aqiCategory = categorize(projectedAqi);
  const aqiSavings = Math.round(((currentRouteAqi - projectedAqi) / currentRouteAqi) * 100);

  const formattedTime = departureDate.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });

  return (
    <div className="commute-optimizer-card">
      <div className="optimizer-top-row">
        <div className="optimizer-title">
          <span className="optimizer-icon">⏱️</span>
          <div>
            <strong>Departure Window Optimizer</strong>
            <div className="optimizer-sub">Model diurnal atmospheric inversion & rush-hour exposure</div>
          </div>
        </div>
        {aqiSavings > 0 && (
          <span className="savings-badge">
            🌿 {aqiSavings}% Cleaner
          </span>
        )}
      </div>

      <div className="slider-control-row">
        <div className="slider-meta">
          <span>Leave: <strong>{hourOffset === 0 ? "Now" : `in +${hourOffset} hr${hourOffset > 1 ? "s" : ""} (${formattedTime})`}</strong></span>
          <span className="slider-range-hint">+0h to +4h</span>
        </div>
        <input
          type="range"
          min="0"
          max="4"
          step="0.5"
          value={hourOffset}
          onChange={(e) => setHourOffset(parseFloat(e.target.value))}
          className="optimizer-slider"
        />
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
            {trafficDelayMins <= 5 ? "⚡ Free Flow" : `+${trafficDelayMins}m delay`}
          </div>
        </div>
      </div>

      <div className="optimizer-insight">
        {targetHour >= 18 && targetHour <= 20 ? (
          <span>⚠️ <strong>Peak Inversion Warning:</strong> Evening vehicular exhaust trapped near ground. Delaying past 8:30 PM reduces particulate inhalation significantly.</span>
        ) : targetHour >= 21 || targetHour <= 1 ? (
          <span>✨ <strong>Optimal Clean Window:</strong> Traffic volume has subsided and night wind currents have cleared main arterial avenues.</span>
        ) : (
          <span>ℹ️ <strong>Moderate Window:</strong> Reasonable compromise between travel time and personal pollution exposure.</span>
        )}
      </div>
    </div>
  );
}
