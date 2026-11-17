import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

import 'screens/passenger_auth_screen.dart';
import 'screens/passenger_blocked_screen.dart';
import 'screens/passenger_home_screen.dart';

/// Aplicación principal de TaxiYa Pasajeros.
class PassengerApp extends ConsumerWidget {
  const PassengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'TaxiYa Pasajeros',
      debugShowCheckedModeBanner: false,
      theme: TaxiyaTheme.light,
      darkTheme: TaxiyaTheme.dark,
      themeMode: themeMode,
      home: const _PassengerRootGate(),
    );
  }
}

class _PassengerRootGate extends ConsumerWidget {
  const _PassengerRootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateStreamProvider);
    final user = authAsync.value;
    if (authAsync.isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user == null) {
      return const PassengerAuthScreen();
    }

    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;
    if (profileAsync.isLoading && profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile == null) {
      return _PassengerProfileSyncScreen(
        onRetry: () => ref.invalidate(currentProfileProvider),
        onSignOut: () async {
          await ref.read(supabaseClientProvider).auth.signOut();
          await ref.read(hiveCacheProvider).clearUserCache();
        },
      );
    }

    if (profile.accountStatus == TaxiyaAccountStatus.suspended ||
        profile.accountStatus == TaxiyaAccountStatus.revoked) {
      return PassengerBlockedScreen(profile: profile);
    }

    return PassengerHomeScreen(profile: profile);
  }
}

class _PassengerProfileSyncScreen extends StatelessWidget {
  const _PassengerProfileSyncScreen({
    required this.onRetry,
    required this.onSignOut,
  });

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    'Preparando tu cuenta',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si tardás en entrar por señal baja, tocá reintentar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.taxiyaColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Volver al inicio de sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
