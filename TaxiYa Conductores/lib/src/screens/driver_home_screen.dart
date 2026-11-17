import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

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
  Timer? _foregroundGpsTimer;
  Timer? _clockRefreshTimer;
  bool _togglingStatus = false;
  bool _gpsSyncError = false;
  bool? _lastAppliedDarkStyle;
  GeoPoint? _latestGps;
  DateTime? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _latestGps = widget.details.currentLocation;
    _lastSyncAt = widget.details.lastLocationAt;
    if (widget.details.isOnline) {
      _startGpsLoop();
    }
    _clockRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DriverHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.details.isOnline && widget.details.isOnline) {
      _startGpsLoop();
    } else if (oldWidget.details.isOnline && !widget.details.isOnline) {
      _stopGpsLoop();
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

    try {
      await repo.pushDriverLocation(
        userId: widget.profile.id,
        point: point,
      );
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
        _latestGps = point;
        _lastSyncAt = DateTime.now();
        _startGpsLoop();
        await _centerMapOn(point);
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

  Future<void> _centerMapOn(GeoPoint target) async {
    final map = _mapboxMap;
    if (map == null) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(target.lng, target.lat)),
        zoom: 15.2,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _recenterOnDriver() async {
    final perm = await DriverLocationController.ensurePermissions();
    if (!perm.granted) {
      await _centerMapOn(_latestGps ?? _localityCenter());
      return;
    }
    final point =
        await DriverLocationController.getCurrentGeoPoint() ??
        _latestGps ??
        _localityCenter();
    await _centerMapOn(point);
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    _lastAppliedDarkStyle = Theme.of(context).brightness == Brightness.dark;
    unawaited(
      map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locality = _currentLocality();
    final company = _currentCompany();
    final isOnline = widget.details.isOnline;
    final initialCenter =
        _latestGps ?? locality?.center ?? CatamarcaDefaults.belen;

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
                coordinates: Position(initialCenter.lng, initialCenter.lat),
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

          // Botón de centrar cámara
          Positioned(
            right: 16,
            bottom: 224,
            child: FloatingActionButton.small(
              heroTag: 'driver_recenter',
              onPressed: _recenterOnDriver,
              tooltip: 'Centrar en mi ubicación',
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // Panel inferior grande y claro para operar con una mano
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Card(
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          onPressed: _togglingStatus ? null : _toggleOnline,
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
