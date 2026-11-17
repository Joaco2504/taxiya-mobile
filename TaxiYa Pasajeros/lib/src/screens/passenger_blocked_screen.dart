import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Bloqueo instantáneo cuando la cuenta del pasajero está suspendida o revocada.
class PassengerBlockedScreen extends ConsumerWidget {
  const PassengerBlockedScreen({
    super.key,
    required this.profile,
  });

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.taxiyaColors;
    final isRevoked = profile.accountStatus == TaxiyaAccountStatus.revoked;
    final accent = isRevoked ? colors.error : colors.warning;

    return Scaffold(
      appBar: AppBar(title: const Text('Acceso restringido')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRevoked
                                ? Icons.block_rounded
                                : Icons.pause_circle_filled_rounded,
                            color: accent,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isRevoked
                            ? 'Tu cuenta fue revocada'
                            : 'Tu cuenta está suspendida',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isRevoked
                            ? 'Por disposición administrativa no podés seguir operando en TaxiYa.'
                            : 'Suspendimos temporalmente el acceso a tu cuenta. Si necesitás revisarlo, escribinos desde soporte.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(supabaseClientProvider).auth.signOut();
                          await ref.read(hiveCacheProvider).clearUserCache();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
