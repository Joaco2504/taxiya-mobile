import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de entorno compartida para las apps móviles de TaxiYa.
///
/// Las variables sensibles/tokens externos (como `MAPBOX_ACCESS_TOKEN`) se
/// inyectan mediante `--dart-define-from-file=../env.local.json`.
abstract final class TaxiyaEnv {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jblsngzlpstojzwsdchb.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_9mDXxCLTTDXdZHuSK6V9hA_UANI0TIs',
  );
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  static const String schema = 'taxiya';
  static const String bucketPublic = 'taxiya_public';
  static const String bucketPrivate = 'taxiya_private';

  static const String hiveCoreBox = 'taxiya_core_cache';
  static const String hiveSettingsBox = 'taxiya_settings';
}

/// Inicializa Hive (persistencia offline) y Supabase apuntando al esquema `taxiya`.
Future<void> initializeTaxiyaCore() async {
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<dynamic>(TaxiyaEnv.hiveCoreBox),
    Hive.openBox<dynamic>(TaxiyaEnv.hiveSettingsBox),
  ]);

  await Supabase.initialize(
    url: TaxiyaEnv.supabaseUrl,
    publishableKey: TaxiyaEnv.supabaseAnonKey,
    postgrestOptions: const PostgrestClientOptions(schema: TaxiyaEnv.schema),
    realtimeLifecycleOptions: const RealtimeLifecycleOptions(
      disconnectAfterPause: Duration(minutes: 2),
    ),
  );
}
