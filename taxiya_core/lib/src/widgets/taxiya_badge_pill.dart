import 'package:flutter/material.dart';

import '../models/taxiya_models.dart';

/// Medalla de insignia con carga desde `packages/taxiya_core/assets/badges/<archivo>.png`
/// y respaldo vectorial automático en el color del material correspondiente (Madera a Obsidiana).
class TaxiyaBadgeArtwork extends StatelessWidget {
  const TaxiyaBadgeArtwork({
    super.key,
    required this.badgeCode,
    required this.level,
    this.size = 44,
    this.locked = false,
  });

  final DriverBadgeCode badgeCode;
  final BadgeLevel level;
  final double size;
  final bool locked;

  IconData get _categoryIcon {
    switch (badgeCode) {
      case DriverBadgeCode.punctual:
        return Icons.schedule_rounded;
      case DriverBadgeCode.localFav:
        return Icons.star_rounded;
      case DriverBadgeCode.impeccable:
        return Icons.verified_rounded;
      case DriverBadgeCode.nightShift:
        return Icons.nightlight_round;
      case DriverBadgeCode.veteran:
        return Icons.workspace_premium_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetLevel = level.isEarned ? level : BadgeLevel.madera;
    final materialColor = Color(targetLevel.colorHex);
    final assetPath = badgeCode.assetPath(targetLevel);

    final badgeBody = SizedBox(
      width: size,
      height: size,
      child: Opacity(
        opacity: locked ? 0.42 : 1.0,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _VectorMedalFallback(
            color: materialColor,
            icon: _categoryIcon,
            levelNumber: targetLevel.level,
            size: size,
          ),
        ),
      ),
    );

    if (!locked) return badgeBody;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        badgeBody,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: materialColor.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: size * 0.28,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _VectorMedalFallback extends StatelessWidget {
  const _VectorMedalFallback({
    required this.color,
    required this.icon,
    required this.levelNumber,
    required this.size,
  });

  final Color color;
  final IconData icon;
  final int levelNumber;
  final double size;

  @override
  Widget build(BuildContext context) {
    final lighter = Color.lerp(color, Colors.white, 0.34)!;
    final darker = Color.lerp(color, Colors.black, 0.28)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[lighter, color, darker],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: size * 0.48,
            color: Colors.white,
          ),
          Positioned(
            bottom: size * 0.08,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'N$levelNumber',
                style: TextStyle(
                  fontSize: (size * 0.2).clamp(8.0, 11.0),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora compacta que muestra categoría, arte/medalla del material y nivel actual.
class TaxiyaBadgePill extends StatelessWidget {
  const TaxiyaBadgePill({
    super.key,
    required this.badgeCode,
    this.level = BadgeLevel.madera,
    this.compact = false,
  });

  final DriverBadgeCode badgeCode;
  final BadgeLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLevel = level.isEarned ? level : BadgeLevel.madera;
    final accent = Color(effectiveLevel.colorHex);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaxiyaBadgeArtwork(
            badgeCode: badgeCode,
            level: effectiveLevel,
            size: compact ? 20 : 24,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${badgeCode.labelAr} · ${effectiveLevel.labelAr}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
