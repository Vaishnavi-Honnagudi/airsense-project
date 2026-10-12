import { useState, useMemo } from "react";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from "recharts";

function formatAbsolute(isoString) {
  const d = new Date(isoString);
  return d.toLocaleString("en-IN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "short" });
}

function relativeHourLabel(hoursOffset) {
  if (hoursOffset === 0) return "Latest";
  return `${hoursOffset}h ago`;
}

function relativeDayLabel(daysOffset) {
  if (daysOffset === 0) return "Latest";
  return `${daysOffset}d ago`;
}

function toDailyAverages(history) {
  const byDate = {};
  history.forEach((h) => {
    const dateKey = (h.datetime || "").split(" ")[0];
    if (!byDate[dateKey]) byDate[dateKey] = { temps: [], humidity: [], wind: [] };
    byDate[dateKey].temps.push(Number(h.Temperature_C ?? h.temperature ?? 28));
    byDate[dateKey].humidity.push(Number(h.Humidity_pct ?? h.humidity ?? 54));
    byDate[dateKey].wind.push(Number(h.WindSpeed_kmh ?? h.wind_speed ?? 10));
  });

  const avg = (arr) => arr.reduce((a, b) => a + b, 0) / arr.length;
  const dateKeys = Object.keys(byDate).sort();
  const lastIdx = dateKeys.length - 1;

  return dateKeys.map((date, i) => ({
    daysOffset: lastIdx - i,
    absoluteDate: date,
    Temperature_C: Math.round(avg(byDate[date].temps) * 10) / 10,
    Humidity_pct: Math.round(avg(byDate[date].humidity) * 10) / 10,
    WindSpeed_kmh: Math.round(avg(byDate[date].wind) * 10) / 10,
  }));
}

export default function WeatherHistoryChart({ data }) {
  const [view, setView] = useState("hourly"); // "hourly" | "daily"

  const chartData = useMemo(() => {
    if (!data || !Array.isArray(data.history)) return [];
    if (view === "hourly") {
      const recent = data.history.slice(-48);
      const lastTime = recent.length > 0 ? new Date(recent[recent.length - 1].datetime).getTime() : null;
      return recent.map((h) => ({
        ...h,
        Temperature_C: Number(h.Temperature_C ?? h.temperature ?? 28),
        Humidity_pct: Number(h.Humidity_pct ?? h.humidity ?? 54),
        WindSpeed_kmh: Number(h.WindSpeed_kmh ?? h.wind_speed ?? 10),
        hoursOffset: lastTime ? Math.round((new Date(h.datetime).getTime() - lastTime) / (1000 * 60 * 60)) : 0,
      }));
    }
    return toDailyAverages(data.history);
  }, [data, view]);

  if (!data || chartData.length === 0) return null;

  const temps = chartData.map((d) => d.Temperature_C);
  const hums = chartData.map((d) => d.Humidity_pct);
  const winds = chartData.map((d) => d.WindSpeed_kmh);
  const minTemp = Math.min(...temps).toFixed(1);
  const maxTemp = Math.max(...temps).toFixed(1);
  const avgHum = Math.round(hums.reduce((a, b) => a + b, 0) / hums.length);
  const maxWind = Math.max(...winds).toFixed(1);

  const xKey = view === "hourly" ? "hoursOffset" : "daysOffset";
  const formatter = view === "hourly" ? relativeHourLabel : relativeDayLabel;

  return (
    <div className="timeline-chart-wrap">
      <div className="weather-chart-header">
        <div className="section-title" style={{ marginTop: 0, marginBottom: 0 }}>
          Weather — {data.station_name?.replace(", Delhi", "") || "Local Station"} ({data.distance_km ?? 0.5} km away)
        </div>
        <div className="hourly-daily-switch">
          <button className={view === "hourly" ? "active" : ""} onClick={() => setView("hourly")}>Hourly</button>
          <button className={view === "daily" ? "active" : ""} onClick={() => setView("daily")}>Daily</button>
        </div>
      </div>

      {/* Location-specific microclimate summary strip */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 6, margin: "8px 0 10px" }}>
        <div style={{ background: "#F5F3EE", padding: "6px 8px", borderRadius: 7, border: "1px solid #EAE7DE" }}>
          <div style={{ fontSize: 9.5, color: "#6B7178", fontWeight: 700 }}>TEMP RANGE</div>
          <div style={{ fontSize: 12.5, fontWeight: 800, color: "#E0533D" }}>{minTemp}°–{maxTemp}°C</div>
        </div>
        <div style={{ background: "#F5F3EE", padding: "6px 8px", borderRadius: 7, border: "1px solid #EAE7DE" }}>
          <div style={{ fontSize: 9.5, color: "#6B7178", fontWeight: 700 }}>AVG HUMIDITY</div>
          <div style={{ fontSize: 12.5, fontWeight: 800, color: "#2E6E5E" }}>{avgHum}% RH</div>
        </div>
        <div style={{ background: "#F5F3EE", padding: "6px 8px", borderRadius: 7, border: "1px solid #EAE7DE" }}>
          <div style={{ fontSize: 9.5, color: "#6B7178", fontWeight: 700 }}>PEAK WIND</div>
          <div style={{ fontSize: 12.5, fontWeight: 800, color: "#1C2530" }}>{maxWind} km/h</div>
        </div>
      </div>

      <ResponsiveContainer width="100%" height={225}>
        <LineChart data={chartData} margin={{ top: 10, right: 6, left: 4, bottom: 2 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#EAE7DE" />
          <XAxis dataKey={xKey} tickFormatter={formatter} tick={{ fontSize: 10, fill: "#6B7178" }} minTickGap={30} />
          <YAxis
            yAxisId="left"
            tick={{ fontSize: 10, fill: "#E0533D" }}
            width={34}
            domain={[
              (dMin) => Math.max(0, Math.floor((Number.isFinite(dMin) ? dMin : 5) - 2)),
              (dMax) => Math.ceil((Number.isFinite(dMax) ? dMax : 35) + 2),
            ]}
          />
          <YAxis
            yAxisId="right"
            orientation="right"
            tick={{ fontSize: 10, fill: "#2E6E5E" }}
            width={34}
            domain={[
              (dMin) => Math.max(10, Math.floor((Number.isFinite(dMin) ? dMin : 30) - 5)),
              (dMax) => Math.min(100, Math.ceil((Number.isFinite(dMax) ? dMax : 80) + 5)),
            ]}
          />
          <Tooltip
            labelFormatter={(val, payload) => {
              const point = payload?.[0]?.payload;
              if (!point) return formatter(val);
              const abs = view === "hourly" ? formatAbsolute(point.datetime) : point.absoluteDate;
              return `${formatter(val)} · ${abs}`;
            }}
            contentStyle={{ fontSize: 12, borderRadius: 8, border: "1px solid #DAD6C9" }}
          />
          <Legend wrapperStyle={{ fontSize: 11 }} />
          <Line yAxisId="left" type="monotone" dataKey="Temperature_C" name="Temp (°C)" stroke="#E0533D" strokeWidth={2.3} dot={view === "daily"} />
          <Line yAxisId="right" type="monotone" dataKey="Humidity_pct" name="Humidity (%)" stroke="#2E6E5E" strokeWidth={2.2} dot={view === "daily"} />
          <Line yAxisId="left" type="monotone" dataKey="WindSpeed_kmh" name="Wind (km/h)" stroke="#5C6B73" strokeWidth={2} strokeDasharray="4 3" dot={view === "daily"} />
        </LineChart>
      </ResponsiveContainer>

      <p className="hint" style={{ marginTop: 8 }}>{data.note}</p>
    </div>
  );
}