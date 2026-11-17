import 'package:flutter/material.dart';

import '../constants/avatars_catalog.dart';

/// Avatar reutilizable: renderiza avatar predefinido (`preset://avatar_XX`),
/// imagen remota HTTP(S) o iniciales del usuario en caso de falta de red.
class TaxiyaAvatar extends StatelessWidget {
  const TaxiyaAvatar({
    super.key,
    required this.avatarUrl,
    this.fullName,
    this.radius = 28,
  });

  final String? avatarUrl;
  final String? fullName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final preset = TaxiyaAvatars.fromUri(avatarUrl);
    if (preset != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: preset.backgroundColor,
        child: Icon(
          preset.icon,
          color: preset.foregroundColor,
          size: radius * 1.05,
        ),
      );
    }

    final url = avatarUrl?.trim();
    if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _InitialsBadge(
              fullName: fullName,
              radius: radius,
            ),
          ),
        ),
      );
    }

    return _InitialsBadge(fullName: fullName, radius: radius);
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.fullName, required this.radius});

  final String? fullName;
  final double radius;

  String get _initials {
    final clean = fullName?.trim() ?? '';
    if (clean.isEmpty) return 'TY';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
