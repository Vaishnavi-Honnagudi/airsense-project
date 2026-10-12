import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Weather & atmospheric condition model for Delhi zones (AQI.in UI design)
class CityWeatherAqi {
  final String cityName;
  final String stateCountry;
  final double temperature;
  final double feelsLike;
  final String condition;
  final String conditionIcon;
  final double minTemp;
  final double maxTemp;
  final double aqi;
  final int humidity;
  final double windSpeedKmh;
  final String windDirection;
  final double uvIndex;
  final double visibilityKm;
  final int pressureMb;
  final int cloudCoverPct;
  final double rainfallMm;
  final String airComfort;
  final List<HourlyWeatherForecast> hourly;
  final Map<String, PollutantMetric> pollutants;

  const CityWeatherAqi({
    required this.cityName,
    required this.stateCountry,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.conditionIcon,
    required this.minTemp,
    required this.maxTemp,
    required this.aqi,
    required this.humidity,
    required this.windSpeedKmh,
    required this.windDirection,
    required this.uvIndex,
    required this.visibilityKm,
    required this.pressureMb,
    required this.cloudCoverPct,
    required this.rainfallMm,
    required this.airComfort,
    required this.hourly,
    required this.pollutants,
  });

  /// Returns a copy updated with live backend AQI and weather telemetry so the 24h curve and sensors stay in sync.
  CityWeatherAqi copyWithLiveTelemetry({
    required double liveAqi,
    double? liveTemp,
    int? liveHumidity,
    double? liveWindSpeed,
    int? livePressure,
    int zoneIndex = 0,
  }) {
    final t = liveTemp ?? temperature;
    final ratio = (liveAqi / (aqi > 0 ? aqi : 135.0)).clamp(0.35, 2.5);
    final updatedPollutants = <String, PollutantMetric>{};
    pollutants.forEach((k, v) {
      final scaledVal = double.parse((v.value * ratio).toStringAsFixed(1));
      final st = scaledVal <= v.maxStandard * 0.6
          ? "Good"
          : (scaledVal <= v.maxStandard
              ? "Satisfactory"
              : (scaledVal <= v.maxStandard * 1.8 ? "Moderate" : "Poor"));
      updatedPollutants[k] = PollutantMetric(
        name: v.name,
        value: scaledVal,
        unit: v.unit,
        maxStandard: v.maxStandard,
        status: st,
      );
    });

    return CityWeatherAqi(
      cityName: cityName,
      stateCountry: stateCountry,
      temperature: t,
      feelsLike: t + (liveAqi > 180 ? 2.5 : 1.5),
      condition: condition,
      conditionIcon: conditionIcon,
      minTemp: (t - 5.5).roundToDouble(),
      maxTemp: (t + 4.5).roundToDouble(),
      aqi: liveAqi,
      humidity: liveHumidity ?? humidity,
      windSpeedKmh: liveWindSpeed ?? windSpeedKmh,
      windDirection: windDirection,
      uvIndex: uvIndex,
      visibilityKm: visibilityKm,
      pressureMb: livePressure ?? pressureMb,
      cloudCoverPct: cloudCoverPct,
      rainfallMm: rainfallMm,
      airComfort: liveAqi <= 50
          ? "Optimal Comfort"
          : (liveAqi <= 100
              ? "Satisfactory Air"
              : (liveAqi <= 200 ? "Moderate Discomfort" : "Poor / Unhealthy")),
      hourly: generateDynamicHourly(baseAqi: liveAqi, baseTemp: t, zoneIndex: zoneIndex),
      pollutants: updatedPollutants,
    );
  }

  /// Generates a realistic 10-point forecast timeline starting from the current real-time hour,
  /// differentiated by Delhi zone profile and continuous diurnal harmonics.
  static List<HourlyWeatherForecast> generateDynamicHourly({
    required double baseAqi,
    required double baseTemp,
    int zoneIndex = 0,
  }) {
    final now = DateTime.now();
    // 10 key timeline points covering the next 24 hours
    final offsets = [0, 1, 2, 3, 4, 6, 9, 13, 18, 22];
    final zonePhase = zoneIndex * 0.65;
    final zoneAmpScale = 1.0 + (zoneIndex % 3) * 0.08;

    double diurnalMultiplierForHour(int hr, int stepOffset) {
      final h = (hr + zonePhase) % 24.0;
      final morningPeak = 0.24 * zoneAmpScale * math.exp(-math.pow(h - 7.5, 2) / 6.0);
      final afternoonDip = -0.18 * zoneAmpScale * math.exp(-math.pow(h - 15.0, 2) / 7.5);
      final nightPeak = 0.16 * zoneAmpScale * math.exp(-math.pow(h - 22.0, 2) / 8.5);
      final microWave = 0.045 * math.sin(stepOffset * 0.9 + zoneIndex * 1.3);
      return 1.0 + morningPeak + afternoonDip + nightPeak + microWave;
    }

    final nowMult = diurnalMultiplierForHour(now.hour, 0);

    return offsets.map((h) {
      final target = now.add(Duration(hours: h));
      final hr = target.hour;
      final period = hr < 12 ? "AM" : "PM";
      final displayHr = hr == 0 ? 12 : (hr > 12 ? hr - 12 : hr);
      final label = h == 0 ? "Now" : "$displayHr $period";

      // Continuous diurnal temperature curve anchored at baseTemp at h=0
      final nowTempWave = math.cos((now.hour - 15 + zoneIndex * 0.4) * 2 * math.pi / 24);
      final targetTempWave = math.cos((hr - 15 + zoneIndex * 0.4) * 2 * math.pi / 24);
      final tempDelta = (targetTempWave - nowTempWave) * (3.8 + zoneIndex * 0.35) + math.sin(h * 0.7 + zoneIndex) * 0.6;
      final temp = h == 0 ? baseTemp.round() : (baseTemp + tempDelta).round();

      final targetMult = diurnalMultiplierForHour(hr, h);
      final relMult = targetMult / (nowMult > 0.5 ? nowMult : 1.0);
      final aqi = h == 0 ? baseAqi.round() : (baseAqi * relMult).round().clamp(15, 495);

      String cond;
      IconData icon;
      if (hr >= 5 && hr <= 8) {
        cond = "Inversion peak";
        icon = aqi > 200 ? Icons.dangerous_rounded : Icons.warning_rounded;
      } else if (hr >= 9 && hr <= 12) {
        cond = "Morning haze";
        icon = Icons.wb_sunny_outlined;
      } else if (hr >= 13 && hr <= 16) {
        cond = "Midday breeze";
        icon = Icons.wb_sunny;
      } else if (hr >= 17 && hr <= 19) {
        cond = "Evening rush";
        icon = Icons.air;
      } else if (hr >= 20 && hr <= 23) {
        cond = "Night smog";
        icon = Icons.nightlight_round;
      } else {
        cond = "Cold inversion";
        icon = Icons.nightlight_round;
      }

      return HourlyWeatherForecast(
        time: label,
        temp: temp,
        aqi: aqi,
        condition: cond,
        icon: icon,
      );
    }).toList();
  }

  /// Central Delhi (Connaught Place / Mandir Marg)
  static CityWeatherAqi centralDelhi() {
    return CityWeatherAqi(
      cityName: "Central Delhi (Connaught Place)",
      stateCountry: "Delhi NCR, India",
      temperature: 27.5,
      feelsLike: 29.0,
      condition: "Haze & Dust",
      conditionIcon: "haze",
      minTemp: 21.0,
      maxTemp: 32.0,
      aqi: 112.0,
      humidity: 54,
      windSpeedKmh: 12.4,
      windDirection: "NW",
      uvIndex: 5.5,
      visibilityKm: 4.2,
      pressureMb: 1011,
      cloudCoverPct: 38,
      rainfallMm: 0.0,
      airComfort: "Moderate Discomfort",
      hourly: generateDynamicHourly(baseAqi: 112.0, baseTemp: 27.5, zoneIndex: 0),
      pollutants: {
        "PM2.5": const PollutantMetric(name: "PM2.5", value: 58.4, unit: "µg/m³", maxStandard: 60, status: "Moderate"),
        "PM10": const PollutantMetric(name: "PM10", value: 128.0, unit: "µg/m³", maxStandard: 100, status: "Moderate"),
        "NO2": const PollutantMetric(name: "NO₂", value: 42.6, unit: "µg/m³", maxStandard: 80, status: "Good"),
        "SO2": const PollutantMetric(name: "SO₂", value: 12.8, unit: "µg/m³", maxStandard: 80, status: "Good"),
        "CO": const PollutantMetric(name: "CO", value: 1.2, unit: "mg/m³", maxStandard: 2.0, status: "Good"),
        "O3": const PollutantMetric(name: "Ozone", value: 48.0, unit: "µg/m³", maxStandard: 100, status: "Good"),
      },
    );
  }

  /// East Delhi (Anand Vihar - DPCC hotspot)
  static CityWeatherAqi anandVihar() {
    return CityWeatherAqi(
      cityName: "East Delhi (Anand Vihar)",
      stateCountry: "Delhi NCR, India",
      temperature: 29.5,
      feelsLike: 32.0,
      condition: "Heavy Smog & Traffic Haze",
      conditionIcon: "smog",
      minTemp: 23.0,
      maxTemp: 34.5,
      aqi: 258.0,
      humidity: 61,
      windSpeedKmh: 8.2,
      windDirection: "WNW",
      uvIndex: 4.8,
      visibilityKm: 2.4,
      pressureMb: 1008,
      cloudCoverPct: 56,
      rainfallMm: 0.0,
      airComfort: "Poor / Unhealthy",
      hourly: generateDynamicHourly(baseAqi: 258.0, baseTemp: 29.5, zoneIndex: 1),
      pollutants: {
        "PM2.5": const PollutantMetric(name: "PM2.5", value: 148.0, unit: "µg/m³", maxStandard: 60, status: "Poor"),
        "PM10": const PollutantMetric(name: "PM10", value: 265.0, unit: "µg/m³", maxStandard: 100, status: "Very Poor"),
        "NO2": const PollutantMetric(name: "NO₂", value: 88.5, unit: "µg/m³", maxStandard: 80, status: "Moderate"),
        "SO2": const PollutantMetric(name: "SO₂", value: 24.2, unit: "µg/m³", maxStandard: 80, status: "Good"),
        "CO": const PollutantMetric(name: "CO", value: 2.8, unit: "mg/m³", maxStandard: 2.0, status: "Poor"),
        "O3": const PollutantMetric(name: "Ozone", value: 72.0, unit: "µg/m³", maxStandard: 100, status: "Moderate"),
      },
    );
  }

  /// South Delhi (R.K. Puram / Hauz Khas)
  static CityWeatherAqi southDelhi() {
    return CityWeatherAqi(
      cityName: "South Delhi (R.K. Puram)",
      stateCountry: "Delhi NCR, India",
      temperature: 26.2,
      feelsLike: 27.5,
      condition: "Mild Haze · Green Belt",
      conditionIcon: "haze",
      minTemp: 20.0,
      maxTemp: 30.5,
      aqi: 104.0,
      humidity: 51,
      windSpeedKmh: 14.2,
      windDirection: "NW",
      uvIndex: 5.2,
      visibilityKm: 5.2,
      pressureMb: 1012,
      cloudCoverPct: 32,
      rainfallMm: 0.0,
      airComfort: "Moderate",
      hourly: generateDynamicHourly(baseAqi: 104.0, baseTemp: 26.2, zoneIndex: 2),
      pollutants: {
        "PM2.5": const PollutantMetric(name: "PM2.5", value: 44.0, unit: "µg/m³", maxStandard: 60, status: "Good"),
        "PM10": const PollutantMetric(name: "PM10", value: 96.0, unit: "µg/m³", maxStandard: 100, status: "Good"),
        "NO2": const PollutantMetric(name: "NO₂", value: 34.0, unit: "µg/m³", maxStandard: 80, status: "Good"),
        "SO2": const PollutantMetric(name: "SO₂", value: 11.0, unit: "µg/m³", maxStandard: 80, status: "Good"),
        "CO": const PollutantMetric(name: "CO", value: 0.9, unit: "mg/m³", maxStandard: 2.0, status: "Good"),
        "O3": const PollutantMetric(name: "Ozone", value: 42.0, unit: "µg/m³", maxStandard: 100, status: "Good"),
      },
    );
  }

  /// North Delhi (Wazirpur - DPCC)
  static CityWeatherAqi northDelhi() {
    return CityWeatherAqi(
      cityName: "North Delhi (Wazirpur)",
      stateCountry: "Delhi NCR, India",
      temperature: 28.4,
      feelsLike: 30.8,
      condition: "Industrial Haze",
      conditionIcon: "haze",
      minTemp: 21.5,
      maxTemp: 33.2,
      aqi: 215.0,
      humidity: 58,
      windSpeedKmh: 9.8,
      windDirection: "WNW",
      uvIndex: 5.0,
      visibilityKm: 3.1,
      pressureMb: 1009,
      cloudCoverPct: 48,
      rainfallMm: 0.0,
      airComfort: "Moderate Discomfort",
      hourly: generateDynamicHourly(baseAqi: 215.0, baseTemp: 28.4, zoneIndex: 3),
      pollutants: {
        "PM2.5": const PollutantMetric(name: "PM2.5", value: 85.0, unit: "µg/m³", maxStandard: 60, status: "Moderate"),
        "PM10": const PollutantMetric(name: "PM10", value: 175.0, unit: "µg/m³", maxStandard: 100, status: "Poor"),
        "NO2": const PollutantMetric(name: "NO₂", value: 55.0, unit: "µg/m³", maxStandard: 80, status: "Moderate"),
        "SO2": const PollutantMetric(name: "SO₂", value: 16.0, unit: "µg/m³", maxStandard: 80, status: "Good"),
        "CO": const PollutantMetric(name: "CO", value: 1.8, unit: "mg/m³", maxStandard: 2.0, status: "Moderate"),
        "O3": const PollutantMetric(name: "Ozone", value: 62.0, unit: "µg/m³", maxStandard: 100, status: "Moderate"),
      },
    );
  }
}

class HourlyWeatherForecast {
  final String time;
  final int temp;
  final int aqi;
  final String condition;
  final IconData icon;

  const HourlyWeatherForecast({
    required this.time,
    required this.temp,
    required this.aqi,
    required this.condition,
    required this.icon,
  });
}

class PollutantMetric {
  final String name;
  final double value;
  final String unit;
  final double maxStandard;
  final String status;

  const PollutantMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.maxStandard,
    required this.status,
  });

  double get ratio => (value / maxStandard).clamp(0.0, 1.0);
}
