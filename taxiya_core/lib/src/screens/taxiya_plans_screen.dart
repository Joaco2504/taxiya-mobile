import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/taxiya_models.dart';
import '../providers/core_providers.dart';
import '../services/revenuecat_service.dart';
import '../theme/taxiya_theme.dart';
import '../utils/date_format_utils.dart';

/// Pantalla compartida "Planes y Suscripciones" para Pasajeros y Conductores.
/// Compara Gratuito ($0), Sin Publicidad ($2 USD/mes) y Premium ($3 USD/mes),
/// e integra compras mensuales con RevenueCat y modo Sandbox de prueba.
class TaxiyaPlansScreen extends ConsumerStatefulWidget {
  const TaxiyaPlansScreen({super.key, this.role});

  final TaxiyaRole? role;

  @override
  ConsumerState<TaxiyaPlansScreen> createState() => _TaxiyaPlansScreenState();
}

class _TaxiyaPlansScreenState extends ConsumerState<TaxiyaPlansScreen> {
  SubscriptionTier? _loadingTier;
  bool _restoring = false;

  Future<void> _selectPlan(Profile profile, SubscriptionTier targetTier) async {
    if (_loadingTier != null || _restoring) return;
    setState(() => _loadingTier = targetTier);

    try {
      final result = await ref
          .read(subscriptionServiceProvider)
          .purchasePlan(
            repository: ref.read(taxiyaRepositoryProvider),
            userId: profile.id,
            targetTier: targetTier,
          );

      if (!mounted) return;
      if (result.success) {
        ref.invalidate(currentProfileProvider);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) {
        setState(() => _loadingTier = null);
      }
    }
  }

  Future<void> _restorePurchases(Profile profile) async {
    if (_loadingTier != null || _restoring) return;
    setState(() => _restoring = true);

    try {
      final result = await ref
          .read(subscriptionServiceProvider)
          .restorePurchases(
            repository: ref.read(taxiyaRepositoryProvider),
            userId: profile.id,
          );
      if (!mounted) return;
      if (result.success) {
        ref.invalidate(currentProfileProvider);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final cached = ref.read(hiveCacheProvider).loadProfile();
    final profile = profileAsync.value ?? cached;
    final activeTier = profile?.subscriptionTier ?? SubscriptionTier.free;
    final effectiveRole = widget.role ?? profile?.role ?? TaxiyaRole.passenger;
    final isDriver = effectiveRole == TaxiyaRole.driver;
    final semantic = Theme.of(context).extension<TaxiyaSemanticColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes y Suscripciones'),
        actions: [
          TextButton.icon(
            onPressed: profile == null || _restoring
                ? null
                : () => _restorePurchases(profile),
            icon: _restoring
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Restaurar'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            activeTier.isPremium
                                ? Icons.workspace_premium_rounded
                                : activeTier.hidesAds
                                    ? Icons.verified_user_outlined
                                    : Icons.local_taxi_outlined,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plan activo: ${activeTier.shortTitleAr}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeTier.isFree
                                    ? 'Tenés acceso completo a viajes y seguridad con publicidad local.'
                                    : profile?.subscriptionExpiresAt != null
                                        ? 'Renovación / vigencia estimada hasta ${TaxiyaDateUtils.formatDateAr(profile!.subscriptionExpiresAt!.toLocal())}.'
                                        : 'Beneficios activos en tu cuenta de TaxiYa.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: semantic.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!TaxiyaSubscriptionService.hasPlatformApiKey) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: scheme.secondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Modo de prueba Sandbox activo: podés cambiar de plan sin cobro real hasta publicar las claves de Google Play / RevenueCat.',
                          style: TextStyle(
                            fontSize: 12,
                            color: semantic.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _PlanComparisonCard(
              title: 'Plan Gratuito',
              priceLabel: r'$ 0',
              subtitle:
                  'Todo lo esencial para pedir o tomar viajes en Belén y Andalgalá.',
              features: isDriver
                  ? const <String>[
                      'Pedidos en vivo e historial de traslados',
                      'Sistema de 30 insignias progresivas y prioridades',
                      'Chat protegido, emergencias y avisos',
                      'Incluye banner discreto de comercios locales',
                    ]
                  : const <String>[
                      'Mapa en vivo, ida y vuelta y reservas programadas (hasta 1 activa)',
                      'Hasta 2 lugares personales guardados',
                      'Chat en tiempo real y compartir viaje por WhatsApp',
                      'Incluye banner discreto de comercios locales',
                    ],
              isCurrent: activeTier == SubscriptionTier.free,
              accentColor: semantic.textSecondary,
              actionLabel: activeTier == SubscriptionTier.free
                  ? 'Plan actual'
                  : !TaxiyaSubscriptionService.hasPlatformApiKey
                      ? 'Volver al Plan Gratuito (prueba)'
                      : null,
              loading: _loadingTier == SubscriptionTier.free,
              onPressed: profile == null ||
                      activeTier == SubscriptionTier.free ||
                      TaxiyaSubscriptionService.hasPlatformApiKey
                  ? null
                  : () => _selectPlan(profile, SubscriptionTier.free),
            ),
            const SizedBox(height: 12),
            _PlanComparisonCard(
              title: 'Sin Publicidad',
              priceLabel: r'$ 2 USD / mes',
              subtitle:
                  'Navegación completamente limpia, sin anuncios ni banners en ninguna pantalla.',
              features: const <String>[
                'Elimina los banners en inicio, espera y menú',
                'Interfaz más despejada y directa en todo momento',
                'Facturación mensual simple con Google Play o tienda',
              ],
              isCurrent: activeTier == SubscriptionTier.noAds,
              accentColor: scheme.secondary,
              actionLabel: activeTier == SubscriptionTier.noAds
                  ? 'Plan actual'
                  : 'Pasarme a Sin Publicidad',
              loading: _loadingTier == SubscriptionTier.noAds,
              onPressed: profile == null || activeTier == SubscriptionTier.noAds
                  ? null
                  : () => _selectPlan(profile, SubscriptionTier.noAds),
            ),
            const SizedBox(height: 12),
            _PlanComparisonCard(
              title: 'Plan Premium',
              priceLabel: r'$ 3 USD / mes',
              badgeLabel: 'Recomendado',
              subtitle: isDriver
                  ? 'Sin publicidad y herramientas exclusivas para rendir más en cada turno.'
                  : 'Sin publicidad y ventajas exclusivas para tus viajes frecuentes.',
              features: isDriver
                  ? const <String>[
                      'Sin publicidad en toda la app',
                      'Mapa de calor y horarios pico de tu localidad',
                      'Tonos exclusivos para alertas de nuevos pedidos',
                      'Prioridad combinada con tus insignias ganadas',
                    ]
                  : const <String>[
                      'Sin publicidad en toda la app',
                      'Lugares personales ilimitados en lugar de 2',
                      'Taxistas Favoritos: tu chofer elegido ve el pedido 10 s antes',
                      'Reservas programadas ilimitadas',
                    ],
              isCurrent: activeTier == SubscriptionTier.premium,
              accentColor: scheme.primary,
              isHighlighted: true,
              actionLabel: activeTier == SubscriptionTier.premium
                  ? 'Plan actual'
                  : 'Suscribirme a Premium',
              loading: _loadingTier == SubscriptionTier.premium,
              onPressed: profile == null || activeTier == SubscriptionTier.premium
                  ? null
                  : () => _selectPlan(profile, SubscriptionTier.premium),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: profile == null || _restoring
                  ? null
                  : () => _restorePurchases(profile),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Restaurar compras'),
            ),
            const SizedBox(height: 8),
            Text(
              'La suscripción mensual se gestiona desde tu cuenta de tienda y podés cancelarla cuando quieras. Si pagás tu plan en otra unidad, tocá Restaurar compras.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: semantic.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanComparisonCard extends StatelessWidget {
  const _PlanComparisonCard({
    required this.title,
    required this.priceLabel,
    required this.subtitle,
    required this.features,
    required this.isCurrent,
    required this.accentColor,
    required this.loading,
    this.badgeLabel,
    this.isHighlighted = false,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String priceLabel;
  final String subtitle;
  final List<String> features;
  final bool isCurrent;
  final Color accentColor;
  final bool loading;
  final String? badgeLabel;
  final bool isHighlighted;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<TaxiyaSemanticColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCurrent
              ? semantic.success
              : isHighlighted
                  ? scheme.primary
                  : semantic.border,
          width: isCurrent || isHighlighted ? 1.8 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: semantic.success.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Activo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: semantic.success,
                      ),
                    ),
                  )
                else if (badgeLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              priceLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: semantic.textSecondary),
            ),
            const SizedBox(height: 12),
            ...features.map(
              (String item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isCurrent ? semantic.success : accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: isHighlighted && !isCurrent
                    ? FilledButton(
                        onPressed: loading ? null : onPressed,
                        child: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(actionLabel!),
                      )
                    : OutlinedButton(
                        onPressed: loading ? null : onPressed,
                        child: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(actionLabel!),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
