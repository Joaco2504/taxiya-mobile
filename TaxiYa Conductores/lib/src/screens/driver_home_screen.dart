import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

import '../features/stats/driver_performance_screen.dart';
import '../features/support/driver_help_screen.dart';
import '../features/trips/driver_trip_widgets.dart';
import '../providers/driver_providers.dart';
import '../services/driver_location_service.dart';
import 'driver_settings_screen.dart';

/// Pantalla principal del chofer activo: mapa Mapbox + interruptor En línea / Fuera de línea.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.profile,
    required this.details,
    required this.onEditDossier,
  });

  final Profile profile;
  final DriverDetails details;
  final VoidCallback onEditDossier;

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _selfMarkerManager;
  CircleAnnotation? _selfMarker;
  final List<StreamSubscription<MapContentGestureContext>> _gestureSubs =
      <StreamSubscription<MapContentGestureContext>>[];

  Timer? _foregroundGpsTimer;
  Timer? _clockRefreshTimer;
  bool _togglingStatus = false;
  bool _gpsSyncError = false;
  bool _followUserLocation = true;
  bool? _lastAppliedDarkStyle;
  late GeoPoint _initialCameraCenter;
  GeoPoint? _latestGps;
  DateTime? _lastSyncAt;

  // Fase 4: Motor de viajes, alertas, cola offline y anti-ghosting
  final TaxiyaSoundService _sound = TaxiyaSoundService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _dismissedOrderIds = <String>{};
  String? _ringingOrderId;
  bool _acceptingOrder = false;
  bool _updatingTrip = false;
  Trip? _optimisticTrip;
  Profile? _passengerProfile;
  String? _loadedPassengerId;

  String? _trackedGhostTripId;
  DateTime? _lastApproachProgressAt;
  double? _bestDistToOriginMeters;
  String? _warned3MinTripId;
  bool _releasingGhostTrip = false;

  @override
  void initState() {
    super.initState();
    _latestGps = widget.details.currentLocation;
    _lastSyncAt = widget.details.lastLocationAt;
    _initialCameraCenter =
        widget.details.currentLocation ?? _localityCenter();
    unawaited(_initAlertNotificationChannel());
    if (widget.details.isOnline) {
      _startGpsLoop();
      unawaited(ref.read(hiveCacheProvider).recordOnlineSessionStart());
      unawaited(ref.read(taxiyaRepositoryProvider).flushPendingTripMutations());
    }
    _clockRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _checkGhostCancelWatchdog();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DriverHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.details.isOnline && widget.details.isOnline) {
      _startGpsLoop();
    } else if (oldWidget.details.isOnline && !widget.details.isOnline) {
      _stopGpsLoop();
      unawaited(_stopIncomingOrderAlert());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_mapboxMap != null && _lastAppliedDarkStyle != isDark) {
      _lastAppliedDarkStyle = isDark;
      unawaited(
        _mapboxMap!.loadStyleURI(
          isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
        ),
      );
    }
  }

  @override
  void dispose() {
    _foregroundGpsTimer?.cancel();
    _clockRefreshTimer?.cancel();
    unawaited(_sound.dispose());
    for (final sub in _gestureSubs) {
      unawaited(sub.cancel());
    }
    _gestureSubs.clear();
    super.dispose();
  }

  void _startGpsLoop() {
    _foregroundGpsTimer?.cancel();
    unawaited(DriverLocationController.startBackgroundService(widget.profile.id));
    _foregroundGpsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_sendSingleGpsTick());
    });
  }

  void _stopGpsLoop() {
    _foregroundGpsTimer?.cancel();
    _foregroundGpsTimer = null;
    unawaited(DriverLocationController.stopBackgroundService());
  }

  Future<void> _sendSingleGpsTick() async {
    if (!widget.details.isOnline) return;
    final repo = ref.read(taxiyaRepositoryProvider);
    final point = await DriverLocationController.getCurrentGeoPoint();
    if (point == null) return;

    await _updateDriverMarker(point);
    if (_followUserLocation) {
      await _followDriverPosition(point);
    }

    try {
      await repo.pushDriverLocation(
        userId: widget.profile.id,
        point: point,
      );
      await repo.flushPendingTripMutations();
      if (mounted) {
        setState(() {
          _latestGps = point;
          _lastSyncAt = DateTime.now();
          _gpsSyncError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _latestGps = point;
          _gpsSyncError = true;
        });
      }
    }
  }

  Future<void> _toggleOnline() async {
    if (_togglingStatus) return;
    setState(() => _togglingStatus = true);

    final repo = ref.read(taxiyaRepositoryProvider);
    final turningOn = !widget.details.isOnline;

    try {
      if (turningOn) {
        final perm = await DriverLocationController.ensurePermissions();
        if (!perm.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  perm.errorMessage ?? 'Activá el GPS para poder conectarte.',
                ),
              ),
            );
          }
          return;
        }

        final point =
            await DriverLocationController.getCurrentGeoPoint() ??
            widget.details.currentLocation ??
            _localityCenter();

        await repo.setDriverOnlineStatus(
          userId: widget.profile.id,
          isOnline: true,
          location: point,
        );
        if (mounted) {
          setState(() {
            _latestGps = point;
            _lastSyncAt = DateTime.now();
            _followUserLocation = true;
          });
        }
        _startGpsLoop();
        await _updateDriverMarker(point);
        await _centerMapOn(point, ensureComfortableZoom: true);
      } else {
        _stopGpsLoop();
        await repo.setDriverOnlineStatus(
          userId: widget.profile.id,
          isOnline: false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos actualizar tu estado. Revisá la señal e intentá de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingStatus = false);
      }
    }
  }

  Locality? _currentLocality() {
    final localities = ref.read(localitiesProvider).value ?? const <Locality>[];
    for (final l in localities) {
      if (l.id == widget.profile.localityId) return l;
    }
    return null;
  }

  TaxiCompany? _currentCompany() {
    final companyId = widget.details.companyId;
    if (companyId == null) return null;
    final companies =
        ref.read(taxiCompaniesProvider).value ?? const <TaxiCompany>[];
    for (final c in companies) {
      if (c.id == companyId) return c;
    }
    return null;
  }

  GeoPoint _localityCenter() {
    return _currentLocality()?.center ?? CatamarcaDefaults.belen;
  }

  Future<void> _updateDriverMarker(GeoPoint point) async {
    final manager = _selfMarkerManager;
    if (manager == null) return;
    final coords = Point(coordinates: Position(point.lng, point.lat));
    final markerColor = (widget.details.isOnline
            ? TaxiyaColors.lightSuccess
            : TaxiyaColors.lightPrimary)
        .toARGB32();
    final existing = _selfMarker;
    if (existing == null) {
      _selfMarker = await manager.create(
        CircleAnnotationOptions(
          geometry: coords,
          circleRadius: 10.5,
          circleColor: markerColor,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3.0,
        ),
      );
    } else {
      existing.geometry = coords;
      existing.circleColor = markerColor;
      await manager.update(existing);
    }
  }

  Future<void> _followDriverPosition(GeoPoint target) async {
    final map = _mapboxMap;
    if (map == null || !_followUserLocation) return;
    final cam = await map.getCameraState();
    if (!mounted || !_followUserLocation) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(target.lng, target.lat)),
        zoom: cam.zoom,
      ),
      MapAnimationOptions(duration: 450),
    );
  }

  Future<void> _centerMapOn(
    GeoPoint target, {
    bool ensureComfortableZoom = false,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    final cam = await map.getCameraState();
    final targetZoom = ensureComfortableZoom && cam.zoom < 14.5
        ? 15.2
        : cam.zoom;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(target.lng, target.lat)),
        zoom: targetZoom,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _recenterOnDriver() async {
    setState(() => _followUserLocation = true);
    final perm = await DriverLocationController.ensurePermissions();
    if (!perm.granted) {
      final fallback = _latestGps ?? _localityCenter();
      await _updateDriverMarker(fallback);
      await _centerMapOn(fallback, ensureComfortableZoom: true);
      return;
    }
    final point =
        await DriverLocationController.getCurrentGeoPoint() ??
        _latestGps ??
        _localityCenter();
    await _updateDriverMarker(point);
    await _centerMapOn(point, ensureComfortableZoom: true);
  }

  void _onUserMapGesture(MapContentGestureContext _) {
    if (_followUserLocation && mounted) {
      setState(() => _followUserLocation = false);
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    _lastAppliedDarkStyle = Theme.of(context).brightness == Brightness.dark;

    for (final sub in _gestureSubs) {
      await sub.cancel();
    }
    _gestureSubs
      ..clear()
      ..add(map.gestures.pan.gestureEvents.listen(_onUserMapGesture))
      ..add(map.gestures.zoom.gestureEvents.listen(_onUserMapGesture))
      ..add(map.gestures.rotate.gestureEvents.listen(_onUserMapGesture))
      ..add(map.gestures.pitch.gestureEvents.listen(_onUserMapGesture));

    await Future.wait(<Future<void>>[
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(enabled: false)),
      map.attribution.updateSettings(AttributionSettings(enabled: false)),
      map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      ),
    ]);

    _selfMarkerManager = await map.annotations.createCircleAnnotationManager();
    final markerPoint = _latestGps ?? _initialCameraCenter;
    await _updateDriverMarker(markerPoint);
  }

  Future<void> _initAlertNotificationChannel() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        settings: const InitializationSettings(android: androidInit),
      );
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'taxiya_driver_orders',
          'Pedidos y alertas de viaje',
          description:
              'Notificaciones prioritarias cuando entra un pedido o vence una demora.',
          importance: Importance.max,
        ),
      );
    } catch (_) {}
  }

  Future<void> _showLocalAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'taxiya_driver_orders',
            'Pedidos y alertas de viaje',
            importance: Importance.max,
            priority: Priority.max,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _syncIncomingOrderAlert(Trip? eligibleOrder) async {
    if (eligibleOrder == null || !widget.details.isOnline) {
      if (_ringingOrderId != null) {
        _ringingOrderId = null;
        await _sound.stopOrderRing();
      }
      return;
    }

    if (_ringingOrderId != eligibleOrder.id) {
      _ringingOrderId = eligibleOrder.id;
      final notify = ref.read(hiveCacheProvider).notifyTrips;
      if (notify) {
        await _sound.startOrderRing();
        await _showLocalAlert(
          id: 9101,
          title: 'Nuevo pedido de taxi',
          body:
              'Subida: ${eligibleOrder.originAddress ?? 'Ver ubicación en mapa'}',
        );
      }
    }
  }

  Future<void> _stopIncomingOrderAlert() async {
    _ringingOrderId = null;
    await _sound.stopOrderRing();
  }

  int _maxPrioritySeconds(List<DriverBadge> badges) {
    var best = 0;
    for (final b in badges) {
      if (b.isActive && b.level.priorityAdvantageSeconds > best) {
        best = b.level.priorityAdvantageSeconds;
      }
    }
    return best;
  }

  Trip? _selectEligibleIncomingOrder(
    List<Trip> searchingTrips,
    List<DriverBadge> badges,
  ) {
    if (!widget.details.isOnline) return null;
    final prioritySec = _maxPrioritySeconds(badges);
    final holdSeconds = (8 - prioritySec).clamp(0, 8);
    final now = DateTime.now();

    for (final trip in searchingTrips) {
      if (_dismissedOrderIds.contains(trip.id)) continue;
      if (!trip.isReadyForDriverDispatch(now)) continue;

      // Escala de prioridad por nivel: Nivel 5-6 (+8s -> 0s espera), 3-4 (+5s -> 3s), 1-2 (+2s -> 6s), 0 (8s).
      if (holdSeconds > 0 && trip.createdAt != null) {
        final ageSec = now.difference(trip.createdAt!.toLocal()).inSeconds;
        if (ageSec < holdSeconds) continue;
      }
      return trip;
    }
    return null;
  }

  Future<void> _loadPassengerForTrip(String passengerId) async {
    if (_loadedPassengerId == passengerId) return;
    _loadedPassengerId = passengerId;
    final prof = await ref
        .read(taxiyaRepositoryProvider)
        .fetchPublicProfileReadOnly(passengerId);
    if (mounted) {
      setState(() => _passengerProfile = prof);
    }
  }

  void _checkGhostCancelWatchdog() {
    if (_releasingGhostTrip) return;
    final streamTrip = ref.read(activeDriverTripProvider).value;
    final trip = _optimisticTrip ?? streamTrip;
    if (trip == null ||
        (trip.status != TripStatus.accepted &&
            trip.status != TripStatus.arriving)) {
      _trackedGhostTripId = null;
      _lastApproachProgressAt = null;
      _bestDistToOriginMeters = null;
      _warned3MinTripId = null;
      return;
    }

    final origin = trip.originPoint;
    final driverGps = _latestGps ?? widget.details.currentLocation;
    if (origin == null || driverGps == null) return;

    final dist = haversineDistanceMeters(
      driverGps.lat,
      driverGps.lng,
      origin.lat,
      origin.lng,
    );

    if (_trackedGhostTripId != trip.id) {
      _trackedGhostTripId = trip.id;
      _lastApproachProgressAt = DateTime.now();
      _bestDistToOriginMeters = dist;
      _warned3MinTripId = null;
      return;
    }

    final best = _bestDistToOriginMeters ?? dist;
    if (dist < best - 30.0 || dist <= 120.0) {
      _bestDistToOriginMeters = dist < best ? dist : best;
      _lastApproachProgressAt = DateTime.now();
      _warned3MinTripId = null;
      return;
    }

    final baseline = _lastApproachProgressAt;
    if (baseline == null) return;
    final stagnantSeconds = DateTime.now().difference(baseline).inSeconds;

    if (stagnantSeconds >= 180 &&
        stagnantSeconds < 240 &&
        _warned3MinTripId != trip.id) {
      _warned3MinTripId = trip.id;
      unawaited(_sound.playWarning());
      unawaited(
        _showLocalAlert(
          id: 9102,
          title: '¿Seguís yendo al punto de salida?',
          body:
              'En 1 minuto el viaje se liberará si no te acercás al pasajero.',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'Llevás 3 minutos sin acercarte al pasajero. Avanzá para no perder el viaje.',
            ),
          ),
        );
      }
    } else if (stagnantSeconds >= 240) {
      _releasingGhostTrip = true;
      unawaited(_releaseGhostTrip(trip));
    }
  }

  Future<void> _releaseGhostTrip(Trip trip) async {
    try {
      await ref.read(taxiyaRepositoryProvider).releaseTripToSearching(
        tripId: trip.id,
        driverId: widget.profile.id,
        reason: 'auto_released_4min_no_approach',
      );
      if (mounted) {
        setState(() {
          _optimisticTrip = null;
          _trackedGhostTripId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'El viaje se liberó automáticamente tras 4 minutos sin acercarte.',
            ),
          ),
        );
      }
    } catch (_) {
      // Si falló la red, reintentará en el próximo ciclo.
    } finally {
      _releasingGhostTrip = false;
    }
  }

  Future<void> _acceptIncomingOrder(Trip trip) async {
    if (_acceptingOrder) return;
    setState(() => _acceptingOrder = true);
    await _stopIncomingOrderAlert();
    try {
      final taken = await ref
          .read(taxiyaRepositoryProvider)
          .acceptTripAtomically(tripId: trip.id, driverId: widget.profile.id);
      if (!mounted) return;
      if (taken == null) {
        setState(() => _dismissedOrderIds.add(trip.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Otro taxi aceptó este pedido recién.'),
          ),
        );
        return;
      }
      setState(() {
        _optimisticTrip = taken;
        _trackedGhostTripId = taken.id;
        _lastApproachProgressAt = DateTime.now();
      });
      unawaited(_loadPassengerForTrip(taken.passengerId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos tomar el viaje. Revisá tu conexión e intentá de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingOrder = false);
    }
  }

  Future<void> _advanceTripStatus(
    Trip trip,
    TripStatus nextStatus, {
    String? cancelReason,
    String? cancelledBy,
    bool offlineFallback = true,
  }) async {
    if (_updatingTrip) return;
    setState(() => _updatingTrip = true);
    final repo = ref.read(taxiyaRepositoryProvider);
    try {
      final synced = await repo.updateTripStatus(
        tripId: trip.id,
        nextStatus: nextStatus,
        cancelReason: cancelReason,
        cancelledBy: cancelledBy,
        queueOffline: offlineFallback,
      );
      if (!mounted) return;
      setState(() {
        _optimisticTrip = nextStatus.isTerminal
            ? null
            : trip.copyWith(status: nextStatus);
      });
      if (!synced) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin señal 4G. Guardamos el avance y se subirá al volver la señal.',
            ),
          ),
        );
      } else if (nextStatus == TripStatus.completed) {
        unawaited(_syncDriverBadgesQuietly());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje finalizado. Seguís en línea.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos guardar el cambio. Probá de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingTrip = false);
    }
  }

  Future<void> _syncDriverBadgesQuietly() async {
    try {
      final repo = ref.read(taxiyaRepositoryProvider);
      final trips = await repo.fetchDriverTripsHistory(widget.profile.id);
      final ratings = await repo.fetchDriverRatings(widget.profile.id);
      final badgeConfigs =
          await repo.fetchBadgeConfigs(widget.profile.localityId);
      final weekStart = DriverStatsCalculator.startOfPeriod(
        DateTime.now(),
        StatsPeriod.week,
      );
      final weekHours = ref
          .read(hiveCacheProvider)
          .calculateOnlineHoursSince(weekStart);
      final stats = DriverStatsCalculator.compute(
        driverId: widget.profile.id,
        period: StatsPeriod.week,
        trips: trips,
        ratings: ratings,
        onlineHoursInPeriod: weekHours,
        badgeConfigs: badgeConfigs,
        profileRatingAvg: widget.details.ratingAvg,
      );
      final res = await repo.syncProgressiveDriverBadges(
        driverId: widget.profile.id,
        progressByCode: stats.badgeProgress,
      );
      ref.invalidate(driverBadgesProvider);

      if (res.levelUps.isNotEmpty) {
        final first = res.levelUps.first;
        final title = 'Subiste a nivel ${first.newLevel.labelAr}';
        final body =
            'Desbloqueaste ${first.badgeCode.labelAr} (${first.newLevel.labelAr}). ${first.newLevel.rewardSummaryAr}';
        unawaited(_sound.playChime());
        unawaited(_showLocalAlert(id: 9105, title: title, body: body));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              content: Text('$title — ${first.badgeCode.labelAr}'),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _cancelActiveTrip(Trip trip) async {
    const reasons = <String>[
      'Falla mecánica del vehículo',
      'Calle cortada o zona intransitable',
      'No encontré al pasajero tras esperar',
      'Otro inconveniente',
    ];
    var chosen = reasons.first;
    final picked = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setLocalState) {
            return AlertDialog(
              title: const Text('Cancelar viaje'),
              content: RadioGroup<String>(
                groupValue: chosen,
                onChanged: (String? val) {
                  if (val != null) setLocalState(() => chosen = val);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons
                      .map(
                        (String r) => RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: r,
                          title: Text(r),
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Volver'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ctx.taxiyaColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(chosen),
                  child: const Text('Confirmar cancelación'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    await _advanceTripStatus(
      trip,
      TripStatus.cancelled,
      cancelReason: picked,
      cancelledBy: widget.profile.id,
      offlineFallback: false,
    );
  }

  Future<void> _handleDriverPanic(Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Activar botón de pánico'),
        content: const Text(
          'Enviaremos una alerta prioritaria al centro operativo con tu ubicación actual y este viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.taxiyaColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar alerta ahora'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final point =
        await DriverLocationController.getCurrentGeoPoint() ??
        _latestGps ??
        _localityCenter();
    final gpsLabel =
        '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)} · https://maps.google.com/?q=${point.lat},${point.lng}';

    try {
      await ref.read(taxiyaRepositoryProvider).createSupportTicket(
        userId: widget.profile.id,
        tripId: trip.id,
        localityId: trip.localityId ?? widget.profile.localityId,
        category: 'Emergencia del chofer',
        description:
            'EMERGENCIA EN VIAJE — Chofer: ${widget.profile.fullName ?? widget.profile.id} (Patente ${widget.details.plateNumber ?? 'N/D'}). GPS: $gpsLabel',
        isEmergency: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'Alerta de emergencia enviada al centro operativo TaxiYa.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos enviar la alerta sin señal. Llamá al 911 si corrés peligro.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locality = _currentLocality();
    final company = _currentCompany();
    final isOnline = widget.details.isOnline;

    final searchingTrips =
        ref.watch(searchingTripsProvider).value ?? const <Trip>[];
    final streamActiveTrip = ref.watch(activeDriverTripProvider).value;
    final badges = ref.watch(driverBadgesProvider).value ?? const <DriverBadge>[];
    final activeTrip = _optimisticTrip != null && !_optimisticTrip!.status.isTerminal
        ? (_optimisticTrip!)
        : streamActiveTrip;
    if (streamActiveTrip != null && _optimisticTrip != null) {
      if (streamActiveTrip.status == _optimisticTrip!.status ||
          streamActiveTrip.status.isTerminal) {
        _optimisticTrip = null;
      }
    }

    if (activeTrip != null && activeTrip.passengerId != _loadedPassengerId) {
      unawaited(_loadPassengerForTrip(activeTrip.passengerId));
    }

    final incomingOrder = activeTrip == null
        ? _selectEligibleIncomingOrder(searchingTrips, badges)
        : null;
    unawaited(_syncIncomingOrderAlert(incomingOrder));

    final pendingMutationsCount =
        ref.watch(hiveCacheProvider).loadPendingTripMutations().length;

    final expiry = widget.details.permitExpiryDate;
    final daysToExpire = expiry?.difference(DateTime.now()).inDays;
    final showExpiryWarning = daysToExpire != null && daysToExpire <= 15;
    final isNightShift = TaxiyaDateUtils.isNightShift();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            TaxiyaAvatar(
              avatarUrl: widget.profile.avatarUrl,
              fullName: widget.profile.fullName,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.fullName ?? 'Chofer TaxiYa',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    locality?.name ?? 'Catamarca',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tu rendimiento y logros',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DriverPerformanceScreen(
                    profile: widget.profile,
                    details: widget.details,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ayuda y guía de uso',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              openDriverHelpScreen(
                context: context,
                profile: widget.profile,
                localityName: locality?.name ?? 'Catamarca',
                activeTripId: activeTrip?.id,
              );
            },
          ),
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DriverSettingsScreen(
                    onEditDossier: widget.onEditDossier,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: ValueKey<String>(widget.profile.id),
            styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
            viewport: CameraViewportState(
              center: Point(
                coordinates: Position(
                  _initialCameraCenter.lng,
                  _initialCameraCenter.lat,
                ),
              ),
              zoom: 14.5,
            ),
            onMapCreated: _onMapCreated,
          ),

          // Banners superiores (Turno Nocturno, vencimiento próximo, fallo 4G)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isNightShift)
                  _StatusPillBanner(
                    icon: Icons.nights_stay_rounded,
                    color: scheme.secondary,
                    text:
                        'Turno Nocturno (${TaxiyaDateUtils.nightShiftRangeLabel(context)})',
                  ),
                if (showExpiryWarning) ...[
                  if (isNightShift) const SizedBox(height: 8),
                  _StatusPillBanner(
                    icon: Icons.warning_amber_rounded,
                    color: daysToExpire < 0 ? colors.error : colors.warning,
                    text: daysToExpire < 0
                        ? 'Tu habilitación municipal venció el ${TaxiyaDateUtils.formatDateAr(expiry)}. Actualizala.'
                        : 'Tu habilitación vence en $daysToExpire días (${TaxiyaDateUtils.formatDateAr(expiry)}).',
                  ),
                ],
                if (_gpsSyncError) ...[
                  const SizedBox(height: 8),
                  _StatusPillBanner(
                    icon: Icons.signal_wifi_bad_rounded,
                    color: colors.warning,
                    text:
                        'Sin señal 4G. Guardamos tu ubicación y reintentamos al volver.',
                  ),
                ],
              ],
            ),
          ),

          // Dock inferior dinámico: recenter + pedido entrante / viaje activo / interruptor en línea
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_followUserLocation)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FloatingActionButton.extended(
                            heroTag: 'driver_recenter',
                            onPressed: _recenterOnDriver,
                            icon: const Icon(Icons.my_location_rounded),
                            label: const Text('Mi ubicación'),
                          ),
                        ),
                      ),
                    if (activeTrip != null)
                      DriverActiveTripPanel(
                        trip: activeTrip,
                        passengerProfile: _passengerProfile,
                        driverLocation: _latestGps ?? widget.details.currentLocation,
                        pendingSyncCount: pendingMutationsCount,
                        busy: _updatingTrip,
                        onAdvanceStatus: (TripStatus nextStatus) =>
                            _advanceTripStatus(activeTrip, nextStatus),
                        onLongWaitChoiceWait: () => _advanceTripStatus(
                          activeTrip,
                          TripStatus.waitingReturn,
                        ),
                        onLongWaitChoiceRelease: () => _advanceTripStatus(
                          activeTrip,
                          TripStatus.completed,
                          cancelReason: 'driver_released_wait',
                        ),
                        onOpenChat: () {
                          showTaxiyaTripChatSheet(
                            context: context,
                            tripId: activeTrip.id,
                            currentUserId: widget.profile.id,
                            counterpartName:
                                _passengerProfile?.fullName ?? 'Pasajero',
                            counterpartPhone: _passengerProfile?.phone,
                            quickReplies: const <String>[
                              'Estoy afuera',
                              'Estoy en la puerta',
                              'Llego en 2 minutos',
                              'Salgo para allá',
                            ],
                          );
                        },
                        onPanic: () => _handleDriverPanic(activeTrip),
                        onCancel: () => _cancelActiveTrip(activeTrip),
                      )
                    else ...[
                      if (incomingOrder != null) ...[
                        DriverIncomingOrderCard(
                          trip: incomingOrder,
                          driverLocation:
                              _latestGps ?? widget.details.currentLocation,
                          prioritySeconds: _maxPrioritySeconds(badges),
                          accepting: _acceptingOrder,
                          onAccept: () => _acceptIncomingOrder(incomingOrder),
                          onDismiss: () async {
                            await _stopIncomingOrderAlert();
                            if (mounted) {
                              setState(
                                () => _dismissedOrderIds.add(incomingOrder.id),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          company != null
                                              ? company.name
                                              : 'Taxista independiente',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${widget.details.carBrand ?? ''} ${widget.details.carModel ?? ''} · ${widget.details.plateNumber ?? ''}'
                                              .trim(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isOnline
                                              ? colors.success
                                              : colors.textSecondary)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isOnline ? 'EN LÍNEA' : 'FUERA DE LÍNEA',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isOnline
                                            ? colors.success
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.gps_fixed_rounded,
                                    size: 16,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isOnline
                                          ? 'GPS cada 3 s · ${TaxiyaDateUtils.secondsSinceLabel(_lastSyncAt ?? widget.details.lastLocationAt)}'
                                          : 'GPS pausado hasta que te conectes',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 60,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isOnline
                                        ? colors.success
                                        : scheme.primary,
                                    foregroundColor: isOnline
                                        ? Colors.white
                                        : scheme.onPrimary,
                                  ),
                                  onPressed:
                                      _togglingStatus ? null : _toggleOnline,
                                  icon: _togglingStatus
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Icon(
                                          isOnline
                                              ? Icons.power_settings_new_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 28,
                                        ),
                                  label: Text(
                                    isOnline
                                        ? 'En línea · Tocá para desconectarte'
                                        : 'Fuera de línea · Tocá para conectarte',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPillBanner extends StatelessWidget {
  const _StatusPillBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
