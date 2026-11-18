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

/// Último viaje registrado del pasajero en tiempo real.
final activePassengerTripProvider = StreamProvider.autoDispose<Trip?>((Ref ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return Stream<Trip?>.value(null);
  return ref.watch(taxiyaRepositoryProvider).watchLatestPassengerTrip(profile.id);
});

/// Último viaje completado del pasajero para "Repetir último viaje".
final lastCompletedTripProvider = FutureProvider.autoDispose<Trip?>((Ref ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return null;
  return ref
      .watch(taxiyaRepositoryProvider)
      .fetchLastCompletedPassengerTrip(profile.id);
});

/// Base del viaje de ida y vuelta liberado (>10 min) esperando botón "Ya estoy listo para volver".
class PendingReturnTripNotifier extends Notifier<Trip?> {
  @override
  Trip? build() {
    return ref.watch(hiveCacheProvider).loadPendingReturnBaseTrip();
  }

  Future<void> setPending(Trip? trip) async {
    state = trip;
    await ref.read(hiveCacheProvider).savePendingReturnBaseTrip(trip);
  }
}

final pendingReturnTripProvider =
    NotifierProvider<PendingReturnTripNotifier, Trip?>(
      PendingReturnTripNotifier.new,
    );
