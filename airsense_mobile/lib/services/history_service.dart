import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class HistoryEntry {
  final String id;
  final String type; // "location" | "route"
  final double aqi; // headline AQI value
  final String? locationLabel; // e.g. "East Delhi — Anand Vihar ISBT"
  final DateTime timestamp;
  final bool isFavorite;
  final double? distanceKm;
  final int? durationMins;

  HistoryEntry({
    required this.id,
    required this.type,
    required this.aqi,
    required this.locationLabel,
    required this.timestamp,
    this.isFavorite = false,
    this.distanceKm,
    this.durationMins,
  });

  HistoryEntry copyWith({bool? isFavorite}) {
    return HistoryEntry(
      id: id,
      type: type,
      aqi: aqi,
      locationLabel: locationLabel,
      timestamp: timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
      distanceKm: distanceKm,
      durationMins: durationMins,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "type": type,
      "aqi": aqi,
      "locationLabel": locationLabel,
      "timestamp": timestamp.toIso8601String(),
      "isFavorite": isFavorite,
      "distanceKm": distanceKm,
      "durationMins": durationMins,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map["id"] ?? "",
      type: map["type"] ?? "location",
      aqi: (map["aqi"] as num?)?.toDouble() ?? 0,
      locationLabel: map["locationLabel"],
      timestamp: map["timestamp"] != null
          ? DateTime.tryParse(map["timestamp"].toString()) ?? DateTime.now()
          : DateTime.now(),
      isFavorite: map["isFavorite"] == true,
      distanceKm: (map["distanceKm"] as num?)?.toDouble(),
      durationMins: (map["durationMins"] as num?)?.toInt(),
    );
  }

  factory HistoryEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return HistoryEntry(
      id: id,
      type: data["type"] ?? "location",
      aqi: (data["aqi"] as num?)?.toDouble() ?? 0,
      locationLabel: data["locationLabel"],
      timestamp: (data["timestamp"] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFavorite: data["isFavorite"] == true,
      distanceKm: (data["distanceKm"] as num?)?.toDouble(),
      durationMins: (data["durationMins"] as num?)?.toInt(),
    );
  }
}

class HistoryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _storageKey = "airsense_persistent_history_v2";
  static const int maxCapacity = 70;

  static String? get _uid => AuthService.currentUid;
  static bool _isInitialized = false;

  /// In-memory cache holding up to 70 entries
  static final List<HistoryEntry> _localHistory = [];

  static final StreamController<List<HistoryEntry>> _localStreamController =
      StreamController<List<HistoryEntry>>.broadcast();

  /// Comprehensive Delhi presets covering prominent corridors
  static List<HistoryEntry> _generateDefaultDelhiEntries() {
    final now = DateTime.now();
    return [
      HistoryEntry(
        id: "delhi_hist_1",
        type: "location",
        aqi: 245,
        locationLabel: "East Delhi — Anand Vihar ISBT (DPCC Hotspot)",
        timestamp: now.subtract(const Duration(minutes: 18)),
      ),
      HistoryEntry(
        id: "delhi_hist_2",
        type: "route",
        aqi: 142,
        locationLabel: "Route: Connaught Place → India Gate (3.8 km)",
        timestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
        distanceKm: 3.8,
        durationMins: 12,
        isFavorite: true,
      ),
      HistoryEntry(
        id: "delhi_hist_3",
        type: "location",
        aqi: 135,
        locationLabel: "Central Delhi — Connaught Place (Mandir Marg)",
        timestamp: now.subtract(const Duration(hours: 3, minutes: 15)),
      ),
      HistoryEntry(
        id: "delhi_hist_4",
        type: "location",
        aqi: 88,
        locationLabel: "South Delhi — Lodhi Garden & Nehru Park Haven",
        timestamp: now.subtract(const Duration(hours: 5)),
        isFavorite: true,
      ),
      HistoryEntry(
        id: "delhi_hist_5",
        type: "location",
        aqi: 185,
        locationLabel: "North Delhi — Wazirpur Industrial Area",
        timestamp: now.subtract(const Duration(hours: 8)),
      ),
      HistoryEntry(
        id: "delhi_hist_6",
        type: "route",
        aqi: 215,
        locationLabel: "Route: Anand Vihar → Connaught Place (14.2 km)",
        timestamp: now.subtract(const Duration(hours: 14)),
        distanceKm: 14.2,
        durationMins: 38,
      ),
      HistoryEntry(
        id: "delhi_hist_7",
        type: "location",
        aqi: 118,
        locationLabel: "South Delhi — R.K. Puram Sector 8 (DPCC)",
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      HistoryEntry(
        id: "delhi_hist_8",
        type: "location",
        aqi: 95,
        locationLabel: "Central Ridge Forest — Vande Mataram Marg",
        timestamp: now.subtract(const Duration(days: 1, hours: 6)),
        isFavorite: true,
      ),
      HistoryEntry(
        id: "delhi_hist_9",
        type: "route",
        aqi: 168,
        locationLabel: "Route: Rohini Sector 16 → Karol Bagh (12.5 km)",
        timestamp: now.subtract(const Duration(days: 1, hours: 10)),
        distanceKm: 12.5,
        durationMins: 32,
      ),
      HistoryEntry(
        id: "delhi_hist_10",
        type: "location",
        aqi: 280,
        locationLabel: "North-West Delhi — Jahangirpuri Border",
        timestamp: now.subtract(const Duration(days: 2, hours: 4)),
      ),
      HistoryEntry(
        id: "delhi_hist_11",
        type: "location",
        aqi: 125,
        locationLabel: "South Delhi — Hauz Khas Enclave",
        timestamp: now.subtract(const Duration(days: 2, hours: 9)),
      ),
      HistoryEntry(
        id: "delhi_hist_12",
        type: "location",
        aqi: 104,
        locationLabel: "Heritage Zone — Sunder Nursery Botanical Park",
        timestamp: now.subtract(const Duration(days: 3, hours: 1)),
      ),
    ];
  }

  /// Loads stored records from device flash memory
  static Future<void> _ensureLoaded() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _localHistory.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _localHistory.add(HistoryEntry.fromMap(item));
          }
        }
      }
    } catch (_) {}

    // Fallback to rich defaults if empty
    if (_localHistory.isEmpty) {
      _localHistory.addAll(_generateDefaultDelhiEntries());
    }

    _isInitialized = true;
  }

  static Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapped = _localHistory.take(maxCapacity).map((e) => e.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(mapped));
    } catch (_) {}
  }

  static Stream<List<HistoryEntry>> get _localStream async* {
    await _ensureLoaded();
    yield List<HistoryEntry>.from(_localHistory);
    yield* _localStreamController.stream;
  }

  /// Logs one AQI check or route calculation. Retains the latest 70 logs.
  static Future<void> logCheck({
    required String type, // "location" | "route"
    required double aqi,
    String? locationLabel,
    double? distanceKm,
    int? durationMins,
  }) async {
    await _ensureLoaded();

    final entry = HistoryEntry(
      id: "delhi_${DateTime.now().millisecondsSinceEpoch}",
      type: type,
      aqi: aqi,
      locationLabel: locationLabel,
      timestamp: DateTime.now(),
      distanceKm: distanceKm,
      durationMins: durationMins,
    );

    _localHistory.insert(0, entry);
    // Trim to 70 entries
    if (_localHistory.length > maxCapacity) {
      _localHistory.removeRange(maxCapacity, _localHistory.length);
    }

    _localStreamController.add(List<HistoryEntry>.from(_localHistory));
    await _saveToDisk();

    final uid = _uid;
    if (uid == null) return;

    try {
      await _db.collection("users").doc(uid).collection("history").add({
        "type": type,
        "aqi": aqi,
        "locationLabel": locationLabel,
        "distanceKm": distanceKm,
        "durationMins": durationMins,
        "timestamp": FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Toggles favorite status for a given entry
  static Future<void> toggleFavorite(String entryId) async {
    await _ensureLoaded();
    final idx = _localHistory.indexWhere((e) => e.id == entryId);
    if (idx != -1) {
      final updated = _localHistory[idx].copyWith(
        isFavorite: !_localHistory[idx].isFavorite,
      );
      _localHistory[idx] = updated;
      _localStreamController.add(List<HistoryEntry>.from(_localHistory));
      await _saveToDisk();
    }
  }

  /// Real-time stream of history, most recent first (up to 70 entries).
  static Stream<List<HistoryEntry>> historyStream({int limit = maxCapacity}) {
    final uid = _uid;
    if (uid != null) {
      return _db
          .collection("users")
          .doc(uid)
          .collection("history")
          .orderBy("timestamp", descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => HistoryEntry.fromFirestore(doc.id, doc.data()))
              .toList())
          .handleError((_) => _localStream);
    }

    return _localStream;
  }

  static Future<void> deleteEntry(String entryId) async {
    await _ensureLoaded();
    _localHistory.removeWhere((e) => e.id == entryId);
    _localStreamController.add(List<HistoryEntry>.from(_localHistory));
    await _saveToDisk();

    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection("users").doc(uid).collection("history").doc(entryId).delete();
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    await _ensureLoaded();
    _localHistory.clear();
    _localStreamController.add(List<HistoryEntry>.from(_localHistory));
    await _saveToDisk();
  }
}
