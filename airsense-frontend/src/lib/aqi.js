// Official Indian AQI severity bands (CPCB)
export const AQI_BANDS = [
  { max: 50, label: "Good", color: "#4CAF50" },
  { max: 100, label: "Satisfactory", color: "#A8CE39" },
  { max: 200, label: "Moderate", color: "#F4C542" },
  { max: 300, label: "Poor", color: "#F08C3A" },
  { max: 400, label: "Very Poor", color: "#E0533D" },
  { max: Infinity, label: "Severe", color: "#8B2E3C" },
];

export function categorize(aqi) {
  return AQI_BANDS.find((b) => aqi <= b.max)?.label ?? "Severe";
}

export function categoryColor(labelOrAqi) {
  if (typeof labelOrAqi === "number") {
    return AQI_BANDS.find((b) => labelOrAqi <= b.max)?.color ?? "#6B7178";
  }
  return AQI_BANDS.find((b) => b.label === labelOrAqi)?.color ?? "#6B7178";
}

// Age-group health sensitivity. Sensitive groups (infants, children, elderly)
// are advised to take precaution starting at a lower AQI than healthy adults —
// this reflects standard public-health AQI guidance, not something we invented.
export const AGE_GROUPS = [
  { id: "infant", label: "Infant", threshold: 100, note: "Infants are highly sensitive to air pollution — precaution is advised even at Moderate levels." },
  { id: "child", label: "Child", threshold: 100, note: "Children's developing lungs are more sensitive — caution advised from Moderate levels onward." },
  { id: "adult", label: "Adult", threshold: 200, note: "Generally tolerant of Moderate air quality; caution advised from Poor levels onward." },
  { id: "elder", label: "Elder", threshold: 100, note: "Elderly individuals, especially with pre-existing conditions, should take precaution from Moderate levels onward." },
];

export function getAgeGroup(id) {
  return AGE_GROUPS.find((g) => g.id === id) ?? AGE_GROUPS[2]; // default: adult
}

export function isConcerningForAgeGroup(aqi, ageGroupId) {
  const group = getAgeGroup(ageGroupId);
  return aqi >= group.threshold;
}

// Structured advisory: a plain-language summary plus concrete action items,
// following standard public AQI guidance (CPCB/EPA-style communication).
// This is general public-health information, not personalized medical advice.
export const ADVISORY_CONTENT = {
  "Good": {
    summary: "Air quality is considered satisfactory, and air pollution poses little or no risk.",
    actions: [
      "Enjoy outdoor activities as usual.",
      "No precautions needed for any group.",
    ],
  },
  "Satisfactory": {
    summary: "Air quality is acceptable; however, there may be a minor risk for a very small number of unusually sensitive individuals.",
    actions: [
      "Most people can continue outdoor activities normally.",
      "Unusually sensitive individuals may consider reducing prolonged outdoor exertion.",
    ],
  },
  "Moderate": {
    summary: "Members of sensitive groups may experience minor breathing discomfort. The general public is less likely to be affected.",
    actions: [
      "Sensitive groups (children, elderly, those with asthma or heart conditions) should reduce prolonged or heavy outdoor exertion.",
      "Consider keeping windows closed during peak traffic hours (typically morning and evening rush).",
      "Fine for most people to continue normal outdoor activities.",
    ],
  },
  "Poor": {
    summary: "Members of sensitive groups may experience breathing discomfort; the general public may begin to notice mild effects too.",
    actions: [
      "Sensitive groups should avoid prolonged outdoor exertion — move activities indoors where possible.",
      "General public should limit prolonged or heavy outdoor exertion.",
      "Consider wearing a pollution mask (N95) if you need to be outside for extended periods.",
      "Keep windows closed; use an air purifier indoors if available.",
    ],
  },
  "Very Poor": {
    summary: "Health warnings of emergency conditions. The entire population is more likely to be affected.",
    actions: [
      "Avoid outdoor physical activity — reschedule outdoor plans if possible.",
      "Sensitive groups should remain indoors and keep activity levels low.",
      "Wear a well-fitted pollution mask (N95) if you must go outside.",
      "Keep windows and doors closed; run an air purifier if you have one.",
      "Watch for symptoms like coughing or shortness of breath, especially in children and the elderly.",
    ],
  },
  "Severe": {
    summary: "Health alert: everyone may experience more serious health effects. This is an emergency condition.",
    actions: [
      "Stay indoors and avoid all outdoor exertion.",
      "Sensitive groups should consult a doctor if experiencing breathing difficulty, chest discomfort, or persistent coughing.",
      "Keep windows and doors sealed; run an air purifier continuously if available.",
      "If you must go outside, wear a well-fitted N95 mask and minimize time spent outdoors.",
      "Postpone outdoor events, sports, or exercise until conditions improve.",
    ],
  },
};

export function getAdvisory(aqi) {
  const category = categorize(aqi);
  return ADVISORY_CONTENT[category] ?? ADVISORY_CONTENT["Moderate"];
}