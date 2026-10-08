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

  /// Generates a realistic 10-point forecast timeline starting from the current real-time hour.
  static List<HourlyWeatherForecast> generateDynamicHourly({
    required double baseAqi,
    required double baseTemp,
  }) {
    final now = DateTime.now();
    // 10 key timeline points covering the next 24 hours
    final offsets = [0, 1, 2, 3, 4, 6, 9, 13, 18, 22];

    return offsets.map((h) {
      final target = now.add(Duration(hours: h));
      final hr = target.hour;
      final period = hr < 12 ? "AM" : "PM";
      final displayHr = hr == 0 ? 12 : (hr > 12 ? hr - 12 : hr);
      final label = h == 0 ? "Now" : "$displayHr $period";

      // Temperature diurnal variation: coolest around 5-6 AM, peak around 2-3 PM (hour 15)
      final tCos = math.cos((hr - 15) * 2 * math.pi / 24);
      final temp = (baseTemp + tCos * 4.0).round();

      // Delhi AQI diurnal multiplier:
      // Peak morning inversion (5 AM - 8 AM), afternoon solar dispersion (1 PM - 4 PM)
      double aqiMult;
      String cond;
      IconData icon;

      if (hr >= 5 && hr <= 8) {
        aqiMult = 1.30;
        cond = "Inversion peak";
        icon = (baseAqi * aqiMult) > 200 ? Icons.dangerous_rounded : Icons.warning_rounded;
      } else if (hr >= 9 && hr <= 12) {
        aqiMult = 1.05;
        cond = "Morning haze";
        icon = Icons.wb_sunny_outlined;
      } else if (hr >= 13 && hr <= 16) {
        aqiMult = 0.88;
        cond = "Midday breeze";
        icon = Icons.wb_sunny;
      } else if (hr >= 17 && hr <= 19) {
        aqiMult = 1.00;
        cond = "Evening rush";
        icon = Icons.air;
      } else if (hr >= 20 && hr <= 23) {
        aqiMult = 1.15;
        cond = "Night smog";
        icon = Icons.nightlight_round;
      } else {
        aqiMult = 1.22;
        cond = "Cold inversion";
        icon = Icons.nightlight_round;
      }

      final aqi = h == 0 ? baseAqi.round() : (baseAqi * aqiMult).round();
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
      aqi: 135.0,
      humidity: 58,
      windSpeedKmh: 12.4,
      windDirection: "NW",
      uvIndex: 5.5,
      visibilityKm: 4.0,
      pressureMb: 1009,
      cloudCoverPct: 42,
      rainfallMm: 0.0,
      airComfort: "Moderate Discomfort",
      hourly: generateDynamicHourly(baseAqi: 135.0, baseTemp: 27.5),
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
      temperature: 29.0,
      feelsLike: 32.0,
      condition: "Heavy Smog & Traffic Haze",
      conditionIcon: "smog",
      minTemp: 22.0,
      maxTemp: 34.0,
      aqi: 245.0,
      humidity: 62,
      windSpeedKmh: 8.5,
      windDirection: "WNW",
      uvIndex: 4.8,
      visibilityKm: 2.5,
      pressureMb: 1008,
      cloudCoverPct: 55,
      rainfallMm: 0.0,
      airComfort: "Poor / Unhealthy",
      hourly: generateDynamicHourly(baseAqi: 245.0, baseTemp: 29.0),
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
      temperature: 26.5,
      feelsLike: 28.0,
      condition: "Mild Haze · Green Belt",
      conditionIcon: "haze",
      minTemp: 20.0,
      maxTemp: 31.0,
      aqi: 118.0,
      humidity: 55,
      windSpeedKmh: 14.0,
      windDirection: "NW",
      uvIndex: 5.2,
      visibilityKm: 5.0,
      pressureMb: 1010,
      cloudCoverPct: 35,
      rainfallMm: 0.0,
      airComfort: "Moderate",
      hourly: generateDynamicHourly(baseAqi: 118.0, baseTemp: 26.5),
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
      temperature: 28.0,
      feelsLike: 30.5,
      condition: "Industrial Haze",
      conditionIcon: "haze",
      minTemp: 21.0,
      maxTemp: 33.0,
      aqi: 185.0,
      humidity: 59,
      windSpeedKmh: 11.0,
      windDirection: "WNW",
      uvIndex: 5.0,
      visibilityKm: 3.5,
      pressureMb: 1009,
      cloudCoverPct: 45,
      rainfallMm: 0.0,
      airComfort: "Moderate Discomfort",
      hourly: generateDynamicHourly(baseAqi: 185.0, baseTemp: 28.0),
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
