import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/taxiya_env.dart';
import '../models/taxiya_models.dart';
import '../repositories/taxiya_repository.dart';

/// Resultado claro de una acción de compra o restauración de suscripción.
@immutable
class SubscriptionActionResult {
  const SubscriptionActionResult({
    required this.success,
    required this.tier,
    required this.message,
    this.cancelled = false,
    this.sandboxSimulated = false,
  });

  final bool success;
  final SubscriptionTier tier;
  final String message;
  final bool cancelled;
  final bool sandboxSimulated;
}

/// Integración con RevenueCat (`purchases_flutter`) y respaldo de pruebas Sandbox
/// cuando aún no se inyectaron las llaves productivas de Play Store / App Store.
class TaxiyaSubscriptionService {
  const TaxiyaSubscriptionService();

  static bool _isConfigured = false;
  static String? _configuredUserId;

  static String get _platformApiKey {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return TaxiyaEnv.revenueCatAndroidApiKey.trim();
      case TargetPlatform.iOS:
        return TaxiyaEnv.revenueCatIosApiKey.trim();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return '';
    }
  }

  static bool get hasPlatformApiKey => _platformApiKey.isNotEmpty;

  /// Inicializa RevenueCat una única vez por sesión cuando existe API key válida.
  Future<void> ensureInitialized({String? userId}) async {
    final apiKey = _platformApiKey;
    if (apiKey.isEmpty) return;

    try {
      if (!_isConfigured) {
        final configuration = PurchasesConfiguration(apiKey);
        if (userId != null && userId.isNotEmpty) {
          configuration.appUserID = userId;
        }
        await Purchases.configure(configuration);
        _isConfigured = true;
        _configuredUserId = userId;
      } else if (userId != null &&
          userId.isNotEmpty &&
          userId != _configuredUserId) {
        await Purchases.logIn(userId);
        _configuredUserId = userId;
      }
    } catch (_) {
      // En entornos sin Google Play Services o pruebas locales seguimos con respaldo DB/Hive.
    }
  }

  /// Determina el plan vigente inspeccionando entitlements y SKUs activos de RevenueCat.
  SubscriptionTier resolveTierFromCustomerInfo(CustomerInfo info) {
    final activeEntitlements = info.entitlements.active.keys
        .map((String k) => k.toLowerCase())
        .toSet();
    final activeSkus = info.activeSubscriptions
        .map((String s) => s.toLowerCase())
        .toSet();

    if (activeEntitlements.contains(TaxiyaEnv.entitlementPremium) ||
        activeEntitlements.contains('pro') ||
        activeSkus.contains(TaxiyaEnv.productPremiumMonthly)) {
      return SubscriptionTier.premium;
    }

    if (activeEntitlements.contains(TaxiyaEnv.entitlementNoAds) ||
        activeSkus.contains(TaxiyaEnv.productNoAdsMonthly)) {
      return SubscriptionTier.noAds;
    }

    return SubscriptionTier.free;
  }

  DateTime? _parseExpiration(CustomerInfo info) {
    final raw = info.latestExpirationDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Sincroniza el estado real de RevenueCat hacia `taxiya.profiles` (si hay API key).
  Future<SubscriptionTier?> syncActivePlanWithBackend({
    required TaxiyaRepository repository,
    required String userId,
  }) async {
    if (!hasPlatformApiKey) return null;
    try {
      await ensureInitialized(userId: userId);
      final info = await Purchases.getCustomerInfo();
      final tier = resolveTierFromCustomerInfo(info);
      final expiresAt = _parseExpiration(info);
      await repository.updateMySubscriptionTier(
        userId: userId,
        tier: tier,
        expiresAt: expiresAt,
      );
      return tier;
    } catch (_) {
      return null;
    }
  }

  /// Ejecuta la suscripción mensual (`taxiya_no_ads_monthly` o `taxiya_premium_monthly`).
  /// Si no hay API key de RevenueCat inyectada, opera en modo Sandbox controlable en la cuenta de prueba.
  Future<SubscriptionActionResult> purchasePlan({
    required TaxiyaRepository repository,
    required String userId,
    required SubscriptionTier targetTier,
  }) async {
    if (targetTier == SubscriptionTier.free) {
      await repository.updateMySubscriptionTier(
        userId: userId,
        tier: SubscriptionTier.free,
        expiresAt: null,
      );
      return const SubscriptionActionResult(
        success: true,
        tier: SubscriptionTier.free,
        message: 'Volviste al Plan Gratuito en esta cuenta.',
      );
    }

    if (!hasPlatformApiKey) {
      final demoExpiry = DateTime.now().toUtc().add(const Duration(days: 30));
      await repository.updateMySubscriptionTier(
        userId: userId,
        tier: targetTier,
        expiresAt: demoExpiry,
      );
      return SubscriptionActionResult(
        success: true,
        tier: targetTier,
        sandboxSimulated: true,
        message:
            'Activamos ${targetTier.shortTitleAr} en modo de prueba por 30 días.',
      );
    }

    try {
      await ensureInitialized(userId: userId);
      final offerings = await Purchases.getOfferings();
      final targetProductId = targetTier.productId;

      Package? matchedPackage;
      final candidates = <Offering>[
        if (offerings.current != null) offerings.current!,
        ...offerings.all.values,
      ];
      for (final offering in candidates) {
        for (final pkg in offering.availablePackages) {
          if (pkg.storeProduct.identifier == targetProductId ||
              pkg.identifier == targetProductId) {
            matchedPackage = pkg;
            break;
          }
        }
        if (matchedPackage != null) break;
      }

      if (matchedPackage == null) {
        return SubscriptionActionResult(
          success: false,
          tier: SubscriptionTier.free,
          message:
              'Todavía no está publicado el paquete $targetProductId en Google Play / RevenueCat.',
        );
      }

      final result = await Purchases.purchase(
        PurchaseParams.package(matchedPackage),
      );
      final resolvedTier = resolveTierFromCustomerInfo(result.customerInfo);
      final finalTier =
          resolvedTier == SubscriptionTier.free ? targetTier : resolvedTier;
      final expiresAt =
          _parseExpiration(result.customerInfo) ??
          DateTime.now().toUtc().add(const Duration(days: 30));

      await repository.updateMySubscriptionTier(
        userId: userId,
        tier: finalTier,
        expiresAt: expiresAt,
      );

      return SubscriptionActionResult(
        success: true,
        tier: finalTier,
        message: 'Suscripción ${finalTier.shortTitleAr} activada correctamente.',
      );
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return const SubscriptionActionResult(
          success: false,
          cancelled: true,
          tier: SubscriptionTier.free,
          message: 'Operación cancelada sin cargos.',
        );
      }
      return SubscriptionActionResult(
        success: false,
        tier: SubscriptionTier.free,
        message: 'No pudimos completar el pago (${e.message ?? e.code}).',
      );
    } catch (e) {
      return SubscriptionActionResult(
        success: false,
        tier: SubscriptionTier.free,
        message: 'No pudimos procesar la suscripción en este momento.',
      );
    }
  }

  /// Restaura suscripciones previas de Google Play / App Store o sincroniza el estado vigente.
  Future<SubscriptionActionResult> restorePurchases({
    required TaxiyaRepository repository,
    required String userId,
  }) async {
    if (!hasPlatformApiKey) {
      final freshProfile = await repository.fetchProfile(userId);
      final tier = freshProfile?.subscriptionTier ?? SubscriptionTier.free;
      return SubscriptionActionResult(
        success: tier != SubscriptionTier.free,
        tier: tier,
        sandboxSimulated: true,
        message: tier == SubscriptionTier.free
            ? 'No encontramos una suscripción paga activa en esta cuenta.'
            : 'Estado sincronizado: ${tier.labelAr}.',
      );
    }

    try {
      await ensureInitialized(userId: userId);
      final info = await Purchases.restorePurchases();
      final tier = resolveTierFromCustomerInfo(info);
      final expiresAt = _parseExpiration(info);
      await repository.updateMySubscriptionTier(
        userId: userId,
        tier: tier,
        expiresAt: expiresAt,
      );
      return SubscriptionActionResult(
        success: tier != SubscriptionTier.free,
        tier: tier,
        message: tier == SubscriptionTier.free
            ? 'No encontramos compras activas asociadas a tu cuenta de la tienda.'
            : 'Restauramos tu plan ${tier.shortTitleAr} correctamente.',
      );
    } catch (_) {
      return const SubscriptionActionResult(
        success: false,
        tier: SubscriptionTier.free,
        message: 'No pudimos restaurar tus compras. Intentá de nuevo con señal.',
      );
    }
  }
}
