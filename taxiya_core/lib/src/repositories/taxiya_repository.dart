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

  /// Lee nombre, teléfono y avatar de un pasajero sin pisar `current_profile` en Hive.
  Future<Profile?> fetchPublicProfileReadOnly(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return Profile.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
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
    if (isOnline) {
      await _cache.recordOnlineSessionStart();
    } else {
      await _cache.recordOnlineSessionStop();
    }
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

  // ---- Motor de Viajes en Tiempo Real (Fase 4) ----

  /// Crea un pedido nuevo (`searching`) en `taxiya.trips`.
  Future<Trip> createTrip({
    required String passengerId,
    required String localityId,
    required String originAddress,
    required GeoPoint originPoint,
    String? destAddress,
    GeoPoint? destPoint,
    bool isRoundTrip = false,
    int? waitMinutes,
    DateTime? scheduledFor,
  }) async {
    final payload = <String, dynamic>{
      'passenger_id': passengerId,
      'locality_id': localityId,
      'status': TripStatus.searching.dbValue,
      'origin_address': originAddress.trim(),
      'origin_point': toPostGisEwkt(originPoint.lat, originPoint.lng),
      if (destAddress != null && destAddress.trim().isNotEmpty)
        'dest_address': destAddress.trim(),
      if (destPoint != null)
        'dest_point': toPostGisEwkt(destPoint.lat, destPoint.lng),
      'is_round_trip': isRoundTrip,
      'wait_minutes': ?waitMinutes,
      if (scheduledFor != null)
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
    };
    final row = await _client.from('trips').insert(payload).select().single();
    final trip = Trip.fromJson(Map<String, dynamic>.from(row));
    await _cache.saveActiveTrip(trip);
    return trip;
  }

  /// Repite el último viaje o crea el viaje de regreso prioritario desde uno liberado.
  Future<Trip> createPriorityReturnTrip({
    required String passengerId,
    required Trip previousTrip,
    GeoPoint? currentOriginPoint,
  }) async {
    final originPoint =
        currentOriginPoint ?? previousTrip.destPoint ?? previousTrip.originPoint;
    if (originPoint == null) {
      throw StateError('Falta la ubicación de salida para pedir el regreso.');
    }
    final originLabel =
        (previousTrip.destAddress != null &&
            previousTrip.destAddress!.trim().isNotEmpty)
        ? previousTrip.destAddress!.trim()
        : 'Punto actual de regreso';
    final destLabel = previousTrip.originAddress?.trim();

    final trip = await createTrip(
      passengerId: passengerId,
      localityId: previousTrip.localityId ?? '',
      originAddress: '$originLabel (Regreso prioritario)',
      originPoint: originPoint,
      destAddress: destLabel,
      destPoint: previousTrip.originPoint,
      isRoundTrip: false,
    );
    await _cache.savePendingReturnBaseTrip(null);
    return trip;
  }

  /// Escucha el último viaje del pasajero en tiempo real.
  Stream<Trip?> watchLatestPassengerTrip(String passengerId) {
    return _client
        .from('trips')
        .stream(primaryKey: const <String>['id'])
        .eq('passenger_id', passengerId)
        .order('created_at', ascending: false)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          final trips = rows.map((r) => Trip.fromJson(r)).toList()
            ..sort((a, b) {
              final da = a.createdAt ?? DateTime(2000);
              final db = b.createdAt ?? DateTime(2000);
              return db.compareTo(da);
            });
          final latest = trips.first;
          unawaited(_cache.saveActiveTrip(latest));
          if (latest.status == TripStatus.completed) {
            unawaited(_cache.saveLastCompletedTrip(latest));
          }
          return latest;
        });
  }

  Future<Trip?> fetchLastCompletedPassengerTrip(String passengerId) async {
    try {
      final row = await _client
          .from('trips')
          .select()
          .eq('passenger_id', passengerId)
          .eq('status', TripStatus.completed.dbValue)
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return _cache.loadLastCompletedTrip();
      final trip = Trip.fromJson(Map<String, dynamic>.from(row));
      await _cache.saveLastCompletedTrip(trip);
      return trip;
    } catch (_) {
      return _cache.loadLastCompletedTrip();
    }
  }

  /// Escucha un viaje específico por ID en tiempo real.
  Stream<Trip?> watchTripById(String tripId) {
    return _client
        .from('trips')
        .stream(primaryKey: const <String>['id'])
        .eq('id', tripId)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          final trip = Trip.fromJson(rows.first);
          unawaited(_cache.saveActiveTrip(trip));
          return trip;
        });
  }

  /// Escucha pedidos disponibles (`searching` / `requested`) de una localidad listos para despachar.
  Stream<List<Trip>> watchSearchingTrips({required String localityId}) {
    return _client
        .from('trips')
        .stream(primaryKey: const <String>['id'])
        .eq('status', TripStatus.searching.dbValue)
        .order('created_at', ascending: true)
        .map((List<Map<String, dynamic>> rows) {
          final now = DateTime.now();
          return rows
              .map((r) => Trip.fromJson(r))
              .where(
                (t) =>
                    t.localityId == localityId &&
                    t.driverId == null &&
                    t.isReadyForDriverDispatch(now),
              )
              .toList();
        });
  }

  /// Escucha el viaje activo asignado al chofer (si tiene uno).
  Stream<Trip?> watchActiveDriverTrip(String driverId) {
    return _client
        .from('trips')
        .stream(primaryKey: const <String>['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          final parsed = rows.map((r) => Trip.fromJson(r)).toList()
            ..sort((a, b) {
              final da = a.createdAt ?? DateTime(2000);
              final db = b.createdAt ?? DateTime(2000);
              return db.compareTo(da);
            });
          final active = parsed.where((t) => !t.status.isTerminal).toList();
          if (active.isNotEmpty) {
            unawaited(_cache.saveActiveTrip(active.first));
            return active.first;
          }
          unawaited(_cache.saveActiveTrip(null));
          return null;
        });
  }

  /// Toma atómicamente un viaje libre (`status = searching` y `driver_id IS NULL`).
  /// Retorna `null` si otro chofer lo aceptó antes.
  Future<Trip?> acceptTripAtomically({
    required String tripId,
    required String driverId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from('trips')
        .update(<String, dynamic>{
          'driver_id': driverId,
          'status': TripStatus.accepted.dbValue,
          'accepted_at': nowIso,
        })
        .eq('id', tripId)
        .eq('status', TripStatus.searching.dbValue)
        .isFilter('driver_id', null)
        .select()
        .maybeSingle();
    if (row == null) return null;
    final trip = Trip.fromJson(Map<String, dynamic>.from(row));
    await _cache.saveActiveTrip(trip);
    return trip;
  }

  /// Actualiza el estado del viaje enviando únicamente columnas existentes en `taxiya.trips`.
  /// Si falla por falta de 4G y `queueOffline == true`, guarda la transición en Hive.
  Future<bool> updateTripStatus({
    required String tripId,
    required TripStatus nextStatus,
    String? cancelReason,
    String? cancelledBy,
    bool queueOffline = true,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'status': nextStatus.dbValue,
      if (nextStatus == TripStatus.inProgress) 'started_at': nowIso,
      if (nextStatus == TripStatus.completed) 'completed_at': nowIso,
      'cancel_reason': ?cancelReason,
      'cancelled_by': ?cancelledBy,
    };
    try {
      await _client.from('trips').update(payload).eq('id', tripId);
      if (nextStatus.isTerminal) {
        await _cache.saveActiveTrip(null);
      }
      return true;
    } catch (_) {
      if (!queueOffline) rethrow;
      await _cache.enqueueTripMutation(<String, dynamic>{
        'trip_id': tripId,
        'payload': payload,
      });
      return false;
    }
  }

  /// Reintenta sincronizar actualizaciones de viajes encoladas durante cortes de señal.
  Future<int> flushPendingTripMutations() async {
    final queue = _cache.loadPendingTripMutations();
    if (queue.isEmpty) return 0;
    final remaining = <Map<String, dynamic>>[];
    var syncedCount = 0;

    for (final entry in queue) {
      final tripId = entry['trip_id'] as String?;
      final payload = entry['payload'];
      if (tripId == null || payload is! Map) continue;
      try {
        await _client
            .from('trips')
            .update(Map<String, dynamic>.from(payload))
            .eq('id', tripId);
        syncedCount++;
      } catch (_) {
        remaining.add(entry);
      }
    }

    await _cache.replacePendingTripMutations(remaining);
    return syncedCount;
  }

  /// Libera automáticamente un viaje tras 4 minutos sin acercamiento del chofer.
  Future<void> releaseTripToSearching({
    required String tripId,
    required String driverId,
    required String reason,
  }) async {
    await _client
        .from('trips')
        .update(<String, dynamic>{
          'status': TripStatus.searching.dbValue,
          'driver_id': null,
          'accepted_at': null,
          'cancel_reason': reason,
          'cancelled_by': driverId,
        })
        .eq('id', tripId)
        .eq('driver_id', driverId);
    await _cache.saveActiveTrip(null);
  }

  /// Carga datos públicos del chofer asignado, empresa, foto del auto e insignias activas.
  Future<DriverPublicSummary?> fetchDriverAssignedSummary(
    String driverId,
  ) async {
    final results = await Future.wait<dynamic>([
      _client.from('profiles').select().eq('id', driverId).maybeSingle(),
      _client
          .from('driver_details')
          .select()
          .eq('user_id', driverId)
          .maybeSingle(),
      fetchDriverBadges(driverId),
      fetchCompanies(),
    ]);

    final profileRow = results[0] as Map<String, dynamic>?;
    final detailsRow = results[1] as Map<String, dynamic>?;
    final badges = results[2] as List<DriverBadge>;
    final companies = results[3] as List<TaxiCompany>;

    if (detailsRow == null && profileRow == null) return null;

    final profile =
        profileRow != null ? Profile.fromJson(profileRow) : null;
    final details =
        detailsRow != null ? DriverDetails.fromJson(detailsRow) : null;
    TaxiCompany? company;
    if (details?.companyId != null) {
      for (final c in companies) {
        if (c.id == details!.companyId) {
          company = c;
          break;
        }
      }
    }

    return DriverPublicSummary(
      driverId: driverId,
      fullName: profile?.fullName,
      phone: profile?.phone,
      avatarUrl: profile?.avatarUrl,
      companyName: company?.name,
      companyBadgeColor: company?.badgeColor,
      carBrand: details?.carBrand,
      carModel: details?.carModel,
      carColor: details?.carColor,
      carType: details?.carType,
      carPhotoUrl: details?.carPhotoUrl,
      plateNumber: details?.plateNumber,
      municipalMobileNum: details?.municipalMobileNum,
      showPlatePublic: details?.showPlatePublic ?? true,
      showPermitPublic: details?.showPermitPublic ?? true,
      ratingAvg: details?.ratingAvg,
      totalTrips: details?.totalTrips ?? 0,
      currentLocation: details?.currentLocation,
      lastLocationAt: details?.lastLocationAt,
      activeBadges: badges.where((b) => b.isActive).toList(),
    );
  }

  // ---- Chat en viaje (`taxiya.trip_messages`) ----

  Stream<List<TripMessage>> watchTripMessages(String tripId) {
    return _client
        .from('trip_messages')
        .stream(primaryKey: const <String>['id'])
        .eq('trip_id', tripId)
        .order('created_at', ascending: true)
        .map((List<Map<String, dynamic>> rows) {
          final msgs = rows.map((r) => TripMessage.fromJson(r)).toList()
            ..sort((a, b) {
              final da = a.createdAt ?? DateTime(2000);
              final db = b.createdAt ?? DateTime(2000);
              return da.compareTo(db);
            });
          return msgs;
        });
  }

  Future<TripMessage> sendTripMessage({
    required String tripId,
    required String senderId,
    required String message,
  }) async {
    final row = await _client
        .from('trip_messages')
        .insert(<String, dynamic>{
          'trip_id': tripId,
          'sender_id': senderId,
          'message': message.trim(),
        })
        .select()
        .single();
    return TripMessage.fromJson(Map<String, dynamic>.from(row));
  }

  // ---- Calificaciones (`taxiya.ratings`) ----

  Future<TripRating?> fetchRatingForTrip(String tripId) async {
    final row = await _client
        .from('ratings')
        .select()
        .eq('trip_id', tripId)
        .maybeSingle();
    if (row == null) return null;
    return TripRating.fromJson(Map<String, dynamic>.from(row));
  }

  Future<TripRating> submitRating({
    required String tripId,
    required String passengerId,
    required String driverId,
    required int stars,
    String? comment,
  }) async {
    final clamped = stars.clamp(1, 5);
    final row = await _client
        .from('ratings')
        .insert(<String, dynamic>{
          'trip_id': tripId,
          'passenger_id': passengerId,
          'driver_id': driverId,
          'stars': clamped,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        })
        .select()
        .single();

    // Intentamos recalcular el promedio del chofer si las políticas RLS lo habilitan.
    try {
      final ratingRows = await _client
          .from('ratings')
          .select('stars')
          .eq('driver_id', driverId);
      final list = (ratingRows as List<dynamic>)
          .map((e) => (e as Map)['stars'] as num?)
          .whereType<num>()
          .toList();
      if (list.isNotEmpty) {
        final avg =
            list.fold<double>(0, (acc, v) => acc + v.toDouble()) / list.length;
        await _client
            .from('driver_details')
            .update(<String, dynamic>{
              'rating_avg': double.parse(avg.toStringAsFixed(2)),
            })
            .eq('user_id', driverId);
      }
    } catch (_) {}

    return TripRating.fromJson(Map<String, dynamic>.from(row));
  }

  // ---- Insignias y Rendimiento del Chofer ----

  Future<List<DriverBadge>> fetchDriverBadges(String driverId) async {
    try {
      final rows = await _client
          .from('driver_badges')
          .select()
          .eq('driver_id', driverId)
          .order('awarded_at', ascending: false);
      final items = (rows as List<dynamic>)
          .map((e) => DriverBadge.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _cache.saveDriverBadges(driverId, items);
      return items;
    } catch (_) {
      return _cache.loadDriverBadges(driverId);
    }
  }

  Future<List<DriverBadge>> syncEarnedDriverBadges({
    required String driverId,
    required Set<DriverBadgeCode> earnedCodes,
  }) async {
    final existing = await fetchDriverBadges(driverId);
    final activeCodes = existing
        .where((b) => b.isActive && b.badgeCode != null)
        .map((b) => b.badgeCode!)
        .toSet();
    final missing = earnedCodes.difference(activeCodes);
    if (missing.isEmpty) return existing;

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(days: 14)).toIso8601String();
    for (final code in missing) {
      try {
        await _client.from('driver_badges').insert(<String, dynamic>{
          'driver_id': driverId,
          'badge_code': code.code,
          'awarded_at': now.toIso8601String(),
          'expires_at': expiresAt,
        });
      } catch (_) {}
    }
    return fetchDriverBadges(driverId);
  }

  Future<List<Trip>> fetchDriverTripsHistory(String driverId) async {
    try {
      final rows = await _client
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(200);
      final trips = (rows as List<dynamic>)
          .map((e) => Trip.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _cache.saveDriverTripsHistory(driverId, trips);
      return trips;
    } catch (_) {
      return _cache.loadDriverTripsHistory(driverId);
    }
  }

  Future<List<TripRating>> fetchDriverRatings(String driverId) async {
    try {
      final rows = await _client
          .from('ratings')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(200);
      return (rows as List<dynamic>)
          .map((e) => TripRating.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ---- Soporte y Botón de Pánico (`taxiya.support_tickets`) ----

  Future<SupportTicket> createSupportTicket({
    required String userId,
    String? tripId,
    String? localityId,
    required String category,
    required String description,
    bool isEmergency = false,
  }) async {
    final row = await _client
        .from('support_tickets')
        .insert(<String, dynamic>{
          'user_id': userId,
          'trip_id': ?tripId,
          'locality_id': ?localityId,
          'category': category.trim(),
          'description': description.trim(),
          'is_emergency': isEmergency,
          'status': SupportTicketStatus.open.dbValue,
        })
        .select()
        .single();
    return SupportTicket.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<SupportTicket>> fetchMySupportTickets(String userId) async {
    final rows = await _client
        .from('support_tickets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(25);
    return (rows as List<dynamic>)
        .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
