import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

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
  bool? _lastDarkStyle;

  SelectedRoutePlace? _origin;
  SelectedRoutePlace? _destination;
  bool? _pickingMapPinForOrigin; // true = origen, false = destino, null = off
  GeoPoint? _cameraFocus;

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

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        showAccuracyRing: true,
      ),
    );

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

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<OnlineDriverView>>>(
      onlineDriversStreamProvider,
      (AsyncValue<List<OnlineDriverView>>? prev,
          AsyncValue<List<OnlineDriverView>> next) {
        final items = next.value;
        if (items != null) {
          unawaited(_syncDriverMarkers(items));
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

          Positioned(
            right: 16,
            bottom: 215,
            child: FloatingActionButton.small(
              heroTag: 'passenger_recenter',
              onPressed: _centerOnPassengerGps,
              tooltip: 'Ir a mi ubicación',
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // Selector inferior de Origen y Destino
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RouteFieldButton(
                        icon: Icons.trip_origin_rounded,
                        iconColor: colors.success,
                        caption: 'Origen (¿dónde subís?)',
                        value:
                            _origin?.label ??
                            'Elegí GPS, pin en mapa o lugar guardado',
                        onTap: () => _openPlacePicker(isOrigin: true),
                      ),
                      const SizedBox(height: 10),
                      _RouteFieldButton(
                        icon: Icons.place_rounded,
                        iconColor: colors.error,
                        caption: 'Destino (¿a dónde vas?)',
                        value:
                            _destination?.label ??
                            'Elegí punto público, personal o pin en mapa',
                        onTap: () => _openPlacePicker(isOrigin: false),
                      ),
                    ],
                  ),
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
