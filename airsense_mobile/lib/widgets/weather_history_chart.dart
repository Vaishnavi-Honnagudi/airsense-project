import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class WeatherHistoryChart extends StatefulWidget {
  final Map<String, dynamic>? data;

  const WeatherHistoryChart({super.key, this.data});

  @override
  State<WeatherHistoryChart> createState() => _WeatherHistoryChartState();
}

class _WeatherHistoryChartState extends State<WeatherHistoryChart> {
  String _view = "hourly"; // "hourly" | "daily"

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) return const SizedBox.shrink();

    final history = (widget.data!["history"] as List<dynamic>?) ?? [];
    final stationName = (widget.data!["station_name"] as String? ?? "").replaceAll(", Delhi", "");

    final List<double> tempSpotsY = [];
    final List<double> humiditySpotsY = [];
    final List<double> windSpotsY = [];
    int count;

    if (_view == "hourly") {
      final recent = history.length > 48 ? history.sublist(history.length - 48) : history;
      count = recent.length;
      for (final h in recent) {
        tempSpotsY.add((h["Temperature_C"] as num).toDouble());
        humiditySpotsY.add((h["Humidity_pct"] as num).toDouble());
        windSpotsY.add((h["WindSpeed_kmh"] as num).toDouble());
      }
    } else {
      final byDate = <String, List<Map<String, dynamic>>>{};
      for (final h in history) {
        final dateKey = (h["datetime"] as String).split(" ")[0];
        byDate.putIfAbsent(dateKey, () => []).add(h);
      }
      final sortedDates = byDate.keys.toList()..sort();
      count = sortedDates.length;
      for (final date in sortedDates) {
        final entries = byDate[date]!;
        double avg(String key) => entries.map((e) => (e[key] as num).toDouble()).reduce((a, b) => a + b) / entries.length;
        tempSpotsY.add(avg("Temperature_C"));
        humiditySpotsY.add(avg("Humidity_pct"));
        windSpotsY.add(avg("WindSpeed_kmh"));
      }
    }

    List<FlSpot> toSpots(List<double> ys) {
      final n = ys.length;
      return List.generate(n, (i) => FlSpot((i - (n - 1)).toDouble(), ys[i]));
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, size: 18, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Weather Trends",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        "$stationName · ${widget.data!["distance_km"]} km",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _toggle(),
            ],
          ),

          const SizedBox(height: 16),

          // Interactive Chart
          SizedBox(
            height: 190,
            child: count < 2
                ? const Center(
                    child: Text(
                      "Not enough telemetry data to chart",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => const FlLine(
                          color: Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, m) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: (count / 4).clamp(1, double.infinity),
                            getTitlesWidget: (v, m) {
                              final offset = v.toInt();
                              final label = _view == "hourly"
                                  ? (offset == 0 ? "Latest" : "${offset}h")
                                  : (offset == 0 ? "Latest" : "${offset}d");
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        // Temperature
                        LineChartBarData(
                          spots: toSpots(tempSpotsY),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: const Color(0xFFF97316),
                          barWidth: 2.8,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFFF97316).withValues(alpha: 0.20),
                                const Color(0xFFF97316).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        // Humidity
                        LineChartBarData(
                          spots: toSpots(humiditySpotsY),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: const Color(0xFF0284C7),
                          barWidth: 2.8,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                        // Wind
                        LineChartBarData(
                          spots: toSpots(windSpotsY),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: const Color(0xFF0D9488),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots.map((s) {
                            String unit = "";
                            if (s.barIndex == 0) unit = "°C";
                            if (s.barIndex == 1) unit = "%";
                            if (s.barIndex == 2) unit = " km/h";
                            return LineTooltipItem(
                              "${s.y.toStringAsFixed(1)}$unit",
                              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 14),

          // Legend Row
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _legendPill("Temp (°C)", const Color(0xFFF97316)),
              _legendPill("Humidity (%)", const Color(0xFF0284C7)),
              _legendPill("Wind (km/h)", const Color(0xFF0D9488)),
            ],
          ),

          if ((widget.data!["note"] as String? ?? "").isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "${widget.data!["note"]}",
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton("Hourly", "hourly"),
          _toggleButton("Daily", "daily"),
        ],
      ),
    );
  }

  Widget _toggleButton(String text, String value) {
    final active = _view == value;
    return GestureDetector(
      onTap: () => setState(() => _view = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _legendPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
