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
    const dateKey = h.datetime.split(" ")[0]; // "2020-06-29"
    if (!byDate[dateKey]) byDate[dateKey] = { temps: [], humidity: [], wind: [] };
    byDate[dateKey].temps.push(h.Temperature_C);
    byDate[dateKey].humidity.push(h.Humidity_pct);
    byDate[dateKey].wind.push(h.WindSpeed_kmh);
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
    if (!data) return [];
    if (view === "hourly") {
      const recent = data.history.slice(-48);
      const lastTime = recent.length > 0 ? new Date(recent[recent.length - 1].datetime).getTime() : null;
      return recent.map((h) => ({
        ...h,
        hoursOffset: lastTime ? Math.round((new Date(h.datetime).getTime() - lastTime) / (1000 * 60 * 60)) : 0,
      }));
    }
    return toDailyAverages(data.history);
  }, [data, view]);

  if (!data) return null;

  const xKey = view === "hourly" ? "hoursOffset" : "daysOffset";
  const formatter = view === "hourly" ? relativeHourLabel : relativeDayLabel;

  return (
    <div className="timeline-chart-wrap">
      <div className="weather-chart-header">
        <div className="section-title" style={{ marginTop: 0, marginBottom: 0 }}>
          Weather — {data.station_name?.replace(", Delhi", "")} ({data.distance_km} km away)
        </div>
        <div className="hourly-daily-switch">
          <button className={view === "hourly" ? "active" : ""} onClick={() => setView("hourly")}>Hourly</button>
          <button className={view === "daily" ? "active" : ""} onClick={() => setView("daily")}>Daily</button>
        </div>
      </div>
      <p className="hint" style={{ marginTop: -4, marginBottom: 10 }}>
        Shown relative to the model's most recent data point — hover a point for the exact date.
      </p>

      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={chartData} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#EAE7DE" />
          <XAxis dataKey={xKey} tickFormatter={formatter} tick={{ fontSize: 10, fill: "#6B7178" }} minTickGap={30} />
          <YAxis tick={{ fontSize: 10, fill: "#6B7178" }} width={32} />
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
          <Line type="monotone" dataKey="Temperature_C" name="Temp (°C)" stroke="#E0533D" strokeWidth={2} dot={false} />
          <Line type="monotone" dataKey="Humidity_pct" name="Humidity (%)" stroke="#2E6E5E" strokeWidth={2} dot={false} />
          <Line type="monotone" dataKey="WindSpeed_kmh" name="Wind (km/h)" stroke="#8A8478" strokeWidth={2} dot={false} />
        </LineChart>
      </ResponsiveContainer>

      <p className="hint" style={{ marginTop: 8 }}>{data.note}</p>
    </div>
  );
}