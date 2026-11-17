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
}
