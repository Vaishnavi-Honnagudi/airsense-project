import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceResult {
  final String name;
  final double lat;
  final double lon;
  PlaceResult({required this.name, required this.lat, required this.lon});
}

class GeocodeService {
  // Roughly bounds results to the Delhi area.
  static const String _viewbox = "76.80,28.90,77.40,28.35";

  static Future<List<PlaceResult>> searchPlace(String query) async {
    if (query.trim().length < 3) return [];

    final uri = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=${Uri.encodeComponent('$query, Delhi')}"
      "&format=json&limit=5&viewbox=$_viewbox&bounded=1",
    );

    final res = await http.get(
      uri,
      headers: {
        // Nominatim's usage policy asks for an identifying User-Agent.
        "User-Agent": "AirSenseMobileApp/1.0",
      },
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception("Geocoding search failed");
    }

    final List<dynamic> data = jsonDecode(res.body);
    return data.map((item) {
      return PlaceResult(
        name: item["display_name"] as String,
        lat: double.parse(item["lat"] as String),
        lon: double.parse(item["lon"] as String),
      );
    }).toList();
  }
}
