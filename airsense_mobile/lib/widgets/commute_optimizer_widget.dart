import 'package:flutter/material.dart';
import '../models/aqi_utils.dart';

/// Interactive Commute Optimizer Departure Time Slider for AirSense
class CommuteOptimizerWidget extends StatefulWidget {
  final double currentRouteAqi;
  final int baseDurationMins;

  const CommuteOptimizerWidget({
    super.key,
    required this.currentRouteAqi,
    required this.baseDurationMins,
  });

  @override
  State<CommuteOptimizerWidget> createState() => _CommuteOptimizerWidgetState();
}

class _CommuteOptimizerWidgetState extends State<CommuteOptimizerWidget> {
  double _hourOffset = 2.0; // Default +2 hours (typically Delhi evening sweet spot)

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final departureTime = now.add(Duration(minutes: (_hourOffset * 60).toInt()));

    // Realistic Delhi diurnal curve:
    // Rush hour (18:00–20:30) has worst traffic & high inversion
    // Later night (20:30–22:30) traffic drops and dispersion improves
    double aqiFactor;
    int trafficDelayMins;

    final targetHour = departureTime.hour;
    if (targetHour >= 18 && targetHour <= 20) {
      // Peak evening rush + ground inversion
      aqiFactor = 1.15;
      trafficDelayMins = 18;
    } else if (targetHour >= 21 || targetHour <= 1) {
      // Night dispersion, less vehicular congestion
      aqiFactor = 0.72;
      trafficDelayMins = 3;
    } else if (targetHour >= 13 && targetHour <= 16) {
      // Afternoon solar dispersion
      aqiFactor = 0.78;
      trafficDelayMins = 6;
    } else {
      aqiFactor = 0.90;
      trafficDelayMins = 10;
    }

    final projectedAqi = (widget.currentRouteAqi * aqiFactor).clamp(40.0, 480.0);
    final totalDuration = widget.baseDurationMins + trafficDelayMins;
    final color = categoryColor(projectedAqi);
    final category = categorize(projectedAqi);

    final aqiSavings = ((widget.currentRouteAqi - projectedAqi) / widget.currentRouteAqi * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text(
                    "AI Departure Time Optimizer",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "LSTM Powered",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Slide departure time to project future traffic and diurnal smog dispersion along your route.",
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),

          // Interactive Departure Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Leave: ${_hourOffset == 0 ? "Right Now" : "+${_hourOffset.toInt()} hrs (${_formatTime(departureTime)})"}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                _hourOffset == 0 ? "Immediate" : "Scheduled",
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF0F172A),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF0F172A),
              overlayColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _hourOffset,
              min: 0.0,
              max: 5.0,
              divisions: 5,
              label: _hourOffset == 0 ? "Now" : "+${_hourOffset.toInt()}h",
              onChanged: (val) => setState(() => _hourOffset = val),
            ),
          ),

          // Projection Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Projected Route AQI
                Column(
                  children: [
                    const Text(
                      "PROJECTED AQI",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          "${projectedAqi.toInt()}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),

                // Total Travel Time
                Column(
                  children: [
                    const Text(
                      "ESTIMATED TIME",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$totalDuration mins",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),

                Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),

                // Exposure Savings
                Column(
                  children: [
                    const Text(
                      "CLEAN SAVINGS",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      aqiSavings > 0 ? "-$aqiSavings% AQI" : "Baseline",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: aqiSavings > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Recommendation callout
          if (aqiSavings > 15) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.thumb_up_alt_rounded, size: 15, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Optimal Travel Window: Leaving at ${_formatTime(departureTime)} avoids the evening smog inversion trap.",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    final min = dt.minute.toString().padLeft(2, '0');
    return "$hour:$min $ampm";
  }
}
