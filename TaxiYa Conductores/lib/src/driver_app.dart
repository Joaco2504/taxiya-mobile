import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

import 'providers/driver_providers.dart';
import 'screens/driver_auth_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/driver_onboarding_screen.dart';
import 'screens/driver_status_gate_screen.dart';

/// Aplicación principal de TaxiYa Conductores.
class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'TaxiYa Conductores',
      debugShowCheckedModeBanner: false,
      theme: TaxiyaTheme.light,
      darkTheme: TaxiyaTheme.dark,
      themeMode: themeMode,
      home: const _DriverRootGate(),
    );
  }
}

class _DriverRootGate extends ConsumerStatefulWidget {
  const _DriverRootGate();

  @override
  ConsumerState<_DriverRootGate> createState() => _DriverRootGateState();
}

class _DriverRootGateState extends ConsumerState<_DriverRootGate> {
  bool _editingDossier = false;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateStreamProvider);
    final user = authAsync.value;
    if (authAsync.isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user == null) {
      return const DriverAuthScreen();
    }

    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;
    if (profileAsync.isLoading && profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile == null) {
      return _DriverProfileSyncScreen(
        onRetry: () => ref.invalidate(currentProfileProvider),
        onSignOut: () async {
          await ref.read(supabaseClientProvider).auth.signOut();
          await ref.read(hiveCacheProvider).clearUserCache();
        },
      );
    }

    final detailsAsync = ref.watch(driverDetailsProvider);
    final details = detailsAsync.value;
    if (detailsAsync.isLoading && details == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_editingDossier || details == null || !details.hasCompleteDossier) {
      return DriverOnboardingScreen(
        profile: profile,
        existingDetails: details,
        onCompleted: _editingDossier
            ? () => setState(() => _editingDossier = false)
            : null,
      );
    }

    if (profile.accountStatus != TaxiyaAccountStatus.active) {
      return DriverStatusGateScreen(
        profile: profile,
        details: details,
        onEditDossier: () => setState(() => _editingDossier = true),
      );
    }

    return DriverHomeScreen(
      profile: profile,
      details: details,
      onEditDossier: () => setState(() => _editingDossier = true),
    );
  }
}

class _DriverProfileSyncScreen extends StatelessWidget {
  const _DriverProfileSyncScreen({
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
                    'Preparando tu perfil de chofer',
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
