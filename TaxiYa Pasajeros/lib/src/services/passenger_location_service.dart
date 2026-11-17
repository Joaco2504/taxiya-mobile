import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taxiya_core/taxiya_core.dart';

@immutable
class PassengerGpsFix {
  const PassengerGpsFix({
    required this.point,
    required this.accuracyMeters,
  });

  final GeoPoint point;
  final double accuracyMeters;

  bool get needsAccuracyConfirmation => accuracyMeters > 20.0;
}

@immutable
class PassengerGpsResult {
  const PassengerGpsResult({
    this.fix,
    this.errorMessage,
  });

  final PassengerGpsFix? fix;
  final String? errorMessage;
}

/// Obtiene permisos y coordenadas GPS del pasajero informando la precisión en metros.
abstract final class PassengerLocationService {
  static Future<PassengerGpsResult> getCurrentFix() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return const PassengerGpsResult(
        errorMessage:
            'Tenés el GPS apagado. Activalo para ubicar tu punto de partida.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const PassengerGpsResult(
        errorMessage:
            'Necesitamos permiso de ubicación para fijar tu punto en el mapa.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const PassengerGpsResult(
        errorMessage:
            'El permiso de ubicación está bloqueado. Habilitalo desde Configuración.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return PassengerGpsResult(
        fix: PassengerGpsFix(
          point: GeoPoint(lat: pos.latitude, lng: pos.longitude),
          accuracyMeters: pos.accuracy,
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return PassengerGpsResult(
          fix: PassengerGpsFix(
            point: GeoPoint(lat: last.latitude, lng: last.longitude),
            accuracyMeters: last.accuracy > 0 ? last.accuracy : 50.0,
          ),
        );
      }
      return const PassengerGpsResult(
        errorMessage:
            'No pudimos obtener tu ubicación ahora. Probá tocando el pin directo en el mapa.',
      );
    }
  }
}
