import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

String _relativeLabel(int hoursOffset) {
  if (hoursOffset == 0) return "Now";
  return hoursOffset > 0 ? "+${hoursOffset}h" : "${hoursOffset}h";
}

class AqiTimelineChart extends StatelessWidget {
  final Map<String, dynamic>? data;

  const AqiTimelineChart({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    final past = (data!["past"] as List<dynamic>? ?? []);
    final future = (data!["future"] as List<dynamic>? ?? []);

    final pastSpots = <FlSpot>[];
    for (int i = 0; i < past.length; i++) {
      final hoursOffset = i - (past.length - 1); // ends at 0 = "Now"
      pastSpots.add(FlSpot(hoursOffset.toDouble(), (past[i]["aqi"] as num).toDouble()));
    }

    final futureSpots = <FlSpot>[];
    // Bridge point at x=0 so the future line visually connects to the past line
    if (past.isNotEmpty) {
      futureSpots.add(FlSpot(0, (past.last["aqi"] as num).toDouble()));
    }
    for (int i = 0; i < future.length; i++) {
      final hoursAhead = (future[i]["hours_ahead"] as num).toDouble();
      futureSpots.add(FlSpot(hoursAhead, (future[i]["predicted_aqi"] as num).toDouble()));
    }

    final allSpots = [...pastSpots, ...futureSpots];
    if (allSpots.isEmpty) return const SizedBox.shrink();

    final minY = allSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 15;
    final maxY = allSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 20;
    final minX = allSpots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
    final maxX = allSpots.map((s) => s.x).reduce((a, b) => a > b ? a : b);

    final stationName = (data!["station_name"] as String? ?? "").replaceAll(", Delhi", "");

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
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "24h AQI Timeline & Forecast",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      "$stationName · ${data!["distance_km"]} km away",
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Interactive Line Chart
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY < 0 ? 0 : minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 40,
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
                      reservedSize: 32,
                      getTitlesWidget: (v, meta) => Text(
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
                      interval: ((maxX - minX) / 4).clamp(1, double.infinity),
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _relativeLabel(v.toInt()),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(verticalLines: [
                  VerticalLine(
                    x: 0,
                    color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                    strokeWidth: 1.5,
                    dashArray: [4, 4],
                  ),
                ]),
                lineBarsData: [
                  // Actual Recorded AQI
                  LineChartBarData(
                    spots: pastSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF0D9488),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0D9488).withValues(alpha: 0.28),
                          const Color(0xFF0D9488).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // ML Predicted Future AQI
                  LineChartBarData(
                    spots: futureSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFE0533D),
                    barWidth: 3,
                    dashArray: [6, 4],
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFE0533D).withValues(alpha: 0.22),
                          const Color(0xFFE0533D).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      "${_relativeLabel(s.x.toInt())}: ${s.y.toStringAsFixed(0)} AQI",
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Legend Row
          Row(
            children: [
              _legendPill("Actual Past (${past.length}h)", const Color(0xFF0D9488)),
              const SizedBox(width: 10),
              _legendPill("ML Predicted (+${future.length}h)", const Color(0xFFE0533D)),
            ],
          ),

          if ((data!["note"] as String? ?? "").isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "${data!["note"]}",
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
