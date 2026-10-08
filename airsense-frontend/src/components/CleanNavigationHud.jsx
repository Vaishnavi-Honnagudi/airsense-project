import { useState, useEffect } from "react";
import { categorize, categoryColor } from "../lib/aqi";

export default function CleanNavigationHud({
  startLabel = "Origin",
  destinationLabel = "Destination",
  routeAqi = 145,
  distanceKm = 12.4,
  durationMins = 28,
  onExit,
}) {
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [inhaledPm25, setInhaledPm25] = useState(0.8);
  const [speed, setSpeed] = useState(38);

  const steps = [
    {
      instruction: "Head south on Janpath toward Tolstoy Marg",
      distance: "350 m",
      subtext: "Entering low-emission green corridor",
      icon: "⬆️",
      stepAqi: Math.max(30, routeAqi - 12),
    },
    {
      instruction: "Turn left onto Kasturba Gandhi Marg",
      distance: "800 m",
      subtext: "Traffic moving smoothly at 42 km/h",
      icon: "↰",
      stepAqi: Math.max(30, routeAqi - 5),
    },
    {
      instruction: "At the roundabout, take the 2nd exit toward C-Hexagon",
      distance: "1.4 km",
      subtext: "Tree canopy reducing personal PM2.5 inhalation by 25%",
      icon: "🔄",
      stepAqi: Math.max(30, routeAqi - 18),
    },
    {
      instruction: "Continue straight along clean corridor to destination",
      distance: "500 m",
      subtext: "Arriving at low-exposure zone",
      icon: "🏁",
      stepAqi: routeAqi,
    },
  ];

  // Microgram exposure accumulator & step progression simulation
  useEffect(() => {
    const timer = setInterval(() => {
      setInhaledPm25((prev) => parseFloat((prev + 0.15).toFixed(2)));
      setSpeed(Math.floor(34 + Math.random() * 8));
    }, 2000);

    const stepInterval = setInterval(() => {
      setCurrentStepIndex((prev) => (prev < steps.length - 1 ? prev + 1 : prev));
    }, 7000);

    return () => {
      clearInterval(timer);
      clearInterval(stepInterval);
    };
  }, [steps.length]);

  const activeStep = steps[currentStepIndex];
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
          <span className="hud-saving-pill">-34% vs Highway</span>
        </div>

        <div className="hud-telemetry-col">
          <span className="hud-t-label">REMAINING</span>
          <span className="hud-t-val">{Math.max(2, durationMins - currentStepIndex * 6)} <small>min</small></span>
          <span className="hud-sub-dist">{distanceKm} km total</span>
        </div>
      </div>
    </div>
  );
}
