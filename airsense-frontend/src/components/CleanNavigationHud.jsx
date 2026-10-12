import { useState, useEffect, useMemo } from "react";
import { categorize, categoryColor } from "../lib/aqi";

export default function CleanNavigationHud({
  startLabel = "Origin",
  destinationLabel = "Destination",
  routeAqi = 145,
  distanceKm = 12.4,
  durationMins = 28,
  corridorLabel = "Green Canopy Bypass",
  routePoints = [],
  onExit,
}) {
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [inhaledPm25, setInhaledPm25] = useState(0.6);
  const [speed, setSpeed] = useState(34);

  const steps = useMemo(() => {
    const pts = Array.isArray(routePoints) && routePoints.length >= 4 ? routePoints : [];
    const aqi0 = pts[0]?.predicted_aqi ?? Math.max(25, Math.round(routeAqi * 0.92));
    const aqi1 = pts[Math.floor(pts.length * 0.35)]?.predicted_aqi ?? Math.max(25, Math.round(routeAqi * 0.96));
    const aqi2 = pts[Math.floor(pts.length * 0.7)]?.predicted_aqi ?? Math.max(25, Math.round(routeAqi * 0.88));
    const aqi3 = pts[pts.length - 1]?.predicted_aqi ?? Math.round(routeAqi);

    const d1 = `${Math.max(0.4, (distanceKm * 0.25)).toFixed(1)} km`;
    const d2 = `${Math.max(0.6, (distanceKm * 0.35)).toFixed(1)} km`;
    const d3 = `${Math.max(0.5, (distanceKm * 0.25)).toFixed(1)} km`;
    const d4 = `${Math.max(0.3, (distanceKm * 0.15)).toFixed(1)} km`;

    return [
      {
        instruction: `Depart ${startLabel} via ${corridorLabel}`,
        distance: d1,
        subtext: `Entering calibrated low-emission segment (${aqi0} AQI)`,
        icon: "⬆️",
        stepAqi: aqi0,
      },
      {
        instruction: `Continue along ${corridorLabel} toward ${destinationLabel}`,
        distance: d2,
        subtext: `Steady corridor flow · avoiding heavy arterial exhaust`,
        icon: "↗️",
        stepAqi: aqi1,
      },
      {
        instruction: `Pass midpoint dispersion zone on ${corridorLabel}`,
        distance: d3,
        subtext: `Green buffer reducing personal PM2.5 inhalation`,
        icon: "🌿",
        stepAqi: aqi2,
      },
      {
        instruction: `Arrive at ${destinationLabel}`,
        distance: d4,
        subtext: `Destination reached · Trip average ${routeAqi} AQI`,
        icon: "🏁",
        stepAqi: aqi3,
      },
    ];
  }, [startLabel, destinationLabel, routeAqi, distanceKm, corridorLabel, routePoints]);

  useEffect(() => {
    const timer = setInterval(() => {
      const increment = Math.max(0.06, (routeAqi / 150) * 0.14);
      setInhaledPm25((prev) => parseFloat((prev + increment).toFixed(2)));
      setSpeed(Math.floor(30 + ((routeAqi % 9) + Math.random() * 7)));
    }, 2000);

    const stepInterval = setInterval(() => {
      setCurrentStepIndex((prev) => (prev < steps.length - 1 ? prev + 1 : prev));
    }, 6500);

    return () => {
      clearInterval(timer);
      clearInterval(stepInterval);
    };
  }, [steps.length, routeAqi]);

  const activeStep = steps[currentStepIndex] || steps[0];
  const stepColor = categoryColor(activeStep.stepAqi);

  return (
    <div className="clean-nav-hud">
      {/* Top Banner Navigation Card */}
      <div className="hud-top-card">
        <div className="hud-step-icon">{activeStep.icon}</div>
        <div className="hud-step-details">
          <div className="hud-instruction">{activeStep.instruction}</div>
          <div className="hud-subtext">{activeStep.subtext}</div>
          <div className="hud-step-meta">
            <span className="hud-step-dist">{activeStep.distance}</span>
            <span className="hud-step-aqi" style={{ color: stepColor }}>
              ● {activeStep.stepAqi} AQI ({categorize(activeStep.stepAqi)})
            </span>
          </div>
        </div>
        <button className="hud-exit-btn" onClick={onExit} title="Exit Navigation">
          ✕
        </button>
      </div>

      {/* Floating Telemetry Strip */}
      <div className="hud-bottom-card">
        <div className="hud-telemetry-col">
          <span className="hud-t-label">DRIVING SPEED</span>
          <span className="hud-t-val">{speed} <small>km/h</small></span>
        </div>

        <div className="hud-telemetry-col highlight-col">
          <span className="hud-t-label">INHALED PM2.5</span>
          <span className="hud-t-val inhaled-val">{inhaledPm25} <small>µg</small></span>
          <span className="hud-saving-pill">{corridorLabel}</span>
        </div>

        <div className="hud-telemetry-col">
          <span className="hud-t-label">REMAINING</span>
          <span className="hud-t-val">{Math.max(2, Math.round(durationMins - currentStepIndex * (durationMins / 4)))} <small>min</small></span>
          <span className="hud-sub-dist">{distanceKm} km total</span>
        </div>
      </div>
    </div>
  );
}
