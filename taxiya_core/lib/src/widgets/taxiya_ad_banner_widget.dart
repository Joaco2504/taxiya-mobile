import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/taxiya_env.dart';
import '../models/taxiya_models.dart';
import '../providers/core_providers.dart';
import '../screens/taxiya_plans_screen.dart';
import '../theme/taxiya_theme.dart';
import '../utils/taxiya_external_launcher.dart';

/// Inicializador seguro de Google Mobile Ads para Android e iOS.
abstract final class TaxiyaAdRuntime {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (_) {
      // Ignora fallos en emuladores o pruebas headless sin servicios Play.
    }
  }

  static String get resolvedBannerUnitId {
    final overrideId = TaxiyaEnv.adMobBannerUnitId.trim();
    if (overrideId.isNotEmpty) return overrideId;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return TaxiyaEnv.defaultIosTestBannerUnitId;
    }
    return TaxiyaEnv.defaultAndroidTestBannerUnitId;
  }
}

/// Banner discreto para usuarios en Plan Gratuito.
/// - Muestra campañas locales pagas y vigentes de `taxiya.ad_banners` rotando cada 15 segundos.
/// - Al tocarlo, suma clic en Supabase y abre WhatsApp o web del comercio local.
/// - Si no hay comercios locales activos en esa ciudad, cae automáticamente a Google AdMob.
/// - Se oculta por completo si el usuario posee Sin Publicidad o Premium.
class TaxiyaAdBannerWidget extends ConsumerStatefulWidget {
  const TaxiyaAdBannerWidget({
    super.key,
    this.localityId,
    this.subscriptionTier,
    this.role,
    this.compact = false,
    this.disablePlatformAdsForTest = false,
  });

  final String? localityId;
  final SubscriptionTier? subscriptionTier;
  final TaxiyaRole? role;
  final bool compact;
  final bool disablePlatformAdsForTest;

  @override
  ConsumerState<TaxiyaAdBannerWidget> createState() =>
      _TaxiyaAdBannerWidgetState();
}

class _TaxiyaAdBannerWidgetState extends ConsumerState<TaxiyaAdBannerWidget> {
  Timer? _rotationTimer;
  int _activeIndex = 0;

  BannerAd? _adMobBanner;
  bool _adMobLoaded = false;
  bool _adMobAttempted = false;

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _activeIndex++);
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _adMobBanner?.dispose();
    super.dispose();
  }

  void _ensureAdMobFallbackLoaded() {
    if (_adMobAttempted || widget.disablePlatformAdsForTest || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _adMobAttempted = true;

    unawaited(() async {
      await TaxiyaAdRuntime.ensureInitialized();
      if (!mounted) return;
      try {
        final banner = BannerAd(
          adUnitId: TaxiyaAdRuntime.resolvedBannerUnitId,
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (Ad ad) {
              if (!mounted) {
                ad.dispose();
                return;
              }
              setState(() {
                _adMobBanner = ad as BannerAd;
                _adMobLoaded = true;
              });
            },
            onAdFailedToLoad: (Ad ad, LoadAdError error) {
              ad.dispose();
              if (mounted) {
                setState(() {
                  _adMobBanner = null;
                  _adMobLoaded = false;
                });
              }
            },
          ),
        );
        await banner.load();
      } catch (_) {
        // Mantiene tarjeta interna promocional sin romper el layout.
      }
    }());
  }

  void _openPlans(BuildContext context, TaxiyaRole role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaxiyaPlansScreen(role: role),
      ),
    );
  }

  Future<void> _onTapLocalBanner(AdBanner banner) async {
    await ref
        .read(taxiyaRepositoryProvider)
        .incrementAdBannerClick(
          bannerId: banner.id,
          nextClicksCount: banner.clicksCount + 1,
        );
    await TaxiyaExternalLauncher.openAdBannerTarget(
      actionType: banner.actionType,
      actionTarget: banner.actionTarget,
      businessName: banner.businessName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Profile? profile = widget.subscriptionTier == null ||
            widget.localityId == null ||
            widget.role == null
        ? (ref.watch(currentProfileProvider).value ??
            ref.read(hiveCacheProvider).loadProfile())
        : null;

    final effectiveTier =
        widget.subscriptionTier ??
        profile?.subscriptionTier ??
        SubscriptionTier.free;

    // Sin Publicidad ($2) y Premium ($3) ocultan todos los anuncios por completo.
    if (effectiveTier.hidesAds) {
      return const SizedBox.shrink();
    }

    final effectiveLocalityId =
        widget.localityId ?? profile?.localityId ?? '';
    final effectiveRole =
        widget.role ?? profile?.role ?? TaxiyaRole.passenger;

    final bannersAsync = effectiveLocalityId.isEmpty
        ? const AsyncValue<List<AdBanner>>.data(<AdBanner>[])
        : ref.watch(activeAdBannersProvider(effectiveLocalityId));

    final localBanners = bannersAsync.value ?? const <AdBanner>[];

    if (localBanners.isNotEmpty) {
      final banner = localBanners[_activeIndex % localBanners.length];
      return _LocalSponsorBannerCard(
        banner: banner,
        compact: widget.compact,
        onTapBanner: () => _onTapLocalBanner(banner),
        onTapRemoveAds: () => _openPlans(context, effectiveRole),
      );
    }

    if (!bannersAsync.isLoading) {
      _ensureAdMobFallbackLoaded();
    }

    if (_adMobLoaded && _adMobBanner != null) {
      return _AdMobFallbackContainer(
        banner: _adMobBanner!,
        compact: widget.compact,
        onTapRemoveAds: () => _openPlans(context, effectiveRole),
      );
    }

    return _UpgradeReminderBanner(
      compact: widget.compact,
      onTapRemoveAds: () => _openPlans(context, effectiveRole),
    );
  }
}

class _LocalSponsorBannerCard extends StatelessWidget {
  const _LocalSponsorBannerCard({
    required this.banner,
    required this.compact,
    required this.onTapBanner,
    required this.onTapRemoveAds,
  });

  final AdBanner banner;
  final bool compact;
  final VoidCallback onTapBanner;
  final VoidCallback onTapRemoveAds;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<TaxiyaSemanticColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final imgHeight = compact ? 42.0 : 48.0;

    return Container(
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: semantic.border),
      ),
      child: InkWell(
        onTap: onTapBanner,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: compact ? 7 : 8,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: imgHeight * 1.45,
                  height: imgHeight,
                  child: banner.imageUrl.trim().isNotEmpty
                      ? Image.network(
                          banner.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _SponsorThumbPlaceholder(
                            name: banner.businessName,
                          ),
                        )
                      : _SponsorThumbPlaceholder(name: banner.businessName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Publicidad local',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            banner.isWhatsAppAction ? 'WhatsApp' : 'Sitio web',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: semantic.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      banner.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _RemoveAdsChip(onPressed: onTapRemoveAds),
            ],
          ),
        ),
      ),
    );
  }
}

class _SponsorThumbPlaceholder extends StatelessWidget {
  const _SponsorThumbPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = name.trim().isNotEmpty
        ? name.trim().characters.first.toUpperCase()
        : 'T';
    return Container(
      color: scheme.primary.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: scheme.primary,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _AdMobFallbackContainer extends StatelessWidget {
  const _AdMobFallbackContainer({
    required this.banner,
    required this.compact,
    required this.onTapRemoveAds,
  });

  final BannerAd banner;
  final bool compact;
  final VoidCallback onTapRemoveAds;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<TaxiyaSemanticColors>()!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: semantic.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Espacio patrocinado',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: semantic.textSecondary,
                ),
              ),
              _RemoveAdsChip(onPressed: onTapRemoveAds),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: banner.size.width.toDouble(),
            height: banner.size.height.toDouble(),
            child: AdWidget(ad: banner),
          ),
        ],
      ),
    );
  }
}

class _UpgradeReminderBanner extends StatelessWidget {
  const _UpgradeReminderBanner({
    required this.compact,
    required this.onTapRemoveAds,
  });

  final bool compact;
  final VoidCallback onTapRemoveAds;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<TaxiyaSemanticColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: semantic.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 18,
            color: scheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r'Espacio comercial · Pasate a Sin Publicidad ($ 2 USD/mes)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: semantic.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _RemoveAdsChip(onPressed: onTapRemoveAds),
        ],
      ),
    );
  }
}

class _RemoveAdsChip extends StatelessWidget {
  const _RemoveAdsChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<TaxiyaSemanticColors>()!;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: semantic.border),
        ),
        child: Text(
          'Quitar anuncios',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: semantic.textSecondary,
          ),
        ),
      ),
    );
  }
}
