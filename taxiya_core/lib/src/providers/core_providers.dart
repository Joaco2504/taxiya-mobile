import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/taxiya_models.dart';
import '../repositories/taxiya_repository.dart';
import '../services/hive_cache_service.dart';
import '../theme/taxiya_theme.dart';

/// Proveedor del servicio de caché offline con Hive.
final hiveCacheProvider = Provider<HiveCacheService>((Ref ref) {
  return const HiveCacheService();
});

/// Proveedor del cliente Supabase ya configurado en el esquema `taxiya`.
final supabaseClientProvider = Provider<SupabaseClient>((Ref ref) {
  return Supabase.instance.client;
});

/// Proveedor del repositorio principal de TaxiYa.
final taxiyaRepositoryProvider = Provider<TaxiyaRepository>((Ref ref) {
  return TaxiyaRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(hiveCacheProvider),
  );
});

/// Emite el usuario autenticado en tiempo real cada vez que cambia la sesión.
final authStateStreamProvider = StreamProvider<User?>((Ref ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentUser;
  await for (final authState in client.auth.onAuthStateChange) {
    yield authState.session?.user ?? client.auth.currentUser;
  }
});

/// Flujo en tiempo real del perfil del usuario actual en `taxiya.profiles`.
final currentProfileProvider = StreamProvider<Profile?>((Ref ref) {
  final userAsync = ref.watch(authStateStreamProvider);
  final user = userAsync.value;
  if (user == null) {
    return Stream<Profile?>.value(null);
  }
  final repo = ref.watch(taxiyaRepositoryProvider);
  return repo.watchProfile(user.id);
});

/// Localidades activas (Belén, Andalgalá) con fallback a Hive si no hay señal.
final localitiesProvider = FutureProvider<List<Locality>>((Ref ref) {
  return ref.watch(taxiyaRepositoryProvider).fetchLocalities();
});

/// Empresas de taxi activas registradas en `taxiya.taxi_companies`.
final taxiCompaniesProvider = FutureProvider<List<TaxiCompany>>((Ref ref) {
  return ref.watch(taxiyaRepositoryProvider).fetchCompanies();
});

/// Notifier del tema seleccionado (Claro, Oscuro o Sistema), persistido en Hive.
class TaxiyaThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final cache = ref.watch(hiveCacheProvider);
    return TaxiyaTheme.themeModeFromString(cache.themeMode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final cache = ref.read(hiveCacheProvider);
    await cache.setThemeMode(TaxiyaTheme.themeModeToString(mode));

    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        await ref.read(taxiyaRepositoryProvider).updateProfileFields(
          user.id,
          <String, dynamic>{'theme_mode': TaxiyaTheme.themeModeToString(mode)},
        );
      } catch (_) {
        // Si no hay señal 4G en ese instante, queda guardado localmente en Hive.
      }
    }
  }
}

final themeModeProvider = NotifierProvider<TaxiyaThemeModeNotifier, ThemeMode>(
  TaxiyaThemeModeNotifier.new,
);
