import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/taxiya_env.dart';
import '../models/taxiya_models.dart';
import '../services/hive_cache_service.dart';
import '../utils/postgis_utils.dart';

/// Metadatos públicos del chofer asociados a `driver_details`.
@immutable
class DriverPublicMeta {
  const DriverPublicMeta({
    required this.userId,
    required this.fullName,
    required this.avatarUrl,
    required this.localityId,
    required this.accountStatus,
  });

  final String userId;
  final String? fullName;
  final String? avatarUrl;
  final String? localityId;
  final TaxiyaAccountStatus accountStatus;
}

/// Vista combinada de un taxi en línea para el mapa en tiempo real.
@immutable
class OnlineDriverView {
  const OnlineDriverView({
    required this.details,
    this.driverName,
    this.avatarUrl,
    this.localityId,
    this.company,
  });

  final DriverDetails details;
  final String? driverName;
  final String? avatarUrl;
  final String? localityId;
  final TaxiCompany? company;

  bool get isPrivateCompany => company != null;
  bool get isGpsStale => details.isGpsStale;
  GeoPoint? get location => details.currentLocation;

  String get displayTitle {
    final trimmed = driverName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (details.carModel != null && details.carModel!.isNotEmpty) {
      return '${details.carBrand ?? ''} ${details.carModel}'.trim();
    }
    return 'Taxi habilitado';
  }
}

/// Repositorio central para operaciones Supabase (`taxiya`) + respaldo offline en Hive.
class TaxiyaRepository {
  TaxiyaRepository({
    required this.client,
    required this.cache,
  });

  final SupabaseClient client;
  final HiveCacheService cache;
  final Map<String, DriverPublicMeta> _driverMetaCache = {};

  SupabaseClient get _client => client;
  HiveCacheService get _cache => cache;

  // ---- Localidades y Empresas ----

  Future<List<Locality>> fetchLocalities() async {
    try {
      final rows = await _client
          .from('localities')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);
      final items = (rows as List<dynamic>)
          .map((e) => Locality.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _cache.saveLocalities(items);
      return items;
    } catch (_) {
      return _cache.loadLocalities();
    }
  }

  Future<List<TaxiCompany>> fetchCompanies({String? localityId}) async {
    try {
      final rows = await _client
          .from('taxi_companies')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);
      final all = (rows as List<dynamic>)
          .map((e) => TaxiCompany.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _cache.saveCompanies(all);
      if (localityId == null) return all;
      return all.where((c) => c.localityId == localityId).toList();
    } catch (_) {
      final cached = _cache.loadCompanies();
      if (localityId == null) return cached;
      return cached.where((c) => c.localityId == localityId).toList();
    }
  }

  // ---- Perfiles y Autenticación ----

  Future<Profile?> fetchProfile(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      final profile = Profile.fromJson(Map<String, dynamic>.from(row));
      await _cache.saveProfile(profile);
      return profile;
    } catch (_) {
      final cached = _cache.loadProfile();
      if (cached != null && cached.id == userId) return cached;
      rethrow;
    }
  }

  Stream<Profile?> watchProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: const <String>['id'])
        .eq('id', userId)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          final profile = Profile.fromJson(rows.first);
          unawaited(_cache.saveProfile(profile));
          return profile;
        });
  }

  Future<Profile> upsertProfile({
    required String userId,
    required TaxiyaRole role,
    String? fullName,
    String? phone,
    String? email,
    String? localityId,
    String? avatarUrl,
    TaxiyaAccountStatus? accountStatus,
    String? themeMode,
    bool? notifyPromos,
  }) async {
    final payload = <String, dynamic>{
      'id': userId,
      'role': role.name,
      'full_name': ?fullName?.trim(),
      'phone': ?phone?.trim(),
      'email': ?email?.trim(),
      'locality_id': ?localityId,
      'avatar_url': ?avatarUrl,
      'account_status': ?accountStatus?.name,
      'theme_mode': ?themeMode,
      'notify_promos': ?notifyPromos,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await _client
        .from('profiles')
        .upsert(payload, onConflict: 'id')
        .select()
        .single();
    final profile = Profile.fromJson(Map<String, dynamic>.from(row));
    await _cache.saveProfile(profile);
    return profile;
  }

  Future<Profile> updateProfileFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    final payload = <String, dynamic>{
      ...fields,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client
        .from('profiles')
        .update(payload)
        .eq('id', userId)
        .select()
        .single();
    final profile = Profile.fromJson(Map<String, dynamic>.from(row));
    await _cache.saveProfile(profile);
    return profile;
  }

  Future<void> updateAuthEmail(String email) async {
    await _client.auth.updateUser(UserAttributes(email: email.trim()));
  }

  // ---- Legajo y Ubicación de Taxistas ----

  Future<DriverDetails?> fetchDriverDetails(String userId) async {
    try {
      final row = await _client
          .from('driver_details')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      final details = DriverDetails.fromJson(Map<String, dynamic>.from(row));
      await _cache.saveDriverDetails(details);
      return details;
    } catch (_) {
      final cached = _cache.loadDriverDetails();
      if (cached != null && cached.userId == userId) return cached;
      rethrow;
    }
  }

  Stream<DriverDetails?> watchDriverDetails(String userId) {
    return _client
        .from('driver_details')
        .stream(primaryKey: const <String>['user_id'])
        .eq('user_id', userId)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          final details = DriverDetails.fromJson(rows.first);
          unawaited(_cache.saveDriverDetails(details));
          return details;
        });
  }

  Future<DriverDetails> upsertDriverDetails(Map<String, dynamic> fields) async {
    final payload = <String, dynamic>{
      ...fields,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client
        .from('driver_details')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single();
    final details = DriverDetails.fromJson(Map<String, dynamic>.from(row));
    await _cache.saveDriverDetails(details);
    return details;
  }

  Future<DriverDetails> updateDriverPrivacy({
    required String userId,
    bool? showPlatePublic,
    bool? showPermitPublic,
  }) async {
    final fields = <String, dynamic>{
      'show_plate_public': ?showPlatePublic,
      'show_permit_public': ?showPermitPublic,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client
        .from('driver_details')
        .update(fields)
        .eq('user_id', userId)
        .select()
        .single();
    final details = DriverDetails.fromJson(Map<String, dynamic>.from(row));
    await _cache.saveDriverDetails(details);
    return details;
  }

  Future<void> setDriverOnlineStatus({
    required String userId,
    required bool isOnline,
    GeoPoint? location,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'is_online': isOnline,
      'updated_at': nowIso,
      if (location != null) 'current_location': toPostGisEwkt(location.lat, location.lng),
      if (location != null) 'last_location_at': nowIso,
    };
    await _client.from('driver_details').update(payload).eq('user_id', userId);
    if (location != null) {
      await _cache.clearPendingGps();
    }
  }

  Future<void> pushDriverLocation({
    required String userId,
    required GeoPoint point,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from('driver_details')
          .update(<String, dynamic>{
            'current_location': toPostGisEwkt(point.lat, point.lng),
            'last_location_at': nowIso,
            'updated_at': nowIso,
          })
          .eq('user_id', userId);
      await _cache.clearPendingGps();
    } catch (_) {
      await _cache.savePendingGps(point);
      rethrow;
    }
  }

  /// Flujo en tiempo real de taxis en línea filtrados por localidad.
  Stream<List<OnlineDriverView>> watchOnlineDrivers({
    required String localityId,
    Locality? locality,
    List<TaxiCompany> companies = const [],
  }) {
    final companyById = <String, TaxiCompany>{
      for (final c in companies) c.id: c,
    };

    return _client
        .from('driver_details')
        .stream(primaryKey: const <String>['user_id'])
        .eq('is_online', true)
        .asyncMap((List<Map<String, dynamic>> rows) async {
          final drivers = rows
              .map((r) => DriverDetails.fromJson(r))
              .where((d) => d.currentLocation != null)
              .toList();
          if (drivers.isEmpty) return const <OnlineDriverView>[];

          await _ensureDriverMetaLoaded(drivers.map((d) => d.userId));

          final filtered = <OnlineDriverView>[];
          for (final driver in drivers) {
            final meta = _driverMetaCache[driver.userId];
            final company = driver.companyId != null
                ? companyById[driver.companyId!]
                : null;

            if (meta != null) {
              if (meta.accountStatus != TaxiyaAccountStatus.active) continue;
              if (meta.localityId != null && meta.localityId != localityId) {
                continue;
              }
            } else if (company != null) {
              if (company.localityId != localityId) continue;
            } else if (locality != null && driver.currentLocation != null) {
              final maxMeters = (locality.radiusKm + 15.0) * 1000.0;
              final dist = haversineDistanceMeters(
                locality.center.lat,
                locality.center.lng,
                driver.currentLocation!.lat,
                driver.currentLocation!.lng,
              );
              if (dist > maxMeters) continue;
            }

            filtered.add(
              OnlineDriverView(
                details: driver,
                driverName: meta?.fullName,
                avatarUrl: meta?.avatarUrl,
                localityId: meta?.localityId ?? company?.localityId,
                company: company,
              ),
            );
          }
          return filtered;
        });
  }

  Future<void> _ensureDriverMetaLoaded(Iterable<String> userIds) async {
    final missing = userIds.where((id) => !_driverMetaCache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, locality_id, account_status')
          .inFilter('id', missing);
      for (final raw in rows as List<dynamic>) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String;
        _driverMetaCache[id] = DriverPublicMeta(
          userId: id,
          fullName: map['full_name'] as String?,
          avatarUrl: map['avatar_url'] as String?,
          localityId: map['locality_id'] as String?,
          accountStatus: TaxiyaAccountStatus.fromString(
            map['account_status'] as String?,
          ),
        );
      }
    } catch (_) {
      // Si RLS restringe lectura cruzada de perfiles, continuamos con el filtrado espacial y de empresa.
    }
  }

  // ---- Puntos de referencia públicos y privados ----

  Future<List<Landmark>> fetchLandmarks({
    required String localityId,
    String? userId,
  }) async {
    try {
      final rows = await _client
          .from('landmarks')
          .select()
          .eq('locality_id', localityId)
          .order('name', ascending: true);
      final items = (rows as List<dynamic>)
          .map((e) => Landmark.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((l) =>
              (l.isPublic && l.status == 'approved') ||
              (userId != null && !l.isPublic && l.createdBy == userId))
          .toList();
      await _cache.saveLandmarks(localityId, items);
      return items;
    } catch (_) {
      return _cache.loadLandmarks(localityId);
    }
  }

  Future<Landmark> createLandmark({
    required String localityId,
    required String name,
    required String category,
    required GeoPoint location,
    required bool isPublic,
    required String createdBy,
  }) async {
    final payload = <String, dynamic>{
      'locality_id': localityId,
      'name': name.trim(),
      'category': category.trim(),
      'location': toPostGisEwkt(location.lat, location.lng),
      'is_public': isPublic,
      'status': isPublic ? 'pending' : 'approved',
      'created_by': createdBy,
    };
    final row = await _client
        .from('landmarks')
        .insert(payload)
        .select()
        .single();
    return Landmark.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deletePersonalLandmark(String landmarkId) async {
    await _client
        .from('landmarks')
        .delete()
        .eq('id', landmarkId)
        .eq('is_public', false);
  }

  // ---- Storage (taxiya_private / taxiya_public) ----

  Future<String> uploadPrivateImage({
    required String userId,
    required String docKey,
    required Uint8List jpegBytes,
  }) async {
    final path = '$userId/$docKey.jpg';
    await _client.storage
        .from(TaxiyaEnv.bucketPrivate)
        .uploadBinary(
          path,
          jpegBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  Future<String> uploadPublicImage({
    required String userId,
    required String folder,
    required Uint8List jpegBytes,
  }) async {
    final path = '$folder/$userId.jpg';
    await _client.storage
        .from(TaxiyaEnv.bucketPublic)
        .uploadBinary(
          path,
          jpegBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final publicUrl = _client.storage
        .from(TaxiyaEnv.bucketPublic)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> resolvePrivateSignedUrl(
    String pathOrUrl, {
    int expiresInSeconds = 300,
  }) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    return _client.storage
        .from(TaxiyaEnv.bucketPrivate)
        .createSignedUrl(pathOrUrl, expiresInSeconds);
  }
}
