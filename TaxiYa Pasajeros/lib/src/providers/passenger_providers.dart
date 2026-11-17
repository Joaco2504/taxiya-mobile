import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Punto elegido como origen o destino en la app de pasajeros.
@immutable
class SelectedRoutePlace {
  const SelectedRoutePlace({
    required this.label,
    required this.point,
    required this.sourceType,
    this.landmarkId,
    this.accuracyMeters,
  });

  final String label;
  final GeoPoint point;
  final String sourceType; // 'pin', 'personal', 'public'
  final String? landmarkId;
  final double? accuracyMeters;
}

/// Flujo en tiempo real de taxis en línea en la localidad del pasajero.
final onlineDriversStreamProvider =
    StreamProvider.autoDispose<List<OnlineDriverView>>((Ref ref) {
      final profile = ref.watch(currentProfileProvider).value;
      final localities =
          ref.watch(localitiesProvider).value ?? const <Locality>[];
      final companies =
          ref.watch(taxiCompaniesProvider).value ?? const <TaxiCompany>[];

      final localityId =
          profile?.localityId ?? localities.firstOrNull?.id;
      if (localityId == null) {
        return Stream<List<OnlineDriverView>>.value(const <OnlineDriverView>[]);
      }

      Locality? matchedLocality;
      for (final l in localities) {
        if (l.id == localityId) {
          matchedLocality = l;
          break;
        }
      }

      return ref.watch(taxiyaRepositoryProvider).watchOnlineDrivers(
        localityId: localityId,
        locality: matchedLocality,
        companies: companies,
      );
    });

/// Puntos de referencia públicos aprobados y destinos privados del pasajero.
final passengerLandmarksProvider = FutureProvider<List<Landmark>>((Ref ref) {
  final profile = ref.watch(currentProfileProvider).value;
  final localities = ref.watch(localitiesProvider).value ?? const <Locality>[];
  final localityId = profile?.localityId ?? localities.firstOrNull?.id;
  if (localityId == null) return const <Landmark>[];

  return ref.watch(taxiyaRepositoryProvider).fetchLandmarks(
    localityId: localityId,
    userId: profile?.id,
  );
});
