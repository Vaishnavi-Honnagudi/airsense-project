import 'dart:convert';
import 'package:http/http.dart' as http;

// Primary endpoints: checks local emulator bridge first, then remote ngrok tunnel
const List<String> _candidateBases = [
  "http://10.0.2.2:8000",
  "https://material-rhyme-friend.ngrok-free.dev",
];

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static String? _activeBase;

  static Future<Map<String, dynamic>> _getJson(String path) async {
    // If we've already found a working backend base, try it first
    final bases = _activeBase != null
        ? [_activeBase!, ..._candidateBases.where((b) => b != _activeBase)]
        : _candidateBases;

    for (final base in bases) {
      try {
        final uri = Uri.parse("$base$path");
        final isLocal = base.contains("10.0.2.2") || base.contains("localhost");
        final res = await http.get(
          uri,
          headers: {
            "ngrok-skip-browser-warning": "true",
          },
        ).timeout(Duration(seconds: isLocal ? 3 : 15));

        if (res.statusCode == 200) {
          _activeBase = base;
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {
        // Try next candidate base URL
      }
    }
    throw ApiException("Couldn't reach AirSense prediction backend.");
  }

  static Future<Map<String, dynamic>> predictAtLocation(double lat, double lon, {int nStations = 4}) {
    return _getJson("/predict_at_location?lat=$lat&lon=$lon&n_stations=$nStations");
  }

  static Future<Map<String, dynamic>> getCityExtremes() {
    return _getJson("/city_extremes");
  }

  static Future<Map<String, dynamic>> routeOptions(
    double startLat,
    double startLon,
    double endLat,
    double endLon, {
    double sampleIntervalKm = 2.5,
  }) {
    return _getJson(
      "/route_options?start_lat=$startLat&start_lon=$startLon&end_lat=$endLat&end_lon=$endLon&sample_interval_km=$sampleIntervalKm",
    );
  }

  static Future<Map<String, dynamic>> predictAtStation(String stationId) {
    return _getJson("/predict/$stationId");
  }

  static Future<Map<String, dynamic>> getAqiTimeline(double lat, double lon, {int hoursBack = 24, int hoursForward = 24}) {
    return _getJson("/aqi_timeline?lat=$lat&lon=$lon&hours_back=$hoursBack&hours_forward=$hoursForward");
  }

  static Future<Map<String, dynamic>> getWeatherHistory(double lat, double lon, {int hoursBack = 168}) {
    return _getJson("/weather_history?lat=$lat&lon=$lon&hours_back=$hoursBack");
  }
}