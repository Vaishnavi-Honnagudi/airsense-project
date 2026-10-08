import 'package:flutter/material.dart';

Color _trafficColor(String? level) {
  if (level == "Light") return const Color(0xFF4CAF50);
  if (level == "Moderate") return const Color(0xFFF4C542);
  return const Color(0xFFE0533D); // Heavy / Unknown
}

class TrafficGauge extends StatelessWidget {
  final String? level;
  final int? congestionPct;
  final double? avgSpeed;

  const TrafficGauge({super.key, this.level, this.congestionPct, this.avgSpeed});

  @override
  Widget build(BuildContext context) {
    final pct = (congestionPct ?? 0).clamp(0, 100);
    final color = _trafficColor(level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${level ?? "Unknown"} traffic", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13.5)),
              Text("$pct% congestion", style: const TextStyle(fontSize: 12, color: Color(0xFF6B7178))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFEAE7DE),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (avgSpeed != null) ...[
            const SizedBox(height: 6),
            Text("Average speed: $avgSpeed km/h", style: const TextStyle(fontSize: 12, color: Color(0xFF6B7178))),
          ],
        ],
      ),
    );
  }
}
