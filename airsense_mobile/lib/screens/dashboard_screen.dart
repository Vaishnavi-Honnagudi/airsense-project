import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/weather_models.dart';
import '../models/aqi_utils.dart';
import '../services/api_service.dart';
import '../widgets/weather_background_widget.dart';
import '../widgets/delhi_extremes_widget.dart';
import '../widgets/delhi_notifications_sheet.dart';
import '../widgets/airsense_ai_bot_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToMapRoute;

  const DashboardScreen({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToMapRoute,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Exclusively Delhi monitoring zones & DPCC stations
  int _selectedZoneIndex = 0; // 0 = Central (Connaught Place), 1 = East (Anand Vihar), 2 = South (R.K. Puram), 3 = North (Wazirpur)
  late CityWeatherAqi _currentData;
  String _forecastGraphMode = "aqi"; // "aqi" | "weather"
  int _contentTabIndex = 0; // 0 = Sensors, 1 = 24h Curve, 2 = Clean Havens, 3 = Health Guide
  WeatherAnimationType _selectedWeatherAnim = WeatherAnimationType.smogHaze;
  bool _isAutoWeather = true;
  bool _isLiveModelOutput = false;
  bool _isLoadingLiveModel = false;
  double? _livePredictedAqi;

  static const List<Map<String, double>> _zoneCoords = [
    {"lat": 28.6315, "lon": 77.2167}, // Connaught Place
    {"lat": 28.6502, "lon": 77.3150}, // Anand Vihar
    {"lat": 28.5660, "lon": 77.1767}, // R.K. Puram
    {"lat": 28.6999, "lon": 77.1654}, // Wazirpur
  ];

  @override
  void initState() {
    super.initState();
    _currentData = CityWeatherAqi.centralDelhi();
    _selectedWeatherAnim = _detectWeatherAnimation(_currentData);
    _fetchLiveModelPrediction(0);
  }

  Future<void> _fetchLiveModelPrediction(int index) async {
    final coords = _zoneCoords[index.clamp(0, _zoneCoords.length - 1)];
    setState(() => _isLoadingLiveModel = true);
    try {
      final res = await ApiService.predictAtLocation(coords["lat"]!, coords["lon"]!);
      if (res.containsKey("interpolated_aqi") && mounted) {
        final aqiVal = (res["interpolated_aqi"] as num).toDouble();
        setState(() {
          _livePredictedAqi = aqiVal;
          _isLiveModelOutput = true;
          _isLoadingLiveModel = false;
        });
      }
    } catch (_) {
      // Backend offline or unreachable — gracefully preserve calibrated baseline reference
      if (mounted) {
        setState(() {
          _livePredictedAqi = null;
          _isLiveModelOutput = false;
          _isLoadingLiveModel = false;
        });
      }
    }
  }

  WeatherAnimationType _detectWeatherAnimation(CityWeatherAqi data) {
    final hour = DateTime.now().hour;
    final isNight = hour >= 19 || hour < 6;

    // 1. Detected rainfall from weather telemetry
    if (data.rainfallMm > 0.0 ||
        data.condition.toLowerCase().contains("rain") ||
        data.condition.toLowerCase().contains("shower") ||
        data.condition.toLowerCase().contains("drizzle")) {
      return WeatherAnimationType.rain;
    }

    // 2. Detected night time in Delhi (7 PM - 6 AM)
    if (isNight) {
      return WeatherAnimationType.night;
    }

    // 3. Detected high pollution / particulate smog during day (AQI > 120 or particulate haze)
    if (data.aqi > 120 ||
        data.condition.toLowerCase().contains("smog") ||
        data.condition.toLowerCase().contains("haze") ||
        data.condition.toLowerCase().contains("dust")) {
      return WeatherAnimationType.smogHaze;
    }

    // 4. Default to clear sunny conditions
    return WeatherAnimationType.sunny;
  }

  void _switchZone(int index) {
    setState(() {
      _selectedZoneIndex = index;
      switch (index) {
        case 0:
          _currentData = CityWeatherAqi.centralDelhi();
          break;
        case 1:
          _currentData = CityWeatherAqi.anandVihar();
          break;
        case 2:
          _currentData = CityWeatherAqi.southDelhi();
          break;
        case 3:
          _currentData = CityWeatherAqi.northDelhi();
          break;
        default:
          _currentData = CityWeatherAqi.centralDelhi();
      }
      _selectedWeatherAnim = _detectWeatherAnimation(_currentData);
    });
    _fetchLiveModelPrediction(index);
  }

  void _cycleWeatherAnimation() {
    setState(() {
      _isAutoWeather = false;
      switch (_selectedWeatherAnim) {
        case WeatherAnimationType.smogHaze:
          _selectedWeatherAnim = WeatherAnimationType.rain;
          break;
        case WeatherAnimationType.rain:
          _selectedWeatherAnim = WeatherAnimationType.sunny;
          break;
        case WeatherAnimationType.sunny:
          _selectedWeatherAnim = WeatherAnimationType.night;
          break;
        case WeatherAnimationType.night:
          _selectedWeatherAnim = WeatherAnimationType.smogHaze;
          break;
      }
    });
  }

  IconData _getWeatherAnimIcon() {
    switch (_selectedWeatherAnim) {
      case WeatherAnimationType.rain:
        return Icons.water_drop_outlined;
      case WeatherAnimationType.sunny:
        return Icons.wb_sunny_outlined;
      case WeatherAnimationType.night:
        return Icons.nightlight_round;
      case WeatherAnimationType.smogHaze:
        return Icons.blur_on_rounded;
    }
  }

  String _getWeatherAnimLabel() {
    String base;
    switch (_selectedWeatherAnim) {
      case WeatherAnimationType.rain:
        base = "Rain / Shower";
        break;
      case WeatherAnimationType.sunny:
        base = "Sunny / Clear";
        break;
      case WeatherAnimationType.night:
        base = "Clear Night";
        break;
      case WeatherAnimationType.smogHaze:
        base = "Hazy Smog";
        break;
    }
    return _isAutoWeather ? "⚡ Live: $base" : base;
  }

  @override
  Widget build(BuildContext context) {
    final aqi = _isLiveModelOutput && _livePredictedAqi != null ? _livePredictedAqi! : _currentData.aqi;
    final aqiCat = categorize(aqi);
    final aqiClr = categoryColor(aqi);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDelhiHeader(),
                const SizedBox(height: 14),
                _buildDelhiZoneChips(),
                const SizedBox(height: 16),
                _buildHeroWeatherAqiCard(aqi, aqiCat, aqiClr),
                const SizedBox(height: 16),
                DelhiExtremesWidget(
                  onSelectZone: _switchZone,
                  onNavigateToCleanSpot: (spot) {
                    widget.onNavigateToMapRoute?.call();
                  },
                ),
                const SizedBox(height: 18),
                _buildSegmentedTabSelector(),
                const SizedBox(height: 16),
                _buildActiveTabContent(aqi, aqiCat, aqiClr),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sleek Segmented Content Tab Selector
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedTabSelector() {
    final tabs = [
      {"label": "Sensors", "icon": Icons.tune_rounded},
      {"label": "24h Curve", "icon": Icons.show_chart_rounded},
      {"label": "Havens", "icon": Icons.park_rounded},
      {"label": "Guide", "icon": Icons.health_and_safety_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _contentTabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _contentTabIndex = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[i]["icon"] as IconData,
                      size: 13,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tabs[i]["label"] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Tab Content Display (Decluttered)
  // ---------------------------------------------------------------------------
  Widget _buildActiveTabContent(double aqi, String aqiCat, Color aqiClr) {
    switch (_contentTabIndex) {
      case 1:
        // 24h Forecast Studio Tab
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("24-Hour Pollution & Weather Trend", "AI LSTM predictive curve across Delhi"),
            const SizedBox(height: 12),
            _build24HourForecastSection(),
          ],
        );
      case 2:
        // Clean Spots Nearby Tab
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NearbyCleanAirSpotsWidget(
              onPlanRoute: (spot) {
                widget.onNavigateToMapRoute?.call();
              },
            ),
          ],
        );
      case 3:
        // Health & Activity Guidance Tab
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Delhi Health & Activity Guidance", "Advisories tailored to current exposure levels"),
            const SizedBox(height: 12),
            _buildLifestyleAdvisoryGrid(aqi, _selectedZoneIndex),
            const SizedBox(height: 20),
            _buildAqiBandsExplainer(),
          ],
        );
      case 0:
      default:
        // Overview & Sensors Tab
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Delhi Atmospheric Conditions", "Real-time microclimate sensors & DPCC feeds"),
            const SizedBox(height: 12),
            _buildAtmosphericParametersGrid(),
            const SizedBox(height: 22),
            _buildSectionHeader("Delhi Major Pollutants", "Real-time concentration vs CPCB safe standards"),
            const SizedBox(height: 12),
            _buildPollutantsMatrix(),
            const SizedBox(height: 20),
            _buildQuickActionCards(),
          ],
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Delhi Location Header & Live Pulse
  // ---------------------------------------------------------------------------
  Widget _buildDelhiHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on, color: Color(0xFF38BDF8), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      "Delhi NCR",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.verified, size: 16, color: Color(0xFF0284C7)),
                  ],
                ),
                Text(
                  _currentData.cityName,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Ask AI Button
            GestureDetector(
              onTap: () => AirSenseAiBotSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF38BDF8)),
                    SizedBox(width: 5),
                    Text(
                      "Air Guide",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Notification Bell Button
            GestureDetector(
              onTap: () => DelhiNotificationsSheet.show(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_outlined, size: 18, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Delhi Zone Selector Horizontal Chips
  // ---------------------------------------------------------------------------
  Widget _buildDelhiZoneChips() {
    final zones = [
      "Connaught Place",
      "Anand Vihar",
      "R.K. Puram",
      "Wazirpur",
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: zones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = _selectedZoneIndex == i;
          return GestureDetector(
            onTap: () => _switchZone(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Text(
                zones[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Signature Hero Weather & AQI Glass Card (Delhi)
  // ---------------------------------------------------------------------------
  Widget _buildHeroWeatherAqiCard(double aqi, String aqiCat, Color aqiClr) {
    return AnimatedWeatherBackground(
      animationType: _selectedWeatherAnim,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: aqiClr.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: aqiClr.withValues(alpha: 0.15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Interactive weather condition switcher & Min/Max
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _cycleWeatherAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getWeatherAnimIcon(), size: 14, color: const Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              Text(
                                _getWeatherAnimLabel(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.tune_rounded, size: 11, color: Colors.white.withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        "H: ${_currentData.maxTemp.toInt()}° · L: ${_currentData.minTemp.toInt()}°",
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),

                // Main metrics: Large Temperature & AQI Dial
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_currentData.temperature.toInt()}",
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 0.95,
                                letterSpacing: -2,
                              ),
                            ),
                            const Text(
                              "°C",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Feels like ${_currentData.feelsLike.toInt()}°C in Delhi",
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isLiveModelOutput
                                ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isLiveModelOutput
                                  ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.22),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLoadingLiveModel
                                    ? Icons.sync
                                    : (_isLiveModelOutput ? Icons.check_circle_outline : Icons.info_outline),
                                size: 10,
                                color: _isLiveModelOutput ? const Color(0xFF34D399) : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isLoadingLiveModel
                                    ? "Querying Model..."
                                    : (_isLiveModelOutput ? "Live LSTM Model (FastAPI)" : "Baseline Reference"),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: _isLiveModelOutput ? const Color(0xFF34D399) : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // AQI Halo Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: aqiClr.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: aqiClr.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                aqi.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: aqiClr,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "AQI",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: aqiClr.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: aqiClr,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              aqiCat.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // Comfort and quick note
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Air Comfort: ${_currentData.airComfort} · ${_getShortAdvisory(aqi)}",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Live Animated Weather Switcher Pill Bar
                Row(
                  children: [
                    _weatherModePill(null, "⚡ Auto", isAuto: true),
                    const SizedBox(width: 5),
                    _weatherModePill(WeatherAnimationType.smogHaze, "🌫️ Smog"),
                    const SizedBox(width: 5),
                    _weatherModePill(WeatherAnimationType.rain, "🌧️ Rain"),
                    const SizedBox(width: 5),
                    _weatherModePill(WeatherAnimationType.sunny, "☀️ Sun"),
                    const SizedBox(width: 5),
                    _weatherModePill(WeatherAnimationType.night, "🌙 Night"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _weatherModePill(WeatherAnimationType? type, String label, {bool isAuto = false}) {
    final isSelected = isAuto ? _isAutoWeather : (!_isAutoWeather && _selectedWeatherAnim == type);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isAuto) {
              _isAutoWeather = true;
              _selectedWeatherAnim = _detectWeatherAnimation(_currentData);
            } else {
              _isAutoWeather = false;
              if (type != null) _selectedWeatherAnim = type;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.32) : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8 Atmospheric Parameter Grid (Delhi)
  // ---------------------------------------------------------------------------
  Widget _buildAtmosphericParametersGrid() {
    final params = [
      _ParamItem(
        title: "FEELS LIKE",
        value: "${_currentData.feelsLike.toInt()}°C",
        subtext: "Urban heat factor",
        icon: Icons.thermostat,
        iconColor: const Color(0xFFF97316),
      ),
      _ParamItem(
        title: "HUMIDITY",
        value: "${_currentData.humidity}%",
        subtext: _currentData.humidity > 60 ? "Moist haze" : "Dry air",
        icon: Icons.water_drop,
        iconColor: const Color(0xFF0284C7),
      ),
      _ParamItem(
        title: "WIND SPEED",
        value: "${_currentData.windSpeedKmh} km/h",
        subtext: "Direction: ${_currentData.windDirection}",
        icon: Icons.air,
        iconColor: const Color(0xFF0D9488),
      ),
      _ParamItem(
        title: "UV INDEX",
        value: "${_currentData.uvIndex}",
        subtext: _currentData.uvIndex > 5 ? "High (Wear sunscreen)" : "Moderate exposure",
        icon: Icons.wb_sunny_rounded,
        iconColor: const Color(0xFFEAB308),
      ),
      _ParamItem(
        title: "VISIBILITY",
        value: "${_currentData.visibilityKm} km",
        subtext: _currentData.visibilityKm < 5 ? "Dense dust haze" : "Fair horizon",
        icon: Icons.remove_red_eye_outlined,
        iconColor: const Color(0xFF6366F1),
      ),
      _ParamItem(
        title: "PRESSURE",
        value: "${_currentData.pressureMb} mb",
        subtext: "Surface pressure",
        icon: Icons.speed,
        iconColor: const Color(0xFF8B5CF6),
      ),
      _ParamItem(
        title: "CLOUD COVER",
        value: "${_currentData.cloudCoverPct}%",
        subtext: _currentData.cloudCoverPct > 50 ? "Overcast smog" : "Clear sunlight",
        icon: Icons.cloud_outlined,
        iconColor: const Color(0xFF64748B),
      ),
      _ParamItem(
        title: "PRECIPITATION",
        value: "${_currentData.rainfallMm} mm",
        subtext: "Dry season",
        icon: Icons.umbrella_outlined,
        iconColor: const Color(0xFF0284C7),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: params.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, i) {
        final p = params[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(p.icon, size: 16, color: p.iconColor),
                ],
              ),
              Text(
                p.value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                p.subtext,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Interactive 24-Hour Forecast Studio (AQI Curve & Weather Graph)
  // ---------------------------------------------------------------------------
  Widget _build24HourForecastSection() {
    final list = _currentData.hourly;
    final isAqiMode = _forecastGraphMode == "aqi";

    // Compute peaks, minimums and statistical labels
    final aqiValues = list.map((h) => h.aqi).toList();
    final maxAqi = aqiValues.reduce((a, b) => a > b ? a : b);
    final minAqi = aqiValues.reduce((a, b) => a < b ? a : b);
    final peakAqiHour = list.firstWhere((h) => h.aqi == maxAqi).time;

    final tempValues = list.map((h) => h.temp).toList();
    final maxTemp = tempValues.reduce((a, b) => a > b ? a : b);
    final minTemp = tempValues.reduce((a, b) => a < b ? a : b);
    final peakTempHour = list.firstWhere((h) => h.temp == maxTemp).time;

    final spots = <FlSpot>[];
    for (int i = 0; i < list.length; i++) {
      final y = isAqiMode ? list[i].aqi.toDouble() : list[i].temp.toDouble();
      spots.add(FlSpot(i.toDouble(), y));
    }

    final double minY = isAqiMode
        ? (minAqi - 15).clamp(0, 999999).toDouble()
        : (minTemp - 3).clamp(0, 999999).toDouble();
    final double maxY = isAqiMode
        ? (maxAqi + 25).toDouble()
        : (maxTemp + 3).toDouble();

    final themeColor = isAqiMode
        ? categoryColor(maxAqi.toDouble())
        : const Color(0xFFF97316);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Toggle Row (Responsive Full Width)
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _togglePill(
                    label: "24h AQI Curve",
                    icon: Icons.air_rounded,
                    isSelected: isAqiMode,
                    activeColor: const Color(0xFF0F172A),
                    onTap: () => setState(() => _forecastGraphMode = "aqi"),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _togglePill(
                    label: "Weather & Temp",
                    icon: Icons.thermostat_rounded,
                    isSelected: !isAqiMode,
                    activeColor: const Color(0xFF0284C7),
                    onTap: () => setState(() => _forecastGraphMode = "weather"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Peak and Lowest Stats Row
          Row(
            children: [
              _metricSummaryChip(
                icon: Icons.arrow_upward_rounded,
                label: isAqiMode ? "Peak: $maxAqi AQI ($peakAqiHour)" : "High: $maxTemp°C ($peakTempHour)",
                color: themeColor,
              ),
              const SizedBox(width: 8),
              _metricSummaryChip(
                icon: Icons.arrow_downward_rounded,
                label: isAqiMode ? "Lowest: $minAqi AQI" : "Low: $minTemp°C",
                color: const Color(0xFF10B981),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Interactive Graph (LineChart with glowing gradient fill)
          SizedBox(
            height: 175,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (list.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: isAqiMode ? 40 : 4,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: isAqiMode ? 50 : 5,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          isAqiMode ? v.toInt().toString() : "${v.toInt()}°",
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 2,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx >= 0 && idx < list.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              list[idx].time,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                extraLinesData: isAqiMode
                    ? ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: 100,
                          color: const Color(0xFFA8CE39).withValues(alpha: 0.4),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                        HorizontalLine(
                          y: 200,
                          color: const Color(0xFFF08C3A).withValues(alpha: 0.4),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ])
                    : null,
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        if (idx >= 0 && idx < list.length) {
                          final item = list[idx];
                          final valStr = isAqiMode ? "${item.aqi} AQI" : "${item.temp}°C";
                          return LineTooltipItem(
                            "${item.time}\n$valStr · ${item.condition}",
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: themeColor,
                    barWidth: 3.2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isPeak = isAqiMode
                            ? (list[index].aqi == maxAqi)
                            : (list[index].temp == maxTemp);
                        return FlDotCirclePainter(
                          radius: isPeak ? 4.5 : 2.5,
                          color: isPeak ? themeColor : Colors.white,
                          strokeWidth: 2,
                          strokeColor: themeColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          themeColor.withValues(alpha: 0.30),
                          themeColor.withValues(alpha: 0.00),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 14),

          // Synchronized Hourly Timeline Capsules Below Graph
          SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final h = list[index];
                final aqiColor = categoryColor(h.aqi.toDouble());
                final isNow = index == 0;

                return Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isNow ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isNow ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        h.time,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                          color: isNow ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                      Icon(
                        h.icon,
                        size: 19,
                        color: isNow ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                      Text(
                        isAqiMode ? "${h.aqi} AQI" : "${h.temp}°C",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isNow ? Colors.white : (isAqiMode ? aqiColor : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _togglePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricSummaryChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delhi Major Pollutants Matrix
  // ---------------------------------------------------------------------------
  Widget _buildPollutantsMatrix() {
    final pollutants = _currentData.pollutants.values.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: pollutants.map((p) {
          final isHigh = p.ratio > 0.8;
          final isPoor = p.ratio > 1.2;
          final barColor = isPoor
              ? const Color(0xFFEF4444)
              : (isHigh ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "${p.value} ${p.unit}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: barColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: barColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.ratio.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Lifestyle Advisory & Health Guidance (Delhi Context)
  // ---------------------------------------------------------------------------
  Widget _buildLifestyleAdvisoryGrid(double aqi, int zoneIndex) {
    final items = _getLifestyleItems(zoneIndex, aqi);
    final cpcbAdvisory = getAdvisory(aqi);
    final aqiColor = categoryColor(aqi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Dynamic Lifestyle Cards (Full Text, No Ellipsis)
        ...items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Icon + Title + Status Pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 20, color: item.statusColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: item.statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: item.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Full Guidance Text (Completely visible, no truncation)
                Text(
                  item.advice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),

                if (item.highlight.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.highlight,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // Official CPCB Delhi Health Advisory Action Checklist
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: aqiColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: aqiColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: aqiColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.health_and_safety_rounded, size: 20, color: aqiColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CPCB Public Health Checklist",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          "Official standard for ${categorize(aqi)} air quality",
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                cpcbAdvisory.summary,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 10),
              ...cpcbAdvisory.actions.map((act) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: aqiColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(Icons.check, size: 10, color: aqiColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          act,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Zone & AQI Specific Advisory Data Generator
  // ---------------------------------------------------------------------------
  List<_LifestyleItem> _getLifestyleItems(int zoneIndex, double aqi) {
    switch (zoneIndex) {
      case 1: // East Delhi (Anand Vihar - Hotspot)
        return [
          const _LifestyleItem(
            icon: Icons.directions_run_rounded,
            title: "Outdoor Morning Exercise",
            status: "Avoid Outdoor",
            statusColor: Color(0xFFEF4444),
            advice: "Heavy diesel emissions from Anand Vihar ISBT and cold morning inversion create severe ground-level smog. Do NOT jog or exercise outdoors. Shift workouts indoors.",
            highlight: "High particulate concentration near ISBT & Ghazipur border corridor.",
          ),
          const _LifestyleItem(
            icon: Icons.sensor_window_outlined,
            title: "Home Ventilation in East Delhi",
            status: "Keep Sealed",
            statusColor: Color(0xFFEF4444),
            advice: "Keep all windows, balconies, and exterior doors tightly closed throughout the day. Infiltration of fine PM2.5 and highway dust is severe in Anand Vihar.",
            highlight: "Run indoor HEPA air purifier on continuous mode if available.",
          ),
          const _LifestyleItem(
            icon: Icons.masks_outlined,
            title: "Pollution Mask Requirement",
            status: "N95 Mandatory",
            statusColor: Color(0xFFDC2626),
            advice: "A certified N95 or KN95 respirator is strictly required for anyone stepping outside in East Delhi. Simple cloth masks do not filter fine toxic soot.",
            highlight: "Ensure a tight seal around the nose bridge for outdoor transit.",
          ),
          const _LifestyleItem(
            icon: Icons.family_restroom_rounded,
            title: "East Delhi Sensitive Groups",
            status: "High Caution",
            statusColor: Color(0xFF991B1B),
            advice: "Children, elderly residents, and individuals with asthma or cardiovascular conditions must remain indoors. Keep emergency inhalers accessible at all times.",
            highlight: "Consult a healthcare professional if shortness of breath occurs.",
          ),
        ];

      case 2: // South Delhi (R.K. Puram - Green Belt / Best AQI)
        return [
          const _LifestyleItem(
            icon: Icons.directions_run_rounded,
            title: "Outdoor Morning Exercise",
            status: "Safe for Moderate Jog",
            statusColor: Color(0xFF10B981),
            advice: "South Delhi benefits from extensive green cover around Hauz Khas and Sanjay Van. Safe for outdoor walking and moderate jogging away from the main Outer Ring Road.",
            highlight: "Best outdoor jogging window: 7:00 AM – 9:30 AM in park areas.",
          ),
          const _LifestyleItem(
            icon: Icons.sensor_window_outlined,
            title: "Home Ventilation in South Delhi",
            status: "Open Afternoon",
            statusColor: Color(0xFF0284C7),
            advice: "Air out rooms between 12:00 PM and 3:30 PM. Ridge breezes clear residual indoor moisture and stale air when sunlight disperses lower inversion layers.",
            highlight: "Close windows before evening rush hour builds up on Ring Road.",
          ),
          const _LifestyleItem(
            icon: Icons.masks_outlined,
            title: "Pollution Mask Requirement",
            status: "Optional in Parks",
            statusColor: Color(0xFF10B981),
            advice: "Masks are not essential for healthy adults in residential parks. Sensitive individuals and cyclists along Africa Avenue should wear an N95 near intersections.",
            highlight: "Lowest particulate exposure among all 4 Delhi monitoring zones today.",
          ),
          const _LifestyleItem(
            icon: Icons.family_restroom_rounded,
            title: "South Delhi Sensitive Groups",
            status: "Normal Caution",
            statusColor: Color(0xFF10B981),
            advice: "Infants, seniors, and asthma patients can enjoy outdoor recreation in green parks like Deer Park. Stay hydrated and avoid heavy sprints near arterial roadways.",
            highlight: "Air comfort remains acceptable throughout midday hours.",
          ),
        ];

      case 3: // North Delhi (Wazirpur - Industrial Zone)
        return [
          const _LifestyleItem(
            icon: Icons.directions_run_rounded,
            title: "Outdoor Morning Exercise",
            status: "Limit Exertion",
            statusColor: Color(0xFFF97316),
            advice: "Wazirpur experiences elevated industrial emissions and dust from the GT Karnal transit corridor. Avoid heavy cardiovascular sprints outdoors; limit morning walks to low intensity.",
            highlight: "Shift strenuous workouts to an air-conditioned indoor fitness facility.",
          ),
          const _LifestyleItem(
            icon: Icons.sensor_window_outlined,
            title: "Home Ventilation in North Delhi",
            status: "Brief Afternoon Only",
            statusColor: Color(0xFFF59E0B),
            advice: "Keep windows shut during morning industrial startup and late evening traffic. Ventilate briefly between 1:30 PM and 3:30 PM when surface winds disperse smoke plumes.",
            highlight: "Damp-mop indoor surfaces to capture settled industrial dust.",
          ),
          const _LifestyleItem(
            icon: Icons.masks_outlined,
            title: "Pollution Mask Requirement",
            status: "N95 Recommended",
            statusColor: Color(0xFFF97316),
            advice: "Pedestrians and two-wheeler commuters navigating the Ring Road and industrial complexes should wear an N95 mask to filter airborne metallic particulates and fly ash.",
            highlight: "Effective protection against high PM10 and chemical exhaust.",
          ),
          const _LifestyleItem(
            icon: Icons.family_restroom_rounded,
            title: "North Delhi Sensitive Groups",
            status: "Precaution Advised",
            statusColor: Color(0xFFF97316),
            advice: "Elderly residents with chronic bronchitis and children should avoid playing near industrial estates. Keep quick-relief bronchodilators accessible at all times.",
            highlight: "Monitor indoor humidity and consider air filtration plants.",
          ),
        ];

      case 0: // Central Delhi (Connaught Place - Urban Commercial)
      default:
        return [
          const _LifestyleItem(
            icon: Icons.directions_run_rounded,
            title: "Outdoor Morning Exercise",
            status: "Limit Near Roads",
            statusColor: Color(0xFFF59E0B),
            advice: "Connaught Place circles face heavy vehicular exhaust. For morning fitness, choose Central Park or nearby India Gate lawns before 8:00 AM before traffic accumulates.",
            highlight: "Avoid jogging along radial avenues (Barakhamba, Janpath) during commute hours.",
          ),
          const _LifestyleItem(
            icon: Icons.sensor_window_outlined,
            title: "Home Ventilation in Central Delhi",
            status: "Open 1 PM - 4 PM",
            statusColor: Color(0xFF0284C7),
            advice: "Open windows for cross-ventilation during early afternoon (1:00 PM to 4:00 PM) when solar warming lifts ground-level vehicular exhaust. Seal shut by 6:00 PM.",
            highlight: "Keep windows closed during morning rush (8:30 AM - 11:30 AM).",
          ),
          const _LifestyleItem(
            icon: Icons.masks_outlined,
            title: "Pollution Mask Requirement",
            status: "Commuter Caution",
            statusColor: Color(0xFFF59E0B),
            advice: "Commuters walking near Barakhamba Road, Janpath, or waiting at bus stops should wear an N95 mask to block high localized nitrogen dioxide and soot from idling vehicles.",
            highlight: "Essential for two-wheeler and auto-rickshaw riders during rush hours.",
          ),
          const _LifestyleItem(
            icon: Icons.family_restroom_rounded,
            title: "Central Delhi Sensitive Groups",
            status: "Caution at Rush Hours",
            statusColor: Color(0xFFF59E0B),
            advice: "Asthma sufferers and elderly visitors to Central Delhi should take periodic rest in indoor air-conditioned buildings. Avoid standing near congested traffic signals.",
            highlight: "Carry prescribed inhalers and stay well-hydrated throughout the day.",
          ),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // Quick Action Cards to Map (Delhi)
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionCards() {
    return Column(
      children: [
        _actionBanner(
          title: "Explore Live Delhi Pollution Map",
          subtitle: "Inspect DPCC stations, tap any point for instant AQI prediction",
          icon: Icons.map_outlined,
          color: const Color(0xFF0F172A),
          onTap: () => widget.onNavigateToMap?.call(),
        ),
        const SizedBox(height: 10),
        _actionBanner(
          title: "Delhi Clean Route Optimizer",
          subtitle: "Compare travel paths across Delhi to avoid heavy pollution corridors",
          icon: Icons.alt_route_rounded,
          color: const Color(0xFF0284C7),
          onTap: () => (widget.onNavigateToMapRoute ?? widget.onNavigateToMap)?.call(),
        ),
      ],
    );
  }

  Widget _actionBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Understanding AQI Bands
  // ---------------------------------------------------------------------------
  Widget _buildAqiBandsExplainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Understanding Standard AQI Index",
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          ...aqiBands.map((b) {
            final rangeText = b.max == 999999 ? "401 - 500+" : (b.max == 50 ? "0 - 50" : "${b.max - 49} - ${b.max}");
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: Text(
                      b.label,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: b.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      rangeText,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  String _getShortAdvisory(double aqi) {
    if (aqi <= 50) return "Air quality is good. Enjoy outdoor activities.";
    if (aqi <= 100) return "Air quality is acceptable for most Delhi residents.";
    if (aqi <= 200) return "Sensitive individuals should reduce prolonged outdoor exertion.";
    if (aqi <= 300) return "Wear N95 masks when outside in Delhi.";
    return "Emergency conditions — stay indoors with air purifiers.";
  }
}

class _ParamItem {
  final String title;
  final String value;
  final String subtext;
  final IconData icon;
  final Color iconColor;

  const _ParamItem({
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.iconColor,
  });
}

class _LifestyleItem {
  final IconData icon;
  final String title;
  final String status;
  final Color statusColor;
  final String advice;
  final String highlight;

  const _LifestyleItem({
    required this.icon,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.advice,
    this.highlight = "",
  });
}
