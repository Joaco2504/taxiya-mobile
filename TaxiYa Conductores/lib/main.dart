import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

import 'src/driver_app.dart';
import 'src/services/driver_location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeTaxiyaCore();
  unawaited(TaxiyaAdRuntime.ensureInitialized());
  if (TaxiyaEnv.mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(TaxiyaEnv.mapboxAccessToken);
  }
  await configureDriverBackgroundService();

  runApp(const ProviderScope(child: DriverApp()));
}
