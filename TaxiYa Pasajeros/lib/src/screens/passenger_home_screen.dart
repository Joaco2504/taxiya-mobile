import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

import '../features/support/passenger_help_screen.dart';
import '../features/trips/passenger_active_trip_card.dart';
import '../features/trips/passenger_trip_modals.dart';
import '../places/place_picker_sheet.dart';
import '../providers/passenger_providers.dart';
import '../services/passenger_location_service.dart';
import 'passenger_settings_screen.dart';

class _InterpolatedDriverState {
  _InterpolatedDriverState({
    required this.driver,
    required this.from,
    required this.to,
    required this.startedAt,
    required this.circleAnnotation,
  });

  OnlineDriverView driver;
  GeoPoint from;
  GeoPoint to;
  DateTime startedAt;
  CircleAnnotation circleAnnotation;

  GeoPoint interpolatedAt(DateTime now) {
    final elapsedMs = now.difference(startedAt).inMilliseconds;
    final t = (elapsedMs / 2800.0).clamp(0.0, 1.0);
    return GeoPoint(
      lat: lerpDouble(from.lat, to.lat, t) ?? to.lat,
      lng: lerpDouble(from.lng, to.lng, t) ?? to.lng,
    );
  }
}

/// Mapa en tiempo real de TaxiYa Pasajeros con interpolación suave y selector de origen/destino.
class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({
    super.key,
    required this.profile,
  });

  final Profile profile;

  @override
  ConsumerState<PassengerHomeScreen> createState() =>
      _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _driverCircleManager;
  CircleAnnotationManager? _routeCircleManager;
  PointAnnotationManager? _landmarkLabelManager;

  final Map<String, _InterpolatedDriverState> _animatedDrivers =
      <String, _InterpolatedDriverState>{};
  final Map<String, OnlineDriverView> _driverByAnnotationId =
      <String, OnlineDriverView>{};

  Timer? _interpolationTimer;
  Timer? _staleCheckTimer;
  Timer? _scheduledWatchTimer;
  bool? _lastDarkStyle;

  SelectedRoutePlace? _origin;
  SelectedRoutePlace? _destination;
  bool? _pickingMapPinForOrigin; // true = origen, false = destino, null = off
  GeoPoint? _cameraFocus;

  final TaxiyaSoundService _sound = TaxiyaSoundService();
  bool _isRoundTrip = false;
  int _waitMinutes = 10;
  DateTime? _scheduledFor;
  bool _submittingTrip = false;

  DriverPublicSummary? _assignedDriverSummary;
  String? _loadedDriverIdForSummary;
  String? _notifiedAcceptedTripId;
  String? _notifiedInDoorTripId;
  String? _notifiedScheduledTripId;
  final Set<String> _handledTerminalTripIds = <String>{};

  @override
  void initState() {
    super.initState();
    _interpolationTimer = Timer.periodic(
      const Duration(milliseconds: 60),
      (_) => _tickAnimations(),
    );
    _staleCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshDriverColorsForStaleState(),
    );
    _scheduledWatchTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkScheduledDispatchWindow(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_mapboxMap != null && _lastDarkStyle != isDark) {
      _lastDarkStyle = isDark;
      unawaited(
        _mapboxMap!.loadStyleURI(
          isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
        ),
      );
    }
  }

  @override
  void dispose() {
    _interpolationTimer?.cancel();
    _staleCheckTimer?.cancel();
    _scheduledWatchTimer?.cancel();
    unawaited(_sound.dispose());
    super.dispose();
  }

  Locality? _currentLocality() {
    final localities = ref.read(localitiesProvider).value ?? const <Locality>[];
    for (final l in localities) {
      if (l.id == widget.profile.localityId) return l;
    }
    return localities.firstOrNull;
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    _lastDarkStyle = Theme.of(context).brightness == Brightness.dark;

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

    _driverCircleManager = await map.annotations.createCircleAnnotationManager();
    _routeCircleManager = await map.annotations.createCircleAnnotationManager();
    _landmarkLabelManager = await map.annotations.createPointAnnotationManager();

    _driverCircleManager?.tapEvents(
      onTap: (CircleAnnotation ann) {
        final driver = _driverByAnnotationId[ann.id];
        if (driver != null && mounted) {
          _showDriverDetailsSheet(driver);
        }
      },
    );

    map.addInteraction(
      TapInteraction.onMap((MapContentGestureContext ctx) {
        final modeIsOrigin = _pickingMapPinForOrigin;
        if (modeIsOrigin == null) return;
        final coords = ctx.point.coordinates;
        final pickedPoint = GeoPoint(
          lat: coords.lat.toDouble(),
          lng: coords.lng.toDouble(),
        );
        _onMapPinPlaced(isOrigin: modeIsOrigin, point: pickedPoint);
      }),
    );

    final latestDrivers =
        ref.read(onlineDriversStreamProvider).value ?? const <OnlineDriverView>[];
    unawaited(_syncDriverMarkers(latestDrivers));

    final landmarks =
        ref.read(passengerLandmarksProvider).value ?? const <Landmark>[];
    unawaited(_syncLandmarkMarkers(landmarks));
  }

  Future<void> _onMapPinPlaced({
    required bool isOrigin,
    required GeoPoint point,
  }) async {
    final place = SelectedRoutePlace(
      label: isOrigin
          ? 'Pin en mapa (${point.lat.toStringAsFixed(4)}, ${point.lng.toStringAsFixed(4)})'
          : 'Destino en mapa (${point.lat.toStringAsFixed(4)}, ${point.lng.toStringAsFixed(4)})',
      point: point,
      sourceType: 'pin',
    );
    setState(() {
      if (isOrigin) {
        _origin = place;
      } else {
        _destination = place;
      }
      _cameraFocus = point;
      _pickingMapPinForOrigin = null;
    });
    await _syncRouteMarkers();
  }

  Future<void> _syncDriverMarkers(List<OnlineDriverView> drivers) async {
    final manager = _driverCircleManager;
    if (manager == null) return;

    final now = DateTime.now();
    final incomingIds = drivers.map((OnlineDriverView d) => d.details.userId).toSet();

    // Eliminar marcadores de choferes que salieron de línea.
    final toRemove = _animatedDrivers.keys
        .where((String uid) => !incomingIds.contains(uid))
        .toList();
    for (final uid in toRemove) {
      final state = _animatedDrivers.remove(uid);
      if (state != null) {
        _driverByAnnotationId.remove(state.circleAnnotation.id);
        await manager.delete(state.circleAnnotation);
      }
    }

    for (final driver in drivers) {
      final point = driver.location;
      if (point == null) continue;

      final colorArgb = _markerColorFor(driver).toARGB32();
      final strokeColorArgb = const Color(0xFFFFFFFF).toARGB32();
      final existing = _animatedDrivers[driver.details.userId];

      if (existing == null) {
        final created = await manager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(point.lng, point.lat)),
            circleRadius: 11.0,
            circleColor: colorArgb,
            circleStrokeWidth: 2.5,
            circleStrokeColor: strokeColorArgb,
            circleOpacity: driver.isGpsStale ? 0.72 : 1.0,
          ),
        );
        _animatedDrivers[driver.details.userId] = _InterpolatedDriverState(
          driver: driver,
          from: point,
          to: point,
          startedAt: now,
          circleAnnotation: created,
        );
        _driverByAnnotationId[created.id] = driver;
      } else {
        final currentPos = existing.interpolatedAt(now);
        existing.from = currentPos;
        existing.to = point;
        existing.startedAt = now;
        existing.driver = driver;
        existing.circleAnnotation.circleColor = colorArgb;
        existing.circleAnnotation.circleOpacity =
            driver.isGpsStale ? 0.72 : 1.0;
        _driverByAnnotationId[existing.circleAnnotation.id] = driver;
      }
    }
  }

  Future<void> _tickAnimations() async {
    final manager = _driverCircleManager;
    if (manager == null || _animatedDrivers.isEmpty) return;

    final now = DateTime.now();
    for (final state in _animatedDrivers.values) {
      final elapsed = now.difference(state.startedAt).inMilliseconds;
      if (elapsed <= 3000 && state.from != state.to) {
        final next = state.interpolatedAt(now);
        state.circleAnnotation.geometry = Point(
          coordinates: Position(next.lng, next.lat),
        );
        await manager.update(state.circleAnnotation);
      }
    }
  }

  Future<void> _refreshDriverColorsForStaleState() async {
    final manager = _driverCircleManager;
    if (manager == null || _animatedDrivers.isEmpty) return;
    for (final state in _animatedDrivers.values) {
      final expectedColor = _markerColorFor(state.driver).toARGB32();
      final expectedOpacity = state.driver.isGpsStale ? 0.72 : 1.0;
      if (state.circleAnnotation.circleColor != expectedColor ||
          state.circleAnnotation.circleOpacity != expectedOpacity) {
        state.circleAnnotation.circleColor = expectedColor;
        state.circleAnnotation.circleOpacity = expectedOpacity;
        await manager.update(state.circleAnnotation);
      }
    }
  }

  Color _markerColorFor(OnlineDriverView driver) {
    if (driver.isGpsStale) {
      return const Color(0xFF94A3B8); // Gris si pasaron > 15 segundos
    }
    if (driver.isPrivateCompany) {
      return _parseHexColor(driver.company!.badgeColor);
    }
    return TaxiyaColors.lightPrimary; // Independiente
  }

  Future<void> _syncLandmarkMarkers(List<Landmark> landmarks) async {
    final manager = _landmarkLabelManager;
    if (manager == null) return;
    await manager.deleteAll();

    for (final l in landmarks) {
      final loc = l.location;
      if (loc == null) continue;
      if (!l.isPublic && l.createdBy != widget.profile.id) continue;
      if (l.isPublic && l.status != 'approved') continue;

      await manager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(loc.lng, loc.lat)),
          textField: l.name,
          textSize: 11.5,
          textColor: (l.isPublic
                  ? TaxiyaColors.lightSecondary
                  : TaxiyaColors.lightSuccess)
              .toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 1.5,
        ),
      );
    }
  }

  Future<void> _syncRouteMarkers() async {
    final manager = _routeCircleManager;
    if (manager == null) return;
    await manager.deleteAll();

    if (_origin != null) {
      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(_origin!.point.lng, _origin!.point.lat),
          ),
          circleRadius: 10,
          circleColor: TaxiyaColors.lightSuccess.toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3,
        ),
      );
    }

    if (_destination != null) {
      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _destination!.point.lng,
              _destination!.point.lat,
            ),
          ),
          circleRadius: 10,
          circleColor: TaxiyaColors.lightError.toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3,
        ),
      );
    }
  }

  Future<void> _openPlacePicker({required bool isOrigin}) async {
    final locality = _currentLocality();
    final res = await showModalBottomSheet<PlacePickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlacePickerSheet(
        isOrigin: isOrigin,
        profile: widget.profile,
        locality: locality,
        currentMapCenter: _cameraFocus ?? _origin?.point ?? locality?.center,
      ),
    );
    if (!mounted || res == null) return;

    if (res.requestMapPin) {
      setState(() => _pickingMapPinForOrigin = isOrigin);
      return;
    }

    final chosen = res.selectedPlace;
    if (chosen != null) {
      setState(() {
        if (isOrigin) {
          _origin = chosen;
        } else {
          _destination = chosen;
        }
        _cameraFocus = chosen.point;
      });
      await _syncRouteMarkers();
      await _flyTo(chosen.point, zoom: 15.6);
    }
  }

  Future<void> _flyTo(GeoPoint target, {double zoom = 15.0}) async {
    final map = _mapboxMap;
    if (map == null) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(target.lng, target.lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _centerOnPassengerGps() async {
    final res = await PassengerLocationService.getCurrentFix();
    if (!mounted) return;
    if (res.fix != null) {
      await _flyTo(res.fix!.point, zoom: 15.5);
    } else {
      final center = _currentLocality()?.center ?? CatamarcaDefaults.belen;
      await _flyTo(center, zoom: 14.2);
      if (mounted && res.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage!)),
        );
      }
    }
  }

  void _showDriverDetailsSheet(OnlineDriverView driver) {
    final d = driver.details;
    final colors = context.taxiyaColors;
    final isStale = driver.isGpsStale;

    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TaxiyaAvatar(
                      avatarUrl: driver.avatarUrl,
                      fullName: driver.driverName,
                      radius: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.displayTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            driver.company?.name ?? 'Taxista independiente',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: driver.isPrivateCompany
                                  ? _parseHexColor(driver.company!.badgeColor)
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isStale) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Última ubicación conocida (${TaxiyaDateUtils.secondsSinceLabel(d.lastLocationAt)})',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Vehículo: ${d.carBrand ?? ''} ${d.carModel ?? ''} (${d.carColor ?? 'Sin color'}) · ${d.carType ?? ''}'
                      .trim(),
                ),
                if (d.showPlatePublic && (d.plateNumber?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Patente: ${d.plateNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                if (d.showPermitPublic && d.permitExpiryDate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Habilitación vigente hasta: ${TaxiyaDateUtils.formatDateAr(d.permitExpiryDate)}',
                  ),
                ],
                if (d.carPhotoUrl != null && d.carPhotoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      d.carPhotoUrl!,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _parseHexColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return TaxiyaColors.lightSecondary;
    return Color(clean.length <= 6 ? (0xFF000000 | value) : value);
  }

  void _checkScheduledDispatchWindow() {
    final trip = ref.read(activePassengerTripProvider).value;
    if (trip == null || trip.scheduledFor == null || !trip.status.isSearching) {
      return;
    }
    if (!trip.isScheduledStillDormant() &&
        _notifiedScheduledTripId != trip.id) {
      _notifiedScheduledTripId = trip.id;
      if (ref.read(hiveCacheProvider).notifyTrips) {
        unawaited(_sound.playChime());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu reserva programada está por empezar: buscando un taxi cercano.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAssignedDriverSummary(String driverId) async {
    _loadedDriverIdForSummary = driverId;
    try {
      final summary = await ref
          .read(taxiyaRepositoryProvider)
          .fetchDriverAssignedSummary(driverId);
      if (!mounted) return;
      setState(() => _assignedDriverSummary = summary);
      final trip = ref.read(activePassengerTripProvider).value;
      if (trip != null && summary?.currentLocation != null) {
        _evaluateProximity(trip, summary!.currentLocation!);
      }
    } catch (_) {}
  }

  void _evaluateProximity(Trip trip, GeoPoint driverPoint) {
    if (trip.originPoint == null) return;
    if (trip.status != TripStatus.accepted &&
        trip.status != TripStatus.arriving) {
      return;
    }
    final dist = haversineDistanceMeters(
      trip.originPoint!.lat,
      trip.originPoint!.lng,
      driverPoint.lat,
      driverPoint.lng,
    );
    if (dist <= 100.0 && _notifiedInDoorTripId != trip.id) {
      _notifiedInDoorTripId = trip.id;
      if (ref.read(hiveCacheProvider).notifyTrips) {
        unawaited(_sound.playChime());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'El taxi está a menos de 100 metros. Ya podés salir a la puerta.',
            ),
          ),
        );
      }
    }
  }

  void _checkDriverProximityToOrigin(
    Trip? trip,
    List<OnlineDriverView> drivers,
  ) {
    if (trip == null || trip.driverId == null) return;
    for (final d in drivers) {
      if (d.details.userId == trip.driverId && d.location != null) {
        _evaluateProximity(trip, d.location!);
        break;
      }
    }
  }

  Future<void> _handleTripChange(Trip? prev, Trip? next) async {
    if (next == null) {
      if (mounted && _assignedDriverSummary != null) {
        setState(() {
          _assignedDriverSummary = null;
          _loadedDriverIdForSummary = null;
        });
      }
      return;
    }

    if (next.driverId != null &&
        next.driverId != _loadedDriverIdForSummary &&
        !next.status.isTerminal) {
      unawaited(_loadAssignedDriverSummary(next.driverId!));
    }

    if (next.status == TripStatus.accepted &&
        prev?.status != TripStatus.accepted &&
        _notifiedAcceptedTripId != next.id) {
      _notifiedAcceptedTripId = next.id;
      if (ref.read(hiveCacheProvider).notifyTrips) {
        unawaited(_sound.playChime());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Taxi asignado. Ya podés ver el vehículo y chatear.'),
          ),
        );
      }
    }

    if (next.status == TripStatus.inDoor &&
        prev?.status != TripStatus.inDoor &&
        _notifiedInDoorTripId != next.id) {
      _notifiedInDoorTripId = next.id;
      if (ref.read(hiveCacheProvider).notifyTrips) {
        unawaited(_sound.playChime());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text('El taxi está en la puerta.'),
          ),
        );
      }
    }

    if (next.status == TripStatus.completed &&
        !_handledTerminalTripIds.contains(next.id)) {
      _handledTerminalTripIds.add(next.id);
      ref.invalidate(lastCompletedTripProvider);

      if (next.isRoundTrip &&
          (next.waitMinutes ?? 0) > 10 &&
          next.cancelReason == 'driver_released_wait') {
        await ref.read(pendingReturnTripProvider.notifier).setPending(next);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 6),
              content: Text(
                'El móvil liberó el turno por espera larga. Tocá "Ya estoy listo para volver" cuando regreses.',
              ),
            ),
          );
        }
      }

      final completedAt = next.completedAt?.toLocal();
      final isRecent =
          completedAt == null ||
          DateTime.now().difference(completedAt).inMinutes < 45;
      final driverSummaryName = _assignedDriverSummary?.displayName;
      if (mounted) {
        setState(() {
          _assignedDriverSummary = null;
          _loadedDriverIdForSummary = null;
        });
      }
      if (isRecent && next.driverId != null) {
        try {
          final repo = ref.read(taxiyaRepositoryProvider);
          final existingRating = await repo.fetchRatingForTrip(next.id);
          if (existingRating == null && mounted) {
            await showPassengerRatingModal(
              context: context,
              repo: repo,
              trip: next,
              driverName: driverSummaryName,
            );
          }
        } catch (_) {}
      }
    }

    if (next.status == TripStatus.cancelled &&
        !_handledTerminalTripIds.contains(next.id)) {
      _handledTerminalTripIds.add(next.id);
      if (mounted) {
        setState(() {
          _assignedDriverSummary = null;
          _loadedDriverIdForSummary = null;
        });
        if (prev != null && !prev.status.isTerminal) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El viaje fue cancelado.')),
          );
        }
      }
    }
  }

  Future<void> _pickScheduledDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      helpText: 'Elegí el día de tu viaje',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 45))),
      helpText: 'Elegí la hora de salida',
    );
    if (time == null || !mounted) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isBefore(now.add(const Duration(minutes: 10)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para reservar, elegí un horario con al menos 10 minutos de anticipación.',
          ),
        ),
      );
      return;
    }
    setState(() => _scheduledFor = picked);
  }

  Future<void> _requestTrip({Trip? repeatTemplate}) async {
    if (_submittingTrip) return;
    final localityId = widget.profile.localityId ?? _currentLocality()?.id;
    if (localityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí tu localidad en Configuración.')),
      );
      return;
    }

    var originAddress = repeatTemplate?.originAddress ?? _origin?.label;
    var originPoint = repeatTemplate?.originPoint ?? _origin?.point;
    final destAddress = repeatTemplate?.destAddress ?? _destination?.label;
    final destPoint = repeatTemplate?.destPoint ?? _destination?.point;

    if (originPoint == null) {
      final fixRes = await PassengerLocationService.getCurrentFix();
      if (!mounted) return;
      if (fixRes.fix == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fixRes.errorMessage ??
                  'Marcá tu punto de salida antes de pedir el taxi.',
            ),
          ),
        );
        return;
      }
      final fix = fixRes.fix!;
      if (fix.needsAccuracyConfirmation) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Confirmá tu ubicación'),
            content: Text(
              'El GPS tiene un margen de ${fix.accuracyMeters.round()} m. ¿Querés pedir el taxi en esta ubicación igual?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Ajustar en el mapa'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Pedir aquí'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (ok != true) {
          setState(() => _pickingMapPinForOrigin = true);
          return;
        }
      }
      originPoint = fix.point;
      originAddress = 'Mi ubicación actual';
      setState(() {
        _origin = SelectedRoutePlace(
          label: originAddress!,
          point: originPoint!,
          sourceType: 'gps',
        );
      });
      await _syncRouteMarkers();
    }

    setState(() => _submittingTrip = true);
    try {
      await ref.read(taxiyaRepositoryProvider).createTrip(
        passengerId: widget.profile.id,
        localityId: localityId,
        originAddress: originAddress ?? 'Mi ubicación actual',
        originPoint: originPoint,
        destAddress: destAddress,
        destPoint: destPoint,
        isRoundTrip: repeatTemplate?.isRoundTrip ?? _isRoundTrip,
        waitMinutes: (repeatTemplate?.isRoundTrip ?? _isRoundTrip)
            ? (repeatTemplate?.waitMinutes ?? _waitMinutes)
            : null,
        scheduledFor: repeatTemplate == null ? _scheduledFor : null,
      );
      if (mounted) {
        setState(() => _scheduledFor = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido enviado. Buscando un taxi habilitado.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos enviar tu pedido. Revisá tu conexión e intentá de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingTrip = false);
    }
  }

  Future<void> _requestPriorityReturnTrip(Trip baseTrip) async {
    if (_submittingTrip) return;
    setState(() => _submittingTrip = true);
    try {
      final fix = await PassengerLocationService.getCurrentFix();
      final created = await ref
          .read(taxiyaRepositoryProvider)
          .createPriorityReturnTrip(
            passengerId: widget.profile.id,
            previousTrip: baseTrip,
            currentOriginPoint: fix.fix?.point,
          );
      await ref.read(pendingReturnTripProvider.notifier).setPending(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Regreso prioritario pedido desde ${created.originAddress ?? 'tu punto actual'}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos pedir el regreso ahora. Revisá tu conexión.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingTrip = false);
    }
  }

  Future<void> _cancelActiveTrip(Trip trip) async {
    final reason = await showPassengerCancelReasonDialog(context);
    if (reason == null || !mounted) return;
    try {
      await ref.read(taxiyaRepositoryProvider).updateTripStatus(
        tripId: trip.id,
        nextStatus: TripStatus.cancelled,
        cancelReason: reason,
        cancelledBy: widget.profile.id,
        queueOffline: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancelaste el viaje.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos cancelar sin señal. Probá de nuevo en unos segundos.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handlePanic(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Activar botón de pánico'),
        content: const Text(
          'Enviaremos una alerta prioritaria al centro operativo de TaxiYa con tu ubicación y los datos de este viaje.',
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
    if (confirm != true || !mounted) return;

    final fix = await PassengerLocationService.getCurrentFix();
    final point =
        fix.fix?.point ?? trip.originPoint ?? _currentLocality()?.center;
    final coordsText = point != null
        ? '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)} · https://maps.google.com/?q=${point.lat},${point.lng}'
        : 'Sin coordenadas GPS';
    final name = widget.profile.fullName?.trim().isNotEmpty == true
        ? widget.profile.fullName!
        : widget.profile.id;

    try {
      await ref.read(taxiyaRepositoryProvider).createSupportTicket(
        userId: widget.profile.id,
        tripId: trip.id,
        localityId: trip.localityId ?? widget.profile.localityId,
        category: 'Emergencia en viaje',
        description:
            'EMERGENCIA EN VIAJE — Pasajero: $name. Móvil: ${_assignedDriverSummary?.displayName ?? trip.driverId ?? 'N/D'}. GPS: $coordsText',
        isEmergency: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'Alerta de emergencia enviada. El equipo de TaxiYa ya la recibió.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos enviar la alerta sin conexión. Llamá al 911 si corrés peligro.',
            ),
          ),
        );
      }
    }
  }

  void _showCarPhotoPreview(String url) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No pudimos cargar la foto del vehículo.'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<OnlineDriverView>>>(
      onlineDriversStreamProvider,
      (AsyncValue<List<OnlineDriverView>>? prev,
          AsyncValue<List<OnlineDriverView>> next) {
        final items = next.value;
        if (items != null) {
          unawaited(_syncDriverMarkers(items));
          _checkDriverProximityToOrigin(
            ref.read(activePassengerTripProvider).value,
            items,
          );
        }
      },
    );

    ref.listen<AsyncValue<Trip?>>(
      activePassengerTripProvider,
      (AsyncValue<Trip?>? prev, AsyncValue<Trip?> next) {
        if (next.hasValue) {
          unawaited(_handleTripChange(prev?.value, next.value));
        }
      },
    );

    ref.listen<AsyncValue<List<Landmark>>>(
      passengerLandmarksProvider,
      (AsyncValue<List<Landmark>>? prev, AsyncValue<List<Landmark>> next) {
        final items = next.value;
        if (items != null) {
          unawaited(_syncLandmarkMarkers(items));
        }
      },
    );

    final driversAsync = ref.watch(onlineDriversStreamProvider);
    final drivers = driversAsync.value ?? const <OnlineDriverView>[];
    final activeTrip = ref.watch(activePassengerTripProvider).value;
    final hasActiveTrip = activeTrip != null && !activeTrip.status.isTerminal;
    final lastCompletedTrip = ref.watch(lastCompletedTripProvider).value;
    final pendingReturnBase = ref.watch(pendingReturnTripProvider);
    final locality = _currentLocality();
    final center = locality?.center ?? CatamarcaDefaults.belen;
    final colors = context.taxiyaColors;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    'TaxiYa · ${locality?.name ?? 'Catamarca'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${drivers.length} taxis disponibles ahora',
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
            tooltip: 'Ayuda y guía de uso',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              openPassengerHelpScreen(
                context: context,
                profile: widget.profile,
                localityName: locality?.name ?? 'Catamarca',
                activeTripId: hasActiveTrip ? activeTrip.id : null,
              );
            },
          ),
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PassengerSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: ValueKey<String>(locality?.id ?? widget.profile.id),
            styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
            viewport: CameraViewportState(
              center: Point(coordinates: Position(center.lng, center.lat)),
              zoom: 14.3,
            ),
            onMapCreated: _onMapCreated,
          ),

          // Leyenda visual superior + modo Pin en Mapa
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pickingMapPinForOrigin != null)
                  Material(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: scheme.onPrimary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pickingMapPinForOrigin!
                                  ? 'Tocá el mapa para marcar tu punto de subida'
                                  : 'Tocá el mapa para marcar tu destino',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _pickingMapPinForOrigin = null);
                            },
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Material(
                    color: scheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _LegendDot(
                            color: scheme.secondary,
                            label: 'Empresa privada',
                          ),
                          _LegendDot(
                            color: scheme.primary,
                            label: 'Independiente',
                          ),
                          const _LegendDot(
                            color: Color(0xFF94A3B8),
                            label: 'Última ubicación conocida (>15 s)',
                          ),
                          if (isNightShift)
                            Text(
                              'Turno Nocturno (${TaxiyaDateUtils.nightShiftRangeLabel(context)})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.secondary,
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

          // Botones flotantes y tarjeta inferior (seguimiento de viaje o solicitud)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!hasActiveTrip && pendingReturnBase != null)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Material(
                                color: scheme.secondary,
                                borderRadius: BorderRadius.circular(28),
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: _submittingTrip
                                              ? null
                                              : () => _requestPriorityReturnTrip(
                                                    pendingReturnBase,
                                                  ),
                                          icon: Icon(
                                            Icons.keyboard_return_rounded,
                                            color: scheme.onSecondary,
                                          ),
                                          label: Text(
                                            'Ya estoy listo para volver',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: scheme.onSecondary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Ocultar regreso',
                                        onPressed: () {
                                          ref
                                              .read(
                                                pendingReturnTripProvider
                                                    .notifier,
                                              )
                                              .setPending(null);
                                        },
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: scheme.onSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        FloatingActionButton.small(
                          heroTag: 'passenger_recenter',
                          onPressed: _centerOnPassengerGps,
                          tooltip: 'Ir a mi ubicación',
                          child: const Icon(Icons.my_location_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (hasActiveTrip)
                      PassengerActiveTripCard(
                        trip: activeTrip,
                        driverSummary: _assignedDriverSummary,
                        onOpenChat: () {
                          showTaxiyaTripChatSheet(
                            context: context,
                            tripId: activeTrip.id,
                            currentUserId: widget.profile.id,
                            counterpartName:
                                _assignedDriverSummary?.displayName ??
                                'Tu chofer',
                            counterpartPhone: _assignedDriverSummary?.phone,
                            quickReplies: const <String>[
                              'Ya salgo',
                              'Estoy en la esquina',
                              'Voy con equipaje',
                              'Ya te veo',
                            ],
                          );
                        },
                        onShareWhatsApp: () async {
                          final ok = await TaxiyaExternalLauncher
                              .shareTripOnWhatsApp(
                                originAddress:
                                    activeTrip.originAddress ??
                                    'Punto marcado',
                                destinationAddress: activeTrip.destAddress,
                                driverName: _assignedDriverSummary?.displayName,
                                vehicleSummary:
                                    _assignedDriverSummary?.vehicleDescription,
                                plateLabel:
                                    _assignedDriverSummary?.visiblePlateLabel,
                                permitLabel:
                                    _assignedDriverSummary?.visiblePermitLabel,
                              );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No pudimos abrir WhatsApp para compartir.',
                                ),
                              ),
                            );
                          }
                        },
                        onPanic: () => _handlePanic(activeTrip),
                        onCancelTrip: () => _cancelActiveTrip(activeTrip),
                        onInspectCarPhoto: _showCarPhotoPreview,
                      )
                    else
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (lastCompletedTrip != null) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _submittingTrip
                                      ? null
                                      : () => _requestTrip(
                                            repeatTemplate: lastCompletedTrip,
                                          ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: scheme.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.history_rounded,
                                          size: 18,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Repetir último viaje: ${lastCompletedTrip.originAddress ?? 'Origen'} → ${lastCompletedTrip.destAddress ?? 'Destino'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              _RouteFieldButton(
                                icon: Icons.trip_origin_rounded,
                                iconColor: colors.success,
                                caption: 'Origen (¿dónde subís?)',
                                value:
                                    _origin?.label ??
                                    'Elegí GPS, pin en mapa o lugar guardado',
                                onTap: () => _openPlacePicker(isOrigin: true),
                              ),
                              const SizedBox(height: 8),
                              _RouteFieldButton(
                                icon: Icons.place_rounded,
                                iconColor: colors.error,
                                caption: 'Destino (¿a dónde vas?)',
                                value:
                                    _destination?.label ??
                                    'Elegí punto público, personal o pin en mapa',
                                onTap: () => _openPlacePicker(isOrigin: false),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilterChip(
                                    selected: _isRoundTrip,
                                    label: const Text('Ida y vuelta'),
                                    avatar: const Icon(
                                      Icons.sync_alt_rounded,
                                      size: 16,
                                    ),
                                    onSelected: (bool sel) {
                                      setState(() => _isRoundTrip = sel);
                                    },
                                  ),
                                  ActionChip(
                                    avatar: Icon(
                                      _scheduledFor == null
                                          ? Icons.schedule_rounded
                                          : Icons.event_available_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _scheduledFor == null
                                          ? 'Programar horario'
                                          : TaxiyaDateUtils.formatDateTimeAr(
                                              context,
                                              _scheduledFor,
                                            ),
                                    ),
                                    onPressed: _pickScheduledDateTime,
                                  ),
                                  if (_scheduledFor != null)
                                    IconButton(
                                      tooltip: 'Quitar horario programado',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setState(() => _scheduledFor = null);
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                              if (_isRoundTrip) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: const <int>[5, 10, 15, 30].map((
                                    int mins,
                                  ) {
                                    return ChoiceChip(
                                      label: Text('$mins min'),
                                      selected: _waitMinutes == mins,
                                      onSelected: (_) {
                                        setState(() => _waitMinutes = mins);
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _waitMinutes <= 10
                                      ? 'El móvil te espera $_waitMinutes minutos para emprender la vuelta.'
                                      : 'Si la espera supera los 10 minutos, el chofer puede liberar el viaje y vos tendrás un botón de regreso prioritario.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _submittingTrip
                                      ? null
                                      : () => _requestTrip(),
                                  icon: _submittingTrip
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Icon(
                                          _scheduledFor != null
                                              ? Icons.event_available_rounded
                                              : Icons.local_taxi_rounded,
                                        ),
                                  label: Text(
                                    _scheduledFor != null
                                        ? 'Reservar taxi'
                                        : 'Pedir taxi ahora',
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RouteFieldButton extends StatelessWidget {
  const _RouteFieldButton({
    required this.icon,
    required this.iconColor,
    required this.caption,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String caption;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
