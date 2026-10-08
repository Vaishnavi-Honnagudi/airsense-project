import 'dart:async';
import 'package:flutter/material.dart';
import '../models/aqi_utils.dart';

/// Turn-by-Turn Clean Commute Navigation HUD for AirSense Map
class CleanNavigationHud extends StatefulWidget {
  final String startLabel;
  final String destinationLabel;
  final double routeAqi;
  final double distanceKm;
  final int durationMins;
  final VoidCallback onExit;

  const CleanNavigationHud({
    super.key,
    required this.startLabel,
    required this.destinationLabel,
    required this.routeAqi,
    required this.distanceKm,
    required this.durationMins,
    required this.onExit,
  });

  @override
  State<CleanNavigationHud> createState() => _CleanNavigationHudState();
}

class _CleanNavigationHudState extends State<CleanNavigationHud> {
  int _currentStepIndex = 0;
  Timer? _stepTimer;
  double _inhaledPm25Ug = 0.8;
  int _speedKmh = 38;

  late final List<_NavStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = [
      _NavStep(
        instruction: "Head south on Janpath toward Tolstoy Marg",
        distanceM: "350 m",
        subtext: "Entering low-emission green corridor",
        icon: Icons.straight_rounded,
        stepAqi: widget.routeAqi - 10,
      ),
      _NavStep(
        instruction: "Turn left onto Kasturba Gandhi Marg",
        distanceM: "800 m",
        subtext: "Traffic moving smoothly at 42 km/h",
        icon: Icons.turn_left_rounded,
        stepAqi: widget.routeAqi - 5,
      ),
      _NavStep(
        instruction: "At the roundabout, take the 2nd exit toward C-Hexagon",
        distanceM: "1.4 km",
        subtext: "Tree canopy reducing PM2.5 by 25%",
        icon: Icons.roundabout_left_rounded,
        stepAqi: widget.routeAqi - 15,
      ),
      _NavStep(
        instruction: "Continue onto Rajpath / Kartavya Path",
        distanceM: "600 m",
        subtext: "Approaching India Gate lawn canopy",
        icon: Icons.straight_rounded,
        stepAqi: widget.routeAqi - 20,
      ),
      _NavStep(
        instruction: "Destination will be on your left: India Gate",
        distanceM: "100 m",
        subtext: "Clean commute completed safely",
        icon: Icons.place_rounded,
        stepAqi: widget.routeAqi - 25,
      ),
    ];

    // Simulate car moving along route every 5 seconds
    _stepTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted) return;
      setState(() {
        if (_currentStepIndex < _steps.length - 1) {
          _currentStepIndex++;
          _inhaledPm25Ug += 0.4;
          _speedKmh = 35 + (_currentStepIndex * 3) % 15;
        }
      });
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curStep = _steps[_currentStepIndex];
    final color = categoryColor(curStep.stepAqi);
    final category = categorize(curStep.stepAqi);

    return Stack(
      children: [
        // Top Turn-by-Turn Instruction Banner
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Maneuver Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                    ),
                    child: Icon(curStep.icon, color: const Color(0xFF38BDF8), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              curStep.distanceM,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${curStep.stepAqi.toInt()} AQI · $category",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          curStep.instruction,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          curStep.subtext,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Navigation Dashboard Bar
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "${widget.durationMins}",
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "min",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "(${widget.distanceKm} km)",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "ETA: ${DateTime.now().add(Duration(minutes: widget.durationMins)).hour}:${DateTime.now().add(Duration(minutes: widget.durationMins)).minute.toString().padLeft(2, '0')} · $_speedKmh km/h",
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),

                      // Particulate Inhalation Gauge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_rounded, size: 13, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(
                                  "${_inhaledPm25Ug.toStringAsFixed(1)} µg",
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              "34% cleaner path",
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Actions Row: Stop / Re-route
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_currentStepIndex < _steps.length - 1) {
                                _currentStepIndex++;
                              }
                            });
                          },
                          icon: const Icon(Icons.skip_next_rounded, size: 18),
                          label: const Text("Next Step", style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text("Exit Nav", style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavStep {
  final String instruction;
  final String distanceM;
  final String subtext;
  final IconData icon;
  final double stepAqi;

  _NavStep({
    required this.instruction,
    required this.distanceM,
    required this.subtext,
    required this.icon,
    required this.stepAqi,
  });
}
