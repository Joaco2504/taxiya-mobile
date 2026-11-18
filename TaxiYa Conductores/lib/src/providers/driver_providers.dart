import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Flujo en tiempo real del legajo `taxiya.driver_details` del chofer actual.
final driverDetailsProvider = StreamProvider<DriverDetails?>((Ref ref) {
  final userAsync = ref.watch(authStateStreamProvider);
  final user = userAsync.value;
  if (user == null) {
    return Stream<DriverDetails?>.value(null);
  }
  return ref.watch(taxiyaRepositoryProvider).watchDriverDetails(user.id);
});

/// Pedidos libres (`searching`) en la localidad del chofer cuando está en línea.
final searchingTripsProvider = StreamProvider.autoDispose<List<Trip>>((
  Ref ref,
) {
  final profile = ref.watch(currentProfileProvider).value;
  final details = ref.watch(driverDetailsProvider).value;
  final localities =
      ref.watch(localitiesProvider).value ?? const <Locality>[];
  final localityId = profile?.localityId ?? localities.firstOrNull?.id;

  if (profile == null ||
      details == null ||
      !details.isOnline ||
      localityId == null) {
    return Stream<List<Trip>>.value(const <Trip>[]);
  }
  return ref
      .watch(taxiyaRepositoryProvider)
      .watchSearchingTrips(localityId: localityId);
});

/// Viaje activo actualmente asignado al chofer.
final activeDriverTripProvider = StreamProvider.autoDispose<Trip?>((Ref ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return Stream<Trip?>.value(null);
  return ref.watch(taxiyaRepositoryProvider).watchActiveDriverTrip(profile.id);
});

/// Insignias activas del chofer en `taxiya.driver_badges`.
final driverBadgesProvider = FutureProvider.autoDispose<List<DriverBadge>>((
  Ref ref,
) {
  final user = ref.watch(authStateStreamProvider).value;
  if (user == null) return const <DriverBadge>[];
  return ref.watch(taxiyaRepositoryProvider).fetchDriverBadges(user.id);
});
