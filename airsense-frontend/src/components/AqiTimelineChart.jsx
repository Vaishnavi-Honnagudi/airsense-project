import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine, ResponsiveContainer } from "recharts";
import { categoryColor } from "../lib/aqi";

function formatAbsolute(isoString) {
  const d = new Date(isoString);
  return d.toLocaleString("en-IN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "short" });
}

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
      pastAqi: Number(p.aqi),
      futureAqi: null,
    })),
  ];
  if (past.length > 0) {
    merged[merged.length - 1].futureAqi = Number(past[past.length - 1].aqi);
  }
  future.forEach((f) => {
    merged.push({
      time: f.datetime,
      hoursOffset: hoursFromNow(f.datetime),
      pastAqi: null,
      futureAqi: Number(f.predicted_aqi),
    });
  });

  const allVals = [
    ...past.map((p) => Number(p.aqi)),
    ...future.map((f) => Number(f.predicted_aqi)),
  ].filter((v) => Number.isFinite(v));

  const nowVal = past.length > 0 ? Number(past[past.length - 1].aqi) : 120;
  const minVal = allVals.length > 0 ? Math.min(...allVals) : 60;
  const maxVal = allVals.length > 0 ? Math.max(...allVals) : 200;
  const endForecastVal = future.length > 0 ? Number(future[future.length - 1].predicted_aqi) : nowVal;
  const deltaPct = nowVal > 0 ? Math.round(((endForecastVal - nowVal) / nowVal) * 100) : 0;
  const cpcbRef = maxVal > 180 ? 200 : 100;

  return (
    <div className="timeline-chart-wrap">
      <div className="section-title" style={{ marginTop: 0, display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 6 }}>
        <span>AQI trend — {data.station_name?.replace(", Delhi", "")} ({data.distance_km} km away)</span>
        {data.dispersion_regime && (
          <span style={{ fontSize: 10.5, fontWeight: 700, padding: "2px 8px", borderRadius: 999, background: "#EAE7DE", color: "#1C2530" }}>
            {data.dispersion_regime}
          </span>
        )}
      </div>

      {/* Location-specific dynamic trajectory summary strip */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6, margin: "8px 0 10px" }}>
        <div style={{ background: "#F5F3EE", padding: "6px 8px", borderRadius: 7, border: "1px solid #EAE7DE" }}>
          <div style={{ fontSize: 9.5, color: "#6B7178", fontWeight: 700 }}>NOW</div>
          <div style={{ fontSize: 13.5, fontWeight: 800, color: categoryColor(nowVal) }}>{nowVal.toFixed(1)}</div>
        </div>
        <div style={{ background: "#F5F3EE", padding: "6px 8px", borderRadius: 7, border: "1px solid #EAE7DE" }}>
          <div style={{ fontSize: 9.5, color: "#6B7178", fontWeight: 700 }}>48H MIN</div>
          <div style={{ fontSize: 13.5, fontWeight: 800, color: "#2E6E5E" }}>{minVal.toFixed(1)}</div>
        </div>
        <div style={{ background: "#F5F3EE", padding: "6px 8px", borderRadius: 7, border: "1px solid #EAE7DE" }}>
          <div style={{ fontSize: 9.5, color: "#6B7178", fontWeight: 700 }}>48H PEAK</div>
          <div style={{ fontSize: 13.5, fontWeight: 800, color: "#E0533D" }}>{maxVal.toFixed(1)}</div>
        </div>
        <div style={{ background: "#F5F3EE", padding: "6px 8px", borderRadius: 7, border: "1px solid #EAE7DE" }}>
          <div style={{ fontSize: 9.5, color: "#6B7178", fontWeight: 700 }}>24H DRIFT</div>
          <div style={{ fontSize: 13, fontWeight: 800, color: deltaPct > 2 ? "#E0533D" : deltaPct < -2 ? "#2E6E5E" : "#1C2530" }}>
            {deltaPct > 0 ? `+${deltaPct}% ↑` : deltaPct < 0 ? `${deltaPct}% ↓` : "Stable →"}
          </div>
        </div>
      </div>

      <ResponsiveContainer width="100%" height={230}>
        <LineChart data={merged} margin={{ top: 12, right: 12, left: 4, bottom: 2 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#EAE7DE" />
          <XAxis
            dataKey="hoursOffset"
            tickFormatter={relativeLabel}
            tick={{ fontSize: 10, fill: "#6B7178" }}
            interval="preserveStartEnd"
            minTickGap={40}
          />
          <YAxis
            tick={{ fontSize: 10, fill: "#6B7178" }}
            width={40}
            domain={[
              (dataMin) => Math.max(0, Math.floor((Number.isFinite(dataMin) ? dataMin : 50) - 14)),
              (dataMax) => Math.ceil((Number.isFinite(dataMax) ? dataMax : 200) + 14),
            ]}
          />
          <Tooltip
            labelFormatter={(hoursOffset, payload) => {
              const point = payload?.[0]?.payload;
              return point ? `${relativeLabel(hoursOffset)} · ${formatAbsolute(point.time)}` : relativeLabel(hoursOffset);
            }}
            formatter={(value, name) => [`${value} AQI`, name === "pastAqi" ? "Observed (IDW)" : "LSTM Forecast"]}
            contentStyle={{ fontSize: 12, borderRadius: 8, border: "1px solid #DAD6C9" }}
          />
          <ReferenceLine
            x={0}
            stroke="#1C2530"
            strokeDasharray="4 4"
            label={{ value: "Now", fontSize: 10, fill: "#1C2530", position: "top" }}
          />
          <ReferenceLine
            y={cpcbRef}
            stroke={cpcbRef === 200 ? "#D97706" : "#2E6E5E"}
            strokeDasharray="2 4"
            strokeOpacity={0.55}
            label={{ value: `CPCB ${cpcbRef}`, fontSize: 9, fill: "#6B7178", position: "insideTopRight" }}
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

      <p className="hint" style={{ marginTop: 8 }}>
        {data.note} Latest reference timestamp: {past.length > 0 ? formatAbsolute(past[past.length - 1].datetime) : "Live IST"}.
      </p>
    </div>
  );
}