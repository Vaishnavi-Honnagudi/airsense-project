import 'package:flutter/material.dart';
import '../models/aqi_utils.dart';

String _pluralLabel(String label) {
  switch (label) {
    case "Child":
      return "Children";
    case "Infant":
      return "Infants";
    case "Elder":
      return "Elders";
    case "Adult":
      return "Adults";
    default:
      return "${label}s";
  }
}

class HealthAdvisory extends StatelessWidget {
  final double aqi;
  final String ageGroup;
  final String healthNote;

  const HealthAdvisory({
    super.key,
    required this.aqi,
    required this.ageGroup,
    required this.healthNote,
  });

  @override
  Widget build(BuildContext context) {
    final advisory = getAdvisory(aqi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Health advisory"),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            advisory.summary,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1C2530), height: 1.4),
          ),
        ),
        ...advisory.actions.map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text("→", style: TextStyle(color: Color(0xFF2E6E5E), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(action, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7178), height: 1.4)),
                  ),
                ],
              ),
            )),
        PersonalizedCallout(aqi: aqi, ageGroup: ageGroup, healthNote: healthNote),
      ],
    );
  }
}

class PersonalizedCallout extends StatelessWidget {
  final double aqi;
  final String ageGroup;
  final String healthNote;

  const PersonalizedCallout({
    super.key,
    required this.aqi,
    required this.ageGroup,
    required this.healthNote,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = healthNote.trim().isNotEmpty;
    final thresholdMet = isConcerningForAgeGroup(aqi, ageGroup);
    if (!thresholdMet && !hasNote) return const SizedBox.shrink();

    final group = getAgeGroup(ageGroup);
    final category = categorize(aqi);
    String text;
    if (thresholdMet) {
      text = "${group.note} Current reading is $category (${aqi.toStringAsFixed(1)} AQI).";
      if (hasNote) {
        text += ' You also noted: "${healthNote.trim()}" — worth keeping in mind.';
      }
    } else {
      // AQI is below the general threshold, but they flagged a personal
      // condition — acknowledge it without overstating the current risk.
      text = 'You noted: "${healthNote.trim()}". Current air quality is $category (${aqi.toStringAsFixed(1)} AQI) — generally low risk, but keep this in mind if you notice any symptoms.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF4E8),
        border: Border.all(color: const Color(0xFFEAD9B8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "FOR ${_pluralLabel(group.label).toUpperCase()}",
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF8A6A2E), letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF5C4A26), height: 1.4)),
        ],
      ),
    );
  }
}

class AqiHeadline extends StatelessWidget {
  final double aqi;
  const AqiHeadline({super.key, required this.aqi});

  @override
  Widget build(BuildContext context) {
    final category = categorize(aqi);
    final color = categoryColor(aqi);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          aqi.toStringAsFixed(1),
          style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1),
        ),
        const SizedBox(width: 12),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
          child: Text(category, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  const StatCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAD6C9)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class PollutantRow extends StatelessWidget {
  final String name;
  final String value;
  const PollutantRow({super.key, required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEAE7DE))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7178))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF6B7178))),
    );
  }
}