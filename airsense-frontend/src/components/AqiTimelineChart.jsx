import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine, ResponsiveContainer } from "recharts";
import { categoryColor } from "../lib/aqi";

function formatAbsolute(isoString) {
  const d = new Date(isoString);
  return d.toLocaleString("en-IN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "short" });
}

// Relative-to-"now" label, e.g. "-24h", "-1h", "Now", "+6h" — avoids showing
// the dataset's actual 2020 calendar dates, which can look confusing/wrong
// out of context even though they're accurate to the data the model has.
function relativeLabel(hoursOffset) {
  if (hoursOffset === 0) return "Now";
  return hoursOffset > 0 ? `+${hoursOffset}h` : `${hoursOffset}h`;
}

export default function AqiTimelineChart({ data }) {
  if (!data) return null;

  const past = data.past || [];
  const future = data.future || [];
  const nowTime = past.length > 0 ? new Date(past[past.length - 1].datetime).getTime() : null;

  function hoursFromNow(isoString) {
    if (nowTime === null) return 0;
    return Math.round((new Date(isoString).getTime() - nowTime) / (1000 * 60 * 60));
  }

  const merged = [
    ...past.map((p) => ({
      time: p.datetime,
      hoursOffset: hoursFromNow(p.datetime),
      pastAqi: p.aqi,
      futureAqi: null,
    })),
  ];
  if (past.length > 0) {
    merged[merged.length - 1].futureAqi = past[past.length - 1].aqi;
  }
  future.forEach((f) => {
    merged.push({ time: f.datetime, hoursOffset: hoursFromNow(f.datetime), pastAqi: null, futureAqi: f.predicted_aqi });
  });

  return (
    <div className="timeline-chart-wrap">
      <div className="section-title" style={{ marginTop: 0 }}>
        AQI trend — {data.station_name?.replace(", Delhi", "")} ({data.distance_km} km away)
      </div>
      <p className="hint" style={{ marginTop: -4, marginBottom: 10 }}>
        Shown relative to the model's most recent data point — hover a point for the exact date/time.
      </p>

      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={merged} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#EAE7DE" />
          <XAxis
            dataKey="hoursOffset"
            tickFormatter={relativeLabel}
            tick={{ fontSize: 10, fill: "#6B7178" }}
            interval="preserveStartEnd"
            minTickGap={40}
          />
          <YAxis tick={{ fontSize: 10, fill: "#6B7178" }} width={32} />
          <Tooltip
            labelFormatter={(hoursOffset, payload) => {
              const point = payload?.[0]?.payload;
              return point ? `${relativeLabel(hoursOffset)} · ${formatAbsolute(point.time)}` : relativeLabel(hoursOffset);
            }}
            formatter={(value, name) => [value, name === "pastAqi" ? "Actual" : "Predicted"]}
            contentStyle={{ fontSize: 12, borderRadius: 8, border: "1px solid #DAD6C9" }}
          />
          <ReferenceLine
            x={0}
            stroke="#1C2530"
            strokeDasharray="4 4"
            label={{ value: "Now", fontSize: 10, fill: "#1C2530", position: "top" }}
          />
          <Line
            type="monotone"
            dataKey="pastAqi"
            stroke="#2E6E5E"
            strokeWidth={2.5}
            dot={false}
            connectNulls
            name="pastAqi"
          />
          <Line
            type="monotone"
            dataKey="futureAqi"
            stroke="#E0533D"
            strokeWidth={2.5}
            strokeDasharray="5 4"
            dot={false}
            connectNulls
            name="futureAqi"
          />
        </LineChart>
      </ResponsiveContainer>

      <div className="chart-legend">
        <span><span className="legend-dot" style={{ background: "#2E6E5E" }} /> Actual (past {past.length}h)</span>
        <span><span className="legend-dot dashed" style={{ borderColor: "#E0533D" }} /> Predicted (next {future.length}h)</span>
      </div>

      <p className="hint" style={{ marginTop: 8 }}>{data.note} The model's data currently ends at {past.length > 0 ? formatAbsolute(past[past.length - 1].datetime) : "the dataset's last recorded hour"} — "Now" here refers to that point, not today's actual date.</p>
    </div>
  );
}