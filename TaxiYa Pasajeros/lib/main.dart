import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

import 'src/passenger_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeTaxiyaCore();
  if (TaxiyaEnv.mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(TaxiyaEnv.mapboxAccessToken);
  }

  runApp(const ProviderScope(child: PassengerApp()));
}
