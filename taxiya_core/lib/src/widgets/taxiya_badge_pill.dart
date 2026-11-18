import 'package:flutter/material.dart';

import '../models/taxiya_models.dart';
import '../theme/taxiya_theme.dart';

/// Insignia compacta del chofer sin emojis ni ruido visual.
class TaxiyaBadgePill extends StatelessWidget {
  const TaxiyaBadgePill({
    super.key,
    required this.badgeCode,
    this.compact = false,
  });

  final DriverBadgeCode badgeCode;
  final bool compact;

  IconData get _icon {
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
    final theme = Theme.of(context);
    final colors = context.taxiyaColors;
    final isGold = badgeCode.grantsGoldBorder;
    final accent = isGold
        ? theme.colorScheme.primary
        : badgeCode == DriverBadgeCode.nightShift
        ? theme.colorScheme.secondary
        : colors.success;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 14 : 16, color: accent),
          const SizedBox(width: 5),
          Text(
            badgeCode.labelAr,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
