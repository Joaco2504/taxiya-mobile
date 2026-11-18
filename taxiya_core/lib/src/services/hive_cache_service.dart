import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/taxiya_env.dart';
import '../models/taxiya_models.dart';
import '../utils/postgis_utils.dart';

/// Caché offline con Hive para zonas periféricas con cortes de señal 4G.
class HiveCacheService {
  const HiveCacheService();

  Box<dynamic> get _coreBox => Hive.box<dynamic>(TaxiyaEnv.hiveCoreBox);
  Box<dynamic> get _settingsBox => Hive.box<dynamic>(TaxiyaEnv.hiveSettingsBox);

  // ---- Localidades ----
  Future<void> saveLocalities(List<Locality> items) async {
    final encoded = jsonEncode(items.map((e) => e.toCacheJson()).toList());
    await _coreBox.put('localities', encoded);
  }

  List<Locality> loadLocalities() {
    final raw = _coreBox.get('localities') as String?;
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Locality.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ---- Empresas privadas ----
  Future<void> saveCompanies(List<TaxiCompany> items) async {
    final encoded = jsonEncode(items.map((e) => e.toCacheJson()).toList());
    await _coreBox.put('taxi_companies', encoded);
  }

  List<TaxiCompany> loadCompanies() {
    final raw = _coreBox.get('taxi_companies') as String?;
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => TaxiCompany.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ---- Puntos de referencia ----
  Future<void> saveLandmarks(String localityId, List<Landmark> items) async {
    final encoded = jsonEncode(items.map((e) => e.toCacheJson()).toList());
    await _coreBox.put('landmarks_$localityId', encoded);
  }

  List<Landmark> loadLandmarks(String localityId) {
    final raw = _coreBox.get('landmarks_$localityId') as String?;
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Landmark.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ---- Perfil y legajo actual ----
  Future<void> saveProfile(Profile profile) async {
    await _coreBox.put('current_profile', jsonEncode(profile.toCacheJson()));
  }

  Profile? loadProfile() {
    final raw = _coreBox.get('current_profile') as String?;
    if (raw == null || raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return Profile.fromJson(map);
  }

  Future<void> saveDriverDetails(DriverDetails details) async {
    await _coreBox.put('driver_details', jsonEncode(details.toCacheJson()));
  }

  DriverDetails? loadDriverDetails() {
    final raw = _coreBox.get('driver_details') as String?;
    if (raw == null || raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return DriverDetails.fromJson(map);
  }

  Future<void> clearUserCache() async {
    await _coreBox.delete('current_profile');
    await _coreBox.delete('driver_details');
  }

  // ---- Preferencias locales y respaldo sin señal ----
  String get themeMode =>
      (_settingsBox.get('theme_mode') as String?) ?? 'system';
  Future<void> setThemeMode(String value) =>
      _settingsBox.put('theme_mode', value);

  bool get notifyTrips => (_settingsBox.get('notify_trips') as bool?) ?? true;
  Future<void> setNotifyTrips(bool value) =>
      _settingsBox.put('notify_trips', value);

  bool get notifyPromos => (_settingsBox.get('notify_promos') as bool?) ?? true;
  Future<void> setNotifyPromos(bool value) =>
      _settingsBox.put('notify_promos', value);

  String? get driverMobileUnit => _settingsBox.get('driver_mobile_unit') as String?;
  Future<void> setDriverMobileUnit(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _settingsBox.delete('driver_mobile_unit');
    } else {
      await _settingsBox.put('driver_mobile_unit', value.trim());
    }
  }

  /// Guarda la última coordenada pendiente si falla el 4G para reintentar al volver la señal.
  Future<void> savePendingGps(GeoPoint point) async {
    await _coreBox.put('pending_gps', {
      'lat': point.lat,
      'lng': point.lng,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  GeoPoint? loadPendingGps() {
    final raw = _coreBox.get('pending_gps');
    if (raw is Map) {
      final lat = (raw['lat'] as num?)?.toDouble();
      final lng = (raw['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return GeoPoint(lat: lat, lng: lng);
      }
    }
    return null;
  }

  Future<void> clearPendingGps() => _coreBox.delete('pending_gps');

  // ---- Caché y cola offline de viajes (Fase 4) ----

  Future<void> saveActiveTrip(Trip? trip) async {
    if (trip == null || trip.status.isTerminal) {
      await _coreBox.delete('active_trip');
      return;
    }
    await _coreBox.put('active_trip', jsonEncode(trip.toCacheJson()));
  }

  Trip? loadActiveTrip() {
    final raw = _coreBox.get('active_trip') as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return Trip.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastCompletedTrip(Trip trip) async {
    await _coreBox.put('last_completed_trip', jsonEncode(trip.toCacheJson()));
  }

  Trip? loadLastCompletedTrip() {
    final raw = _coreBox.get('last_completed_trip') as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return Trip.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePendingReturnBaseTrip(Trip? trip) async {
    if (trip == null) {
      await _coreBox.delete('pending_return_trip');
      return;
    }
    await _coreBox.put('pending_return_trip', jsonEncode(trip.toCacheJson()));
  }

  Trip? loadPendingReturnBaseTrip() {
    final raw = _coreBox.get('pending_return_trip') as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return Trip.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueueTripMutation(Map<String, dynamic> mutation) async {
    final items = loadPendingTripMutations();
    items.add(mutation);
    await _coreBox.put('pending_trip_mutations', jsonEncode(items));
  }

  List<Map<String, dynamic>> loadPendingTripMutations() {
    final raw = _coreBox.get('pending_trip_mutations') as String?;
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> replacePendingTripMutations(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      await _coreBox.delete('pending_trip_mutations');
      return;
    }
    await _coreBox.put('pending_trip_mutations', jsonEncode(items));
  }

  Future<void> saveDriverBadges(String driverId, List<DriverBadge> badges) async {
    final encoded = jsonEncode(badges.map((e) => e.toCacheJson()).toList());
    await _coreBox.put('driver_badges_$driverId', encoded);
  }

  List<DriverBadge> loadDriverBadges(String driverId) {
    final raw = _coreBox.get('driver_badges_$driverId') as String?;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => DriverBadge.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveDriverTripsHistory(String driverId, List<Trip> trips) async {
    final encoded = jsonEncode(trips.map((e) => e.toCacheJson()).toList());
    await _coreBox.put('driver_trips_$driverId', encoded);
  }

  List<Trip> loadDriverTripsHistory(String driverId) {
    final raw = _coreBox.get('driver_trips_$driverId') as String?;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Trip.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ---- Registro local de horas conectado del chofer ----

  Future<void> recordOnlineSessionStart([DateTime? now]) async {
    final ts = (now ?? DateTime.now()).toUtc().toIso8601String();
    final current = _coreBox.get('driver_online_session_start') as String?;
    if (current == null || current.isEmpty) {
      await _coreBox.put('driver_online_session_start', ts);
    }
  }

  Future<void> recordOnlineSessionStop([DateTime? now]) async {
    final startRaw = _coreBox.get('driver_online_session_start') as String?;
    await _coreBox.delete('driver_online_session_start');
    if (startRaw == null || startRaw.isEmpty) return;
    final start = DateTime.tryParse(startRaw);
    if (start == null) return;
    final end = (now ?? DateTime.now()).toUtc();
    if (!end.isAfter(start)) return;

    final sessions = _loadOnlineSessions();
    sessions.add(<String, String>{
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    });
    // Conservamos últimos 45 días para mantener liviano el almacenamiento local.
    final cutoff = end.subtract(const Duration(days: 45));
    final recent = sessions.where((item) {
      final parsedEnd = DateTime.tryParse(item['end'] ?? '');
      return parsedEnd == null || parsedEnd.isAfter(cutoff);
    }).toList();
    await _coreBox.put('driver_online_sessions', jsonEncode(recent));
  }

  double calculateOnlineHoursSince(DateTime since, [DateTime? now]) {
    final sinceUtc = since.toUtc();
    final currentUtc = (now ?? DateTime.now()).toUtc();
    var totalSeconds = 0;

    for (final item in _loadOnlineSessions()) {
      final s = DateTime.tryParse(item['start'] ?? '');
      final e = DateTime.tryParse(item['end'] ?? '');
      if (s == null || e == null) continue;
      final effectiveStart = s.isBefore(sinceUtc) ? sinceUtc : s;
      if (e.isAfter(effectiveStart)) {
        totalSeconds += e.difference(effectiveStart).inSeconds;
      }
    }

    final activeStartRaw = _coreBox.get('driver_online_session_start') as String?;
    if (activeStartRaw != null && activeStartRaw.isNotEmpty) {
      final activeStart = DateTime.tryParse(activeStartRaw);
      if (activeStart != null && currentUtc.isAfter(activeStart)) {
        final effectiveStart =
            activeStart.isBefore(sinceUtc) ? sinceUtc : activeStart;
        if (currentUtc.isAfter(effectiveStart)) {
          totalSeconds += currentUtc.difference(effectiveStart).inSeconds;
        }
      }
    }

    return totalSeconds / 3600.0;
  }

  List<Map<String, String>> _loadOnlineSessions() {
    final raw = _coreBox.get('driver_online_sessions') as String?;
    if (raw == null || raw.isEmpty) return <Map<String, String>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return <Map<String, String>>[];
    }
  }
}
