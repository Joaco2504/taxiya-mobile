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
