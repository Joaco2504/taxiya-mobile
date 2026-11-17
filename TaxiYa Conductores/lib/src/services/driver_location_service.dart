import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

const String _notificationChannelId = 'taxiya_driver_location';
const int _foregroundNotificationId = 8842;

/// Configura el servicio en segundo plano de geolocalización para choferes en línea.
Future<void> configureDriverBackgroundService() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }

  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    ),
  );

  if (defaultTargetPlatform == TargetPlatform.android) {
    final androidPlugin = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _notificationChannelId,
        'Servicio en línea TaxiYa',
        description:
            'Mantiene tu ubicación activa en tiempo real mientras estás disponible.',
        importance: Importance.low,
      ),
    );
  }

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: driverServiceOnStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: _notificationChannelId,
      initialNotificationTitle: 'TaxiYa Conductores',
      initialNotificationContent: 'Estás en línea transmitiendo tu ubicación',
      foregroundServiceNotificationId: _foregroundNotificationId,
      foregroundServiceTypes: const <AndroidForegroundType>[
        AndroidForegroundType.location,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: driverServiceOnStart,
      onBackground: driverServiceIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> driverServiceIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> driverServiceOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    await initializeTaxiyaCore();
  } catch (_) {
    // Ya inicializado o en curso dentro del isolate.
  }

  final cache = const HiveCacheService();
  final repo = TaxiyaRepository(
    client: Supabase.instance.client,
    cache: cache,
  );

  String? activeUserId =
      Supabase.instance.client.auth.currentUser?.id ?? cache.loadProfile()?.id;

  Timer? timer;
  StreamSubscription<Position>? positionSub;
  GeoPoint? latestPoint;

  if (service is AndroidServiceInstance) {
    unawaited(service.setAsForegroundService());
  }

  service.on('setDriverId').listen((Map<String, dynamic>? event) {
    final uid = event?['userId'] as String?;
    if (uid != null && uid.isNotEmpty) {
      activeUserId = uid;
    }
  });

  service.on('stopService').listen((Map<String, dynamic>? event) async {
    timer?.cancel();
    await positionSub?.cancel();
    await service.stopSelf();
  });

  positionSub = Geolocator.getPositionStream(
    locationSettings: _buildTrackingSettings(),
  ).listen(
    (Position pos) {
      latestPoint = GeoPoint(lat: pos.latitude, lng: pos.longitude);
    },
    onError: (_) {},
  );

  timer = Timer.periodic(const Duration(seconds: 3), (_) async {
    final userId =
        activeUserId ??
        Supabase.instance.client.auth.currentUser?.id ??
        cache.loadProfile()?.id;
    if (userId == null) return;

    GeoPoint? pointToSend = latestPoint;
    if (pointToSend == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 2),
          ),
        );
        pointToSend = GeoPoint(lat: pos.latitude, lng: pos.longitude);
        latestPoint = pointToSend;
      } catch (_) {
        pointToSend = cache.loadPendingGps();
      }
    }

    if (pointToSend == null) return;

    try {
      await repo.pushDriverLocation(userId: userId, point: pointToSend);
      service.invoke('gpsSynced', <String, dynamic>{
        'lat': pointToSend.lat,
        'lng': pointToSend.lng,
        'ts': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      service.invoke('gpsError', <String, dynamic>{
        'lat': pointToSend.lat,
        'lng': pointToSend.lng,
      });
    }
  });
}

LocationSettings _buildTrackingSettings() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 3),
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );
}

/// Resultado de verificar GPS y permisos antes de conectarse en línea.
@immutable
class LocationPermissionResult {
  const LocationPermissionResult({
    required this.granted,
    this.errorMessage,
  });

  final bool granted;
  final String? errorMessage;
}

/// Administra el ciclo de inicio/parada del rastreo en segundo plano del chofer.
abstract final class DriverLocationController {
  static Future<LocationPermissionResult> ensurePermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return const LocationPermissionResult(
        granted: false,
        errorMessage:
            'Tenés el GPS apagado. Activalo desde los ajustes del teléfono.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationPermissionResult(
        granted: false,
        errorMessage:
            'Necesitamos permiso de ubicación para mostrarte en el mapa.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationPermissionResult(
        granted: false,
        errorMessage:
            'El permiso de ubicación está bloqueado. Habilitalo desde Configuración.',
      );
    }

    return const LocationPermissionResult(granted: true);
  }

  static Future<GeoPoint?> getCurrentGeoPoint() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return GeoPoint(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      return GeoPoint(lat: last.latitude, lng: last.longitude);
    }
  }

  static Future<void> startBackgroundService(String userId) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    }
    service.invoke('setDriverId', <String, dynamic>{'userId': userId});
  }

  static Future<void> stopBackgroundService() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (running) {
      service.invoke('stopService');
    }
  }
}
