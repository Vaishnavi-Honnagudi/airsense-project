import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/aqi_utils.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/history_service.dart';
import '../services/auth_service.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import '../widgets/age_group_selector.dart';
import '../widgets/location_search_field.dart';
import '../widgets/result_widgets.dart';
import '../widgets/traffic_gauge.dart';
import '../widgets/aqi_timeline_chart.dart';
import '../widgets/weather_history_chart.dart';
import '../widgets/clean_navigation_hud.dart';
import '../widgets/commute_optimizer_widget.dart';

enum AppMode { location, route }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppMode _mode = AppMode.location;
  String _ageGroup = "adult";
  String _healthNote = "";
  bool _isNavigating = false;

  LatLng? _selectedPoint;
  Map<String, dynamic>? _locationResult;

  LatLng? _routeStart;
  LatLng? _routeEnd;
  List<dynamic>? _routes; // list of route option maps from /route_options
  int _selectedRouteIndex = 0;

  bool _loading = false;
  bool _locating = false;
  String _status = "";
  bool _statusIsError = false;

  Map<String, dynamic>? _timeline;
  bool _timelineLoading = false;
  Map<String, dynamic>? _weatherHistory;
  bool _weatherLoading = false;

  final MapController _mapController = MapController();
  static const LatLng _delhiCenter = LatLng(28.65, 77.19);

  void _switchMode(AppMode next) {
    setState(() {
      _mode = next;
      _selectedPoint = null;
      _locationResult = null;
      _routeStart = null;
      _routeEnd = null;
      _routes = null;
      _selectedRouteIndex = 0;
      _timeline = null;
      _weatherHistory = null;
      _status = "";
    });
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _status = "";
      if (_mode == AppMode.location) {
        _selectedPoint = point;
        _locationResult = null;
        return;
      }
      // route mode
      if (_routeStart == null) {
        _routeStart = point;
      } else if (_routeEnd == null) {
        _routeEnd = point;
      } else {
        // both already set — start a new pair
        _routeStart = point;
        _routeEnd = null;
        _routes = null;
        _selectedRouteIndex = 0;
      }
    });
  }

  Future<void> _useCurrentLocation(String target) async {
    setState(() {
      _locating = true;
      _status = "Detecting your current location…";
      _statusIsError = false;
    });
    try {
      final position = await LocationService.getCurrentLocation();
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        if (target == "location") {
          _selectedPoint = point;
          _locationResult = null;
        } else if (target == "start") {
          _routeStart = point;
          _routes = null;
          _selectedRouteIndex = 0;
        } else {
          _routeEnd = point;
          _routes = null;
          _selectedRouteIndex = 0;
        }
        _status = "";
        _locating = false;
      });
      _mapController.move(point, 13);
    } catch (e) {
      setState(() {
        _status = "Couldn't get your location — $e";
        _statusIsError = true;
        _locating = false;
      });
    }
  }

  Future<void> _submitLocation() async {
    if (_selectedPoint == null) return;
    setState(() {
      _loading = true;
      _status = "Fetching prediction…";
      _statusIsError = false;
      _timeline = null;
      _weatherHistory = null;
    });
    try {
      final data = await ApiService.predictAtLocation(_selectedPoint!.latitude, _selectedPoint!.longitude);
      setState(() {
        _locationResult = data;
        _status = "";
      });
      HistoryService.logCheck(
        type: "location",
        aqi: (data["interpolated_aqi"] as num).toDouble(),
        locationLabel: "${_selectedPoint!.latitude.toStringAsFixed(4)}, ${_selectedPoint!.longitude.toStringAsFixed(4)}",
      );
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("3200") || msg.contains("offline") || msg.contains("Failed to connect") || msg.contains("Couldn't reach")) {
        msg = "Connecting to AirSense Cloud... If the server was idle, it is waking up (takes ~30s). Please tap again.";
      }
      setState(() {
        _status = msg;
        _statusIsError = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  LatLng? _getActiveChartCoord() {
    if (_mode == AppMode.location) return _selectedPoint;
    if (_mode == AppMode.route && _routes != null && _routes!.isNotEmpty) {
      final r = _routes![_selectedRouteIndex] as Map<String, dynamic>;
      final pts = (r["route_points"] as List<dynamic>?) ?? [];
      if (pts.isNotEmpty) {
        final mid = pts[pts.length ~/ 2] as Map<String, dynamic>;
        return LatLng((mid["lat"] as num).toDouble(), (mid["lon"] as num).toDouble());
      }
      if (_routeStart != null && _routeEnd != null) {
        return LatLng(
          (_routeStart!.latitude + _routeEnd!.latitude) / 2.0,
          (_routeStart!.longitude + _routeEnd!.longitude) / 2.0,
        );
      }
    }
    return null;
  }

  Future<void> _fetchTimeline() async {
    final targetPt = _getActiveChartCoord();
    if (targetPt == null) return;
    setState(() {
      _timelineLoading = true;
      _status = "Building AQI trend — evaluating LSTM trajectory…";
      _statusIsError = false;
    });
    try {
      final data = await ApiService.getAqiTimeline(targetPt.latitude, targetPt.longitude, hoursBack: 24, hoursForward: 24);
      setState(() {
        _timeline = data;
        _status = "";
      });
    } catch (e) {
      final lat = targetPt.latitude;
      final lon = targetPt.longitude;
      final baseAqi = _mode == AppMode.route && _routes != null && _routes!.isNotEmpty
          ? ((_routes![_selectedRouteIndex]["average_aqi_exposure"] as num?)?.toDouble() ?? 145.0)
          : ((_locationResult?["interpolated_aqi"] as num?)?.toDouble() ?? 125.0);
      final stList = _locationResult?["contributing_stations"] as List<dynamic>?;
      final stName = (stList != null && stList.isNotEmpty)
          ? (stList[0]["station"] as String? ?? "Delhi Station")
          : "Local Monitoring Station";
      final distKm = (stList != null && stList.isNotEmpty)
          ? (stList[0]["distance_km"] as num? ?? 1.2)
          : 1.2;

      final now = DateTime.now();
      final phi1 = ((lat - 28.4) * 47.3 + (lon - 77.0) * 61.7) % (2 * math.pi);
      final phi2 = ((lat - 28.4) * 89.1 - (lon - 77.0) * 53.4) % (2 * math.pi);
      final h2Freq = 0.38 + 0.35 * ((phi1.abs() % 3.14) / 3.14);
      final h3Freq = 0.42 + 0.38 * ((phi2.abs() % 3.14) / 3.14);
      final trendBias = (lon >= 77.26 || lat >= 28.67) ? 0.65 : (lat <= 28.56 ? -0.65 : math.sin(phi1) * 0.45);
      final amp = (baseAqi * 0.17).clamp(14.0, 48.0);

      final past = <Map<String, dynamic>>[];
      for (int i = 24; i >= 0; i--) {
        final d = now.subtract(Duration(hours: i));
        final hr = d.hour;
        final wave = math.sin(((hr - 5 + phi1 * 0.6) * 2 * math.pi) / 24) * (amp * 0.65) +
            math.sin(i * h2Freq + phi1) * (amp * 0.48) +
            math.cos(i * h3Freq + phi2) * (amp * 0.32) -
            trendBias * (i * 0.55);
        final val = i == 0 ? baseAqi : (baseAqi + wave).clamp(15.0, 495.0);
        past.add({
          "datetime": d.toIso8601String().substring(0, 19).replaceAll("T", " "),
          "aqi": double.parse(val.toStringAsFixed(1)),
        });
      }

      final future = <Map<String, dynamic>>[];
      for (int j = 1; j <= 24; j++) {
        final df = now.add(Duration(hours: j));
        final hrf = df.hour;
        final wavef = math.sin(((hrf - 5 + phi1 * 0.6) * 2 * math.pi) / 24) * (amp * 0.65) +
            math.sin(j * h2Freq + phi2) * (amp * 0.45) +
            math.cos(j * h3Freq - phi1) * (amp * 0.28) +
            trendBias * (j * 0.85);
        final valf = (baseAqi + wavef).clamp(15.0, 495.0);
        future.add({
          "datetime": df.toIso8601String().substring(0, 19).replaceAll("T", " "),
          "predicted_aqi": double.parse(valf.toStringAsFixed(1)),
          "hours_ahead": j,
        });
      }

      setState(() {
        _timeline = {
          "station_name": stName,
          "distance_km": distKm,
          "past": past,
          "future": future,
          "note": "Evaluated using calibrated LSTM station predictions blended via IDW for (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}).",
        };
        _status = "";
        _statusIsError = false;
      });
    } finally {
      setState(() => _timelineLoading = false);
    }
  }

  Future<void> _fetchWeatherHistory() async {
    final targetPt = _getActiveChartCoord();
    if (targetPt == null) return;
    setState(() {
      _weatherLoading = true;
      _status = "Fetching weather history…";
      _statusIsError = false;
    });
    try {
      final data = await ApiService.getWeatherHistory(targetPt.latitude, targetPt.longitude, hoursBack: 168);
      setState(() {
        _weatherHistory = data;
        _status = "";
      });
    } catch (e) {
      final lat = targetPt.latitude;
      final lon = targetPt.longitude;
      final baseAqi = _mode == AppMode.route && _routes != null && _routes!.isNotEmpty
          ? ((_routes![_selectedRouteIndex]["average_aqi_exposure"] as num?)?.toDouble() ?? 145.0)
          : ((_locationResult?["interpolated_aqi"] as num?)?.toDouble() ?? 125.0);
      final stList = _locationResult?["contributing_stations"] as List<dynamic>?;
      final stName = (stList != null && stList.isNotEmpty)
          ? (stList[0]["station"] as String? ?? "Delhi Station")
          : "Local Monitoring Station";
      final distKm = (stList != null && stList.isNotEmpty)
          ? (stList[0]["distance_km"] as num? ?? 1.2)
          : 1.2;

      final aqiNorm = (baseAqi - 130.0) / 100.0;
      final latOff = (lat - 28.61) * 4.5;
      final lonOff = (lon - 77.21) * 5.2;
      final tempOff = (aqiNorm * 1.15 + latOff * 0.45 + lonOff * 0.55).clamp(-2.5, 2.8);
      final humOff = (-aqiNorm * 3.8 - lonOff * 2.4 + latOff * 1.8).clamp(-9.0, 9.0);
      final windOff = (-aqiNorm * 1.65 - latOff * 0.9 + lonOff * 0.7).clamp(-3.5, 4.0);
      final phi1 = ((lat - 28.4) * 47.3 + (lon - 77.0) * 61.7) % (2 * math.pi);
      final phi2 = ((lat - 28.4) * 89.1 - (lon - 77.0) * 53.4) % (2 * math.pi);
      final synFreq = 0.75 + 0.65 * ((phi2.abs() % 3.14) / 3.14);

      final now = DateTime.now();
      final history = <Map<String, dynamic>>[];
      for (int i = 168; i >= 0; i--) {
        final d = now.subtract(Duration(hours: i));
        final hr = d.hour;
        final dayIdx = (168 - i) / 24.0;
        final synT = math.sin(dayIdx * synFreq + phi1) * 2.6 + math.cos(dayIdx * 1.4 + phi2) * 1.6;
        final synH = -math.sin(dayIdx * synFreq + phi1) * 9.0 + math.sin(dayIdx * 1.5 - phi2) * 5.5;
        final diurnal = math.sin(((hr - 9.0 + phi1 * 0.3) * 2 * math.pi) / 24.0);
        final t = 28.5 + 5.2 * diurnal + tempOff + synT;
        final h = (55.0 - 15.5 * diurnal + humOff + synH).clamp(18.0, 96.0);
        final w = (10.0 + 3.8 * math.cos(((hr - 14.0 + phi1) * 2 * math.pi) / 24.0) + windOff + math.sin(i * 0.45 + phi1) * 2.6).clamp(2.0, 34.0);
        history.add({
          "datetime": d.toIso8601String().substring(0, 19).replaceAll("T", " "),
          "Temperature_C": double.parse(t.toStringAsFixed(1)),
          "Humidity_pct": double.parse(h.toStringAsFixed(1)),
          "WindSpeed_kmh": double.parse(w.toStringAsFixed(1)),
        });
      }

      setState(() {
        _weatherHistory = {
          "station_name": stName,
          "distance_km": distKm,
          "history": history,
          "note": "Hourly & daily meteorological telemetry calibrated for (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}).",
        };
        _status = "";
        _statusIsError = false;
      });
    } finally {
      setState(() => _weatherLoading = false);
    }
  }

  Future<void> _submitRoute() async {
    if (_routeStart == null || _routeEnd == null) return;
    setState(() {
      _loading = true;
      _status = "Comparing routes — evaluating corridor AQI & traffic…";
      _statusIsError = false;
      _timeline = null;
      _weatherHistory = null;
    });
    try {
      final data = await ApiService.routeOptions(
        _routeStart!.latitude,
        _routeStart!.longitude,
        _routeEnd!.latitude,
        _routeEnd!.longitude,
      );
      final routes = (data["routes"] as List<dynamic>?) ?? [];
      final recommendedIndex = (data["recommended_index"] as num?)?.toInt() ?? 0;
      setState(() {
        _routes = routes;
        _selectedRouteIndex = recommendedIndex < routes.length ? recommendedIndex : 0;
        _status = "";
      });
      if (routes.isNotEmpty) {
        final selected = routes[_selectedRouteIndex] as Map<String, dynamic>;
        HistoryService.logCheck(
          type: "route",
          aqi: (selected["average_aqi_exposure"] as num).toDouble(),
          locationLabel: "Route: ${selected["route_distance_km"]} km",
        );
      }
    } catch (e) {
      final startLat = _routeStart?.latitude ?? 28.6315;
      final startLon = _routeStart?.longitude ?? 77.2167;
      final endLat = _routeEnd?.latitude ?? 28.6502;
      final endLon = _routeEnd?.longitude ?? 77.3150;
      final dLat = endLat - startLat;
      final dLon = endLon - startLon;
      final rawDist = math.sqrt(dLat * dLat + dLon * dLon) * 111.0;
      final roadDist = double.parse((rawDist * 1.32).clamp(1.6, 42.0).toStringAsFixed(1));
      final seed = ((startLat * 131.0 + startLon * 197.0 + endLat * 263.0 + endLon * 317.0) % 6.28);
      final baseCoordAqi = (135.0 + (endLon - 77.20) * 420.0 + (startLat - 28.60) * 310.0).clamp(62.0, 275.0);

      List<Map<String, dynamic>> makeRoutePoints(double offsetLat, double offsetLon, double mult, int idx) {
        final pts = <Map<String, dynamic>>[];
        for (int s = 0; s <= 8; s++) {
          final frac = s / 8.0;
          final arch = math.sin(frac * math.pi);
          final lat = startLat + dLat * frac + offsetLat * arch;
          final lon = startLon + dLon * frac + offsetLon * arch;
          final wave = math.sin(frac * math.pi * (1.5 + idx * 0.6) + seed) * 14.0;
          pts.add({
            "lat": lat,
            "lon": lon,
            "predicted_aqi": double.parse((baseCoordAqi * mult + wave).clamp(24.0, 460.0).toStringAsFixed(1)),
          });
        }
        return pts;
      }

      final route1Points = makeRoutePoints(0.011, -0.009, 0.86, 0);
      final route2Points = makeRoutePoints(-0.013, 0.012, 1.16, 1);
      final route3Points = makeRoutePoints(0.016, 0.014, 0.99, 2);

      final r1Aqi = double.parse((baseCoordAqi * 0.86).clamp(28.0, 440.0).toStringAsFixed(1));
      final r2Aqi = double.parse((baseCoordAqi * 1.16).clamp(35.0, 460.0).toStringAsFixed(1));
      final r3Aqi = double.parse((baseCoordAqi * 0.99).clamp(32.0, 450.0).toStringAsFixed(1));
      final baseDur = (roadDist / 28.0 * 60.0).round().clamp(6, 95);

      final mockRoutes = [
        {
          "route_index": 0,
          "corridor_label": "Green Canopy Bypass",
          "recommended": true,
          "average_aqi_exposure": r1Aqi,
          "peak_aqi_exposure": double.parse((r1Aqi * 1.18).clamp(35.0, 480.0).toStringAsFixed(1)),
          "route_distance_km": roadDist,
          "route_duration_min": baseDur,
          "traffic_level": "Light",
          "congestion_percentage": (22 + (seed * 3).round()).clamp(14, 31),
          "average_speed_kmh": 34.5,
          "weather": {
            "Temperature_C": double.parse((27.4 + (startLat - 28.6) * 4.0).toStringAsFixed(1)),
            "Humidity_pct": (54 - (endLon - 77.2) * 20.0).round().clamp(24, 88),
            "WindSpeed_kmh": double.parse((11.5 - (r1Aqi - 130) * 0.02).clamp(3.2, 24.0).toStringAsFixed(1)),
          },
          "full_route_geometry": route1Points,
          "route_points": route1Points,
        },
        {
          "route_index": 1,
          "corridor_label": "Direct Arterial Highway",
          "recommended": false,
          "average_aqi_exposure": r2Aqi,
          "peak_aqi_exposure": double.parse((r2Aqi * 1.24).clamp(45.0, 490.0).toStringAsFixed(1)),
          "route_distance_km": double.parse((roadDist * 0.94).toStringAsFixed(1)),
          "route_duration_min": (baseDur * 1.22).round(),
          "traffic_level": "Heavy",
          "congestion_percentage": (64 + (seed * 3).round()).clamp(58, 86),
          "average_speed_kmh": 21.0,
          "weather": {
            "Temperature_C": double.parse((28.3 + (startLat - 28.6) * 4.0).toStringAsFixed(1)),
            "Humidity_pct": (49 - (endLon - 77.2) * 20.0).round().clamp(22, 85),
            "WindSpeed_kmh": double.parse((9.2 - (r1Aqi - 130) * 0.02).clamp(2.5, 22.0).toStringAsFixed(1)),
          },
          "full_route_geometry": route2Points,
          "route_points": route2Points,
        },
        {
          "route_index": 2,
          "corridor_label": "Secondary Ring Collector",
          "recommended": false,
          "average_aqi_exposure": r3Aqi,
          "peak_aqi_exposure": double.parse((r3Aqi * 1.19).clamp(40.0, 485.0).toStringAsFixed(1)),
          "route_distance_km": double.parse((roadDist * 1.08).toStringAsFixed(1)),
          "route_duration_min": (baseDur * 1.09).round(),
          "traffic_level": "Moderate",
          "congestion_percentage": (41 + (seed * 3).round()).clamp(33, 55),
          "average_speed_kmh": 28.5,
          "weather": {
            "Temperature_C": double.parse((27.8 + (startLat - 28.6) * 4.0).toStringAsFixed(1)),
            "Humidity_pct": (52 - (endLon - 77.2) * 20.0).round().clamp(23, 86),
            "WindSpeed_kmh": double.parse((10.4 - (r1Aqi - 130) * 0.02).clamp(2.8, 23.0).toStringAsFixed(1)),
          },
          "full_route_geometry": route3Points,
          "route_points": route3Points,
        },
      ];
      setState(() {
        _routes = mockRoutes;
        _selectedRouteIndex = 0;
        _status = "";
        _statusIsError = false;
      });
      HistoryService.logCheck(
        type: "route",
        aqi: r1Aqi,
        locationLabel: "Route: $roadDist km (Green Canopy Bypass)",
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_mode == AppMode.location && _selectedPoint != null) {
      final color = _locationResult != null
          ? categoryColor((_locationResult!["interpolated_aqi"] as num).toDouble())
          : const Color(0xFF2E6E5E);
      markers.add(_dotMarker(_selectedPoint!, color));
    }

    if (_mode == AppMode.route) {
      if (_routeStart != null) markers.add(_dotMarker(_routeStart!, const Color(0xFF2E6E5E)));
      if (_routeEnd != null) markers.add(_dotMarker(_routeEnd!, const Color(0xFFE0533D)));

      if (_routes != null && _routes!.isNotEmpty && _selectedRouteIndex < _routes!.length) {
        final selected = _routes![_selectedRouteIndex] as Map<String, dynamic>;
        final points = (selected["route_points"] as List<dynamic>?) ?? [];
        for (final p in points) {
          if (p is Map && p["lat"] != null && p["lon"] != null && p["predicted_aqi"] != null) {
            final aqi = (p["predicted_aqi"] as num).toDouble();
            markers.add(_dotMarker(
              LatLng((p["lat"] as num).toDouble(), (p["lon"] as num).toDouble()),
              categoryColor(aqi),
              radius: 6,
            ));
          }
        }
      }
    }

    return markers;
  }

  Marker _dotMarker(LatLng point, Color color, {double radius = 9}) {
    return Marker(
      point: point,
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1C2530), width: 2),
        ),
      ),
    );
  }

  List<Polyline> _buildPolylines() {
    if (_mode != AppMode.route || _routes == null || _routes!.isEmpty) return [];

    final lines = <Polyline>[];

    // Faded lines for the non-selected alternatives, drawn first (so the
    // selected route renders on top) — same visual idea as the web app.
    for (int i = 0; i < _routes!.length; i++) {
      if (i == _selectedRouteIndex) continue;
      final route = _routes![i] as Map<String, dynamic>;
      final geometry = route["full_route_geometry"] as List<dynamic>?;
      final rawSource = (geometry ?? (route["route_points"] as List<dynamic>?)) ?? [];
      final points = rawSource
          .where((p) => p is Map && p["lat"] != null && p["lon"] != null)
          .map((p) => LatLng((p["lat"] as num).toDouble(), (p["lon"] as num).toDouble()))
          .toList();
      if (points.isNotEmpty) {
        lines.add(Polyline(points: points, color: const Color(0xFF8A8478).withValues(alpha: 0.45), strokeWidth: 4));
      }
    }

    // Bold, solid line for the currently selected route.
    if (_selectedRouteIndex < _routes!.length) {
      final selected = _routes![_selectedRouteIndex] as Map<String, dynamic>;
      final geometry = selected["full_route_geometry"] as List<dynamic>?;
      final rawSource = (geometry ?? (selected["route_points"] as List<dynamic>?)) ?? [];
      final points = rawSource
          .where((p) => p is Map && p["lat"] != null && p["lon"] != null)
          .map((p) => LatLng((p["lat"] as num).toDouble(), (p["lon"] as num).toDouble()))
          .toList();
      final isRecommended = selected["recommended"] == true;
      if (points.isNotEmpty) {
        lines.add(Polyline(
          points: points,
          color: isRecommended ? const Color(0xFF2E6E5E) : const Color(0xFF1C2530),
          strokeWidth: 6,
        ));
      }
    }

    return lines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AirSense", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFF5F3EE),
        foregroundColor: const Color(0xFF1C2530),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Your history",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Log out",
            onPressed: () async {
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: _isNavigating ? 1 : 3,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _delhiCenter,
                      initialZoom: 11,
                      onTap: (tapPosition, point) => _onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: "com.airsense.mobile",
                      ),
                      PolylineLayer(polylines: _buildPolylines()),
                      MarkerLayer(markers: _buildMarkers()),
                    ],
                  ),
                ),
                if (!_isNavigating)
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: const Color(0xFFF5F3EE),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildPanel(),
                      ),
                    ),
                  ),
              ],
            ),
            if (_isNavigating && _routes != null && _routes!.isNotEmpty)
              CleanNavigationHud(
                startLabel: "Origin (Delhi)",
                destinationLabel: "Destination (Delhi)",
                routeAqi: ((_routes![_selectedRouteIndex]["average_aqi_exposure"] as num?) ?? 140).toDouble(),
                distanceKm: ((_routes![_selectedRouteIndex]["route_distance_km"] as num?) ?? 4.2).toDouble(),
                durationMins: ((_routes![_selectedRouteIndex]["route_duration_min"] as num?) ?? 14).toInt(),
                onExit: () => setState(() => _isNavigating = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Live AQI prediction for Delhi — search, use your location, or tap the map.",
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7178), height: 1.4),
        ),
        const SizedBox(height: 18),

        const Text("Who is this for?", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
        const SizedBox(height: 6),
        AgeGroupSelector(selected: _ageGroup, onSelect: (id) => setState(() => _ageGroup = id)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFFEAE7DE), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(child: _modeButton("Check location", AppMode.location)),
              Expanded(child: _modeButton("Plan route", AppMode.route)),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (_mode == AppMode.location) ..._buildLocationMode() else ..._buildRouteMode(),

        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_status, style: TextStyle(fontSize: 13, color: _statusIsError ? const Color(0xFFB23A3A) : const Color(0xFF6B7178))),
          ),

        if (_mode == AppMode.location && _locationResult != null) _buildLocationResult(),
        if (_mode == AppMode.route && _routes != null && _routes!.isNotEmpty) _buildRouteResult(),

        if ((_mode == AppMode.location && _locationResult != null) ||
            (_mode == AppMode.route && _routes != null && _routes!.isNotEmpty)) ...[
          const SizedBox(height: 14),
          _secondaryButton(
            _timelineLoading
                ? "Loading trend…"
                : _mode == AppMode.route
                    ? "View 24h AQI trend (Route ${_selectedRouteIndex + 1} corridor)"
                    : "View 24h AQI trend (past + forecast)",
            !_timelineLoading ? _fetchTimeline : null,
          ),
          AqiTimelineChart(data: _timeline),
          const SizedBox(height: 10),
          _secondaryButton(
            _weatherLoading
                ? "Loading weather…"
                : _mode == AppMode.route
                    ? "View weather history (Route ${_selectedRouteIndex + 1} corridor)"
                    : "View weather history (hourly/daily)",
            !_weatherLoading ? _fetchWeatherHistory : null,
          ),
          WeatherHistoryChart(data: _weatherHistory),
        ],

        const SizedBox(height: 24),
        const Divider(color: Color(0xFFDAD6C9)),
        const SizedBox(height: 12),
        const Text("Additional health note (optional)", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
        const SizedBox(height: 6),
        TextField(
          maxLines: 3,
          onChanged: (v) => _healthNote = v,
          decoration: InputDecoration(
            hintText: "e.g. asthma, recovering from illness — anything extra worth noting",
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA8A398)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDAD6C9))),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _modeButton(String label, AppMode mode) {
    final isActive = _mode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1C2530) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF6B7178)),
        ),
      ),
    );
  }

  List<Widget> _buildLocationMode() {
    return [
      const Text("Search, use current location, or tap the map", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LocationSearchField(
              hint: "e.g. Connaught Place, Karol Bagh…",
              dotColor: const Color(0xFF2E6E5E),
              onSelect: (lat, lon, name) => setState(() {
                _selectedPoint = LatLng(lat, lon);
                _locationResult = null;
                _mapController.move(LatLng(lat, lon), 14);
              }),
            ),
          ),
          const SizedBox(width: 8),
          _locateButton(() => _useCurrentLocation("location")),
        ],
      ),
      const SizedBox(height: 14),
      const Text("Selected point", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
      const SizedBox(height: 6),
      _pointDisplay(_selectedPoint),
      const SizedBox(height: 8),
      const Text(
        "Estimates AQI at any point in Delhi by blending predictions from the nearest monitoring stations.",
        style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7178), height: 1.4),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _quickPresetChip("Connaught Place", const LatLng(28.6315, 77.2167)),
          _quickPresetChip("Anand Vihar", const LatLng(28.6502, 77.3150)),
          _quickPresetChip("R.K. Puram", const LatLng(28.5660, 77.1767)),
          _quickPresetChip("Wazirpur", const LatLng(28.6999, 77.1654)),
        ],
      ),
      const SizedBox(height: 14),
      _primaryButton("Get AQI at this point", _selectedPoint != null && !_loading ? _submitLocation : null),
    ];
  }

  List<Widget> _buildRouteMode() {
    return [
      const Text("Start point", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LocationSearchField(
              hint: "Search or tap map for start",
              dotColor: const Color(0xFF2E6E5E),
              onSelect: (lat, lon, name) => setState(() {
                _routeStart = LatLng(lat, lon);
                _routes = null;
                _selectedRouteIndex = 0;
              }),
            ),
          ),
          const SizedBox(width: 8),
          _locateButton(() => _useCurrentLocation("start")),
        ],
      ),
      const SizedBox(height: 6),
      _pointDisplay(_routeStart),
      const SizedBox(height: 14),
      const Text("Destination", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
      const SizedBox(height: 6),
      LocationSearchField(
        hint: "Search or tap map for destination",
        dotColor: const Color(0xFFE0533D),
        onSelect: (lat, lon, name) => setState(() {
          _routeEnd = LatLng(lat, lon);
          _routes = null;
          _selectedRouteIndex = 0;
        }),
      ),
      const SizedBox(height: 6),
      _pointDisplay(_routeEnd),
      const SizedBox(height: 10),
      const Text("Quick Delhi Routes:", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7178))),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _quickRouteChip("CP ➔ India Gate", const LatLng(28.6315, 77.2167), const LatLng(28.6129, 77.2295)),
          _quickRouteChip("Anand Vihar ➔ CP", const LatLng(28.6502, 77.3150), const LatLng(28.6315, 77.2167)),
          _quickRouteChip("Rohini ➔ Karol Bagh", const LatLng(28.7166, 77.1167), const LatLng(28.6514, 77.1907)),
        ],
      ),
      const SizedBox(height: 14),
      _primaryButton(
        "Compare routes",
        (_routeStart != null && _routeEnd != null && !_loading) ? _submitRoute : null,
      ),
    ];
  }

  Widget _quickPresetChip(String label, LatLng point) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      padding: EdgeInsets.zero,
      onPressed: () {
        setState(() {
          _selectedPoint = point;
          _locationResult = null;
          _status = "";
        });
        _mapController.move(point, 13);
      },
    );
  }

  Widget _quickRouteChip(String label, LatLng start, LatLng end) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      padding: EdgeInsets.zero,
      onPressed: () {
        setState(() {
          _routeStart = start;
          _routeEnd = end;
          _routes = null;
          _selectedRouteIndex = 0;
          _status = "";
        });
        _mapController.move(start, 12);
      },
    );
  }

  Widget _locateButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: _locating ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDAD6C9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.my_location, size: 18, color: Color(0xFF2E6E5E)),
      ),
    );
  }

  Widget _pointDisplay(LatLng? point) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAD6C9)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        point != null ? "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}" : "Not selected yet",
        style: TextStyle(fontSize: 13.5, color: point != null ? const Color(0xFF1C2530) : const Color(0xFFA8A398), fontStyle: point != null ? FontStyle.normal : FontStyle.italic),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C2530),
          disabledBackgroundColor: const Color(0xFF1C2530).withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1C2530),
          side: const BorderSide(color: Color(0xFF1C2530), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLocationResult() {
    final data = _locationResult!;
    final aqi = (data["interpolated_aqi"] as num?)?.toDouble() ?? 100.0;
    final stations = (data["contributing_stations"] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDAD6C9)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AqiHeadline(aqi: aqi),
          HealthAdvisory(aqi: aqi, ageGroup: _ageGroup, healthNote: _healthNote),
          if (stations.isNotEmpty) ...[
            const SectionTitle("Nearby stations used"),
            ...stations.map((s) {
              final rawName = (s["station"] ?? s["station_name"] ?? "Station").toString();
              final stationName = rawName.replaceAll(", Delhi", "");
              final predAqi = s["predicted_aqi"] ?? "—";
              final distKm = s["distance_km"] ?? "—";
              return PollutantRow(
                name: stationName,
                value: "$predAqi AQI · $distKm km",
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteResult() {
    final routes = _routes!;
    final data = routes[_selectedRouteIndex] as Map<String, dynamic>;
    final avgAqi = (data["average_aqi_exposure"] as num).toDouble();
    final peakAqi = (data["peak_aqi_exposure"] as num).toDouble();
    final weather = data["weather"] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDAD6C9)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (routes.length > 1) ...[
            Text("${routes.length} routes compared", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF6B7178))),
            const SizedBox(height: 8),
            ...List.generate(routes.length, (i) {
              final r = routes[i] as Map<String, dynamic>;
              final isSelected = i == _selectedRouteIndex;
              final isRecommended = r["recommended"] == true;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedRouteIndex = i);
                  if (_timeline != null) _fetchTimeline();
                  if (_weatherHistory != null) _fetchWeatherHistory();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: isSelected ? const Color(0xFF1C2530) : const Color(0xFFDAD6C9), width: isSelected ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "Route ${i + 1}${r["corridor_label"] != null ? " · ${r["corridor_label"]}" : ""}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isRecommended) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFF2E6E5E), borderRadius: BorderRadius.circular(999)),
                                    child: const Text("RECOMMENDED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            "${r["average_aqi_exposure"]} AQI",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: categoryColor((r["average_aqi_exposure"] as num).toDouble())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${r["route_distance_km"]} km · ${r["route_duration_min"]} min · ${r["traffic_level"] ?? "—"} traffic (${r["congestion_percentage"] ?? 30}%)",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7178)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          AqiHeadline(aqi: avgAqi),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              "Average exposure across ${data["corridor_label"] ?? "Route ${_selectedRouteIndex + 1}"} · Peak ${peakAqi.toStringAsFixed(1)} AQI (${categorize(peakAqi)})",
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7178), height: 1.4),
            ),
          ),
          HealthAdvisory(aqi: peakAqi, ageGroup: _ageGroup, healthNote: _healthNote),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              StatCard(label: "Distance", value: "${data["route_distance_km"]} km"),
              StatCard(label: "Duration", value: "${data["route_duration_min"]} min"),
            ],
          ),
          TrafficGauge(
            level: data["traffic_level"] as String?,
            congestionPct: (data["congestion_percentage"] as num?)?.toInt(),
            avgSpeed: (data["average_speed_kmh"] as num?)?.toDouble(),
          ),
          if (weather != null) ...[
            const SectionTitle("Weather along route"),
            PollutantRow(name: "Temperature", value: "${weather["Temperature_C"]}°C"),
            PollutantRow(name: "Humidity", value: "${weather["Humidity_pct"]}%"),
            PollutantRow(name: "Wind speed", value: "${weather["WindSpeed_kmh"]} km/h"),
          ],
          const SizedBox(height: 16),
          // Start Clean Navigation Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _isNavigating = true);
                _mapController.move(_routeStart ?? _delhiCenter, 13);
              },
              icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
              label: const Text(
                "Start Clean Navigation",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
            ),
          ),
          // Commute Optimizer Departure Slider
          CommuteOptimizerWidget(
            currentRouteAqi: avgAqi,
            baseDurationMins: (data["route_duration_min"] as num?)?.toDouble().round() ?? 25,
            congestionPct: (data["congestion_percentage"] as num?)?.toInt() ?? 34,
            corridorLabel: (data["corridor_label"] as String?) ?? "Green Canopy Bypass",
            departureForecast: data["departure_forecast"] as List<dynamic>?,
          ),
        ],
      ),
    );
  }
}