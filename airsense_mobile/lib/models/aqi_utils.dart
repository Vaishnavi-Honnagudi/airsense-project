import 'package:flutter/material.dart';

class AqiBand {
  final int max;
  final String label;
  final Color color;
  const AqiBand(this.max, this.label, this.color);
}

const List<AqiBand> aqiBands = [
  AqiBand(50, "Good", Color(0xFF4CAF50)),
  AqiBand(100, "Satisfactory", Color(0xFFA8CE39)),
  AqiBand(200, "Moderate", Color(0xFFF4C542)),
  AqiBand(300, "Poor", Color(0xFFF08C3A)),
  AqiBand(400, "Very Poor", Color(0xFFE0533D)),
  AqiBand(999999, "Severe", Color(0xFF8B2E3C)),
];

String categorize(double aqi) {
  for (final band in aqiBands) {
    if (aqi <= band.max) return band.label;
  }
  return "Severe";
}

Color categoryColor(double aqi) {
  for (final band in aqiBands) {
    if (aqi <= band.max) return band.color;
  }
  return const Color(0xFF6B7178);
}

Color categoryColorForLabel(String label) {
  final band = aqiBands.firstWhere(
    (b) => b.label == label,
    orElse: () => aqiBands.last,
  );
  return band.color;
}

class AgeGroup {
  final String id;
  final String label;
  final double threshold;
  final String note;
  const AgeGroup(this.id, this.label, this.threshold, this.note);
}

// Sensitive groups (infants, children, elderly) are advised to take
// precaution starting at a lower AQI than healthy adults — this reflects
// standard public-health AQI guidance.
const List<AgeGroup> ageGroups = [
  AgeGroup("infant", "Infant", 100,
      "Infants are highly sensitive to air pollution — precaution is advised even at Moderate levels."),
  AgeGroup("child", "Child", 100,
      "Children's developing lungs are more sensitive — caution advised from Moderate levels onward."),
  AgeGroup("adult", "Adult", 200,
      "Generally tolerant of Moderate air quality; caution advised from Poor levels onward."),
  AgeGroup("elder", "Elder", 100,
      "Elderly individuals, especially with pre-existing conditions, should take precaution from Moderate levels onward."),
];

AgeGroup getAgeGroup(String id) {
  return ageGroups.firstWhere((g) => g.id == id, orElse: () => ageGroups[2]);
}

bool isConcerningForAgeGroup(double aqi, String ageGroupId) {
  final group = getAgeGroup(ageGroupId);
  return aqi >= group.threshold;
}

class Advisory {
  final String summary;
  final List<String> actions;
  const Advisory(this.summary, this.actions);
}

// Structured advisory: a plain-language summary plus concrete action items,
// following standard public AQI guidance (CPCB/EPA-style communication).
// This is general public-health information, not personalized medical advice.
// Mirrors the same content used in the web app's lib/aqi.js exactly.
const Map<String, Advisory> advisoryContent = {
  "Good": Advisory(
    "Air quality is considered satisfactory, and air pollution poses little or no risk.",
    [
      "Enjoy outdoor activities as usual.",
      "No precautions needed for any group.",
    ],
  ),
  "Satisfactory": Advisory(
    "Air quality is acceptable; however, there may be a minor risk for a very small number of unusually sensitive individuals.",
    [
      "Most people can continue outdoor activities normally.",
      "Unusually sensitive individuals may consider reducing prolonged outdoor exertion.",
    ],
  ),
  "Moderate": Advisory(
    "Members of sensitive groups may experience minor breathing discomfort. The general public is less likely to be affected.",
    [
      "Sensitive groups (children, elderly, those with asthma or heart conditions) should reduce prolonged or heavy outdoor exertion.",
      "Consider keeping windows closed during peak traffic hours (typically morning and evening rush).",
      "Fine for most people to continue normal outdoor activities.",
    ],
  ),
  "Poor": Advisory(
    "Members of sensitive groups may experience breathing discomfort; the general public may begin to notice mild effects too.",
    [
      "Sensitive groups should avoid prolonged outdoor exertion — move activities indoors where possible.",
      "General public should limit prolonged or heavy outdoor exertion.",
      "Consider wearing a pollution mask (N95) if you need to be outside for extended periods.",
      "Keep windows closed; use an air purifier indoors if available.",
    ],
  ),
  "Very Poor": Advisory(
    "Health warnings of emergency conditions. The entire population is more likely to be affected.",
    [
      "Avoid outdoor physical activity — reschedule outdoor plans if possible.",
      "Sensitive groups should remain indoors and keep activity levels low.",
      "Wear a well-fitted pollution mask (N95) if you must go outside.",
      "Keep windows and doors closed; run an air purifier if you have one.",
      "Watch for symptoms like coughing or shortness of breath, especially in children and the elderly.",
    ],
  ),
  "Severe": Advisory(
    "Health alert: everyone may experience more serious health effects. This is an emergency condition.",
    [
      "Stay indoors and avoid all outdoor exertion.",
      "Sensitive groups should consult a doctor if experiencing breathing difficulty, chest discomfort, or persistent coughing.",
      "Keep windows and doors sealed; run an air purifier continuously if available.",
      "If you must go outside, wear a well-fitted N95 mask and minimize time spent outdoors.",
      "Postpone outdoor events, sports, or exercise until conditions improve.",
    ],
  ),
};

Advisory getAdvisory(double aqi) {
  final category = categorize(aqi);
  return advisoryContent[category] ?? advisoryContent["Moderate"]!;
}