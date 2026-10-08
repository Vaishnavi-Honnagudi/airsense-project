import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modal sheet for managing Delhi AQI Notifications and Inversion Alerts
class DelhiNotificationsSheet extends StatefulWidget {
  const DelhiNotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DelhiNotificationsSheet(),
    );
  }

  @override
  State<DelhiNotificationsSheet> createState() => _DelhiNotificationsSheetState();
}

class _DelhiNotificationsSheetState extends State<DelhiNotificationsSheet> {
  bool _morningBriefing = true;
  bool _eveningInversion = true;
  bool _grapRestrictions = true;
  bool _severeThreshold = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _morningBriefing = prefs.getBool("notif_morning") ?? true;
        _eveningInversion = prefs.getBool("notif_inversion") ?? true;
        _grapRestrictions = prefs.getBool("notif_grap") ?? true;
        _severeThreshold = prefs.getBool("notif_severe") ?? false;
      });
    } catch (_) {}
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void _triggerTestNotification() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🚨 Delhi Inversion Spike Alert",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "PM2.5 rising rapidly in Central Delhi (AQI 215). Close windows & shift to indoor workout.",
                    style: TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AirSense Smart Alerts",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        "Delhi NCR Meteorological & Inversion Push",
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 12),

          // Notification Toggles
          _buildToggleTile(
            title: "Morning Air Briefing (7:30 AM)",
            subtitle: "Daily overview of Delhi AQI and optimal outdoor workout window.",
            icon: Icons.wb_sunny_rounded,
            iconColor: const Color(0xFFF59E0B),
            value: _morningBriefing,
            onChanged: (val) {
              setState(() => _morningBriefing = val);
              _savePreference("notif_morning", val);
            },
          ),
          const SizedBox(height: 8),

          _buildToggleTile(
            title: "Evening Inversion Spikes (7:00 PM)",
            subtitle: "Advance alert when night surface cooling traps vehicular exhaust.",
            icon: Icons.cloud_sync_rounded,
            iconColor: const Color(0xFF8B5CF6),
            value: _eveningInversion,
            onChanged: (val) {
              setState(() => _eveningInversion = val);
              _savePreference("notif_inversion", val);
            },
          ),
          const SizedBox(height: 8),

          _buildToggleTile(
            title: "Delhi GRAP Vehicle Curbs",
            subtitle: "Immediate warning if BS-III petrol or BS-IV diesel cars are restricted.",
            icon: Icons.traffic_rounded,
            iconColor: const Color(0xFFEF4444),
            value: _grapRestrictions,
            onChanged: (val) {
              setState(() => _grapRestrictions = val);
              _savePreference("notif_grap", val);
            },
          ),
          const SizedBox(height: 8),

          _buildToggleTile(
            title: "Severe Smog Threshold (> 300 AQI)",
            subtitle: "High-priority push alert recommending immediate N95 mask use.",
            icon: Icons.masks_rounded,
            iconColor: const Color(0xFF10B981),
            value: _severeThreshold,
            onChanged: (val) {
              setState(() => _severeThreshold = val);
              _savePreference("notif_severe", val);
            },
          ),

          const SizedBox(height: 20),

          // Send Test Alert Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _triggerTestNotification,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text(
                "Trigger Live Test Notification",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFF0F172A), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF0F172A),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
