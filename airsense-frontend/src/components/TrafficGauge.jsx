function trafficColor(level) {
  if (level === "Light") return "#4CAF50";
  if (level === "Moderate") return "#F4C542";
  return "#E0533D"; // Heavy
}

export default function TrafficGauge({ level, congestionPct, avgSpeed }) {
  const pct = congestionPct ?? 0;
  const color = trafficColor(level);

  return (
    <div className="traffic-gauge">
      <div className="traffic-gauge-top">
        <span className="traffic-gauge-label" style={{ color }}>{level || "Unknown"} traffic</span>
        <span className="traffic-gauge-pct">{pct}% congestion</span>
      </div>
      <div className="traffic-gauge-track">
        <div className="traffic-gauge-fill" style={{ width: `${pct}%`, background: color }} />
      </div>
      {avgSpeed != null && (
        <div className="traffic-gauge-speed">Average speed: {avgSpeed} km/h</div>
      )}
    </div>
  );
}
