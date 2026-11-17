import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Pantalla amigable cuando la cuenta del chofer está pendiente, suspendida o revocada.
/// Permanece escuchando cambios en tiempo real para desbloquear al aprobarse.
class DriverStatusGateScreen extends ConsumerWidget {
  const DriverStatusGateScreen({
    super.key,
    required this.profile,
    this.details,
    this.onEditDossier,
  });

  final Profile profile;
  final DriverDetails? details;
  final VoidCallback? onEditDossier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.taxiyaColors;
    final status = profile.accountStatus;

    final (IconData icon, Color accent, String title, String message) =
        switch (status) {
          TaxiyaAccountStatus.pending => (
            Icons.hourglass_top_rounded,
            Theme.of(context).colorScheme.primary,
            'Tu legajo está en revisión',
            'Un administrador está controlando tu carnet, habilitación municipal y vehículo. Apenas te aprueben, esta pantalla se va a abrir sola para que puedas conectarte.',
          ),
          TaxiyaAccountStatus.suspended => (
            Icons.pause_circle_filled_rounded,
            colors.warning,
            'Tu cuenta está suspendida temporalmente',
            'Por el momento no podés recibir viajes. Revisá el vencimiento de tus papeles o comunicate con administración para reactivar tu legajo.',
          ),
          TaxiyaAccountStatus.revoked => (
            Icons.block_rounded,
            colors.error,
            'Permiso revocado',
            'Tu habilitación como chofer en TaxiYa fue dada de baja y no podés conectarte.',
          ),
          TaxiyaAccountStatus.active => (
            Icons.check_circle_rounded,
            colors.success,
            'Cuenta habilitada',
            'Ya podés operar.',
          ),
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Estado de tu cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: accent, size: 38),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (details != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vehículo registrado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${details!.carBrand ?? ''} ${details!.carModel ?? ''} · ${details!.plateNumber ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vencimiento de habilitación: ${TaxiyaDateUtils.formatDateAr(details!.permitExpiryDate)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (status == TaxiyaAccountStatus.pending) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Esperando aprobación en tiempo real',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (onEditDossier != null &&
                          status != TaxiyaAccountStatus.revoked) ...[
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: onEditDossier,
                          icon: const Icon(Icons.edit_document),
                          label: const Text('Editar legajo enviado'),
                        ),
                      ],
                      const SizedBox(height: 10),
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
