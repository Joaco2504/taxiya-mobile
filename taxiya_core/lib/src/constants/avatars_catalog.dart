import 'package:flutter/material.dart';

/// Avatar predefinido dentro del catálogo oficial de TaxiYa (12 opciones).
@immutable
class TaxiyaPresetAvatar {
  const TaxiyaPresetAvatar({
    required this.id,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  String get storageUri => 'preset://$id';
}

abstract final class TaxiyaAvatars {
  static const List<TaxiyaPresetAvatar> catalog = [
    TaxiyaPresetAvatar(
      id: 'avatar_01',
      label: 'Taxi clásico',
      icon: Icons.local_taxi_rounded,
      backgroundColor: Color(0xFFF59E0B),
      foregroundColor: Color(0xFF0F172A),
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_02',
      label: 'Cerro catamarqueño',
      icon: Icons.landscape_rounded,
      backgroundColor: Color(0xFF0284C7),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_03',
      label: 'Sol del valle',
      icon: Icons.wb_sunny_rounded,
      backgroundColor: Color(0xFFEA580C),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_04',
      label: 'Turno noche',
      icon: Icons.nights_stay_rounded,
      backgroundColor: Color(0xFF151C2C),
      foregroundColor: Color(0xFFFBBF24),
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_05',
      label: 'Ruta segura',
      icon: Icons.shield_rounded,
      backgroundColor: Color(0xFF16A34A),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_06',
      label: 'Brújula',
      icon: Icons.explore_rounded,
      backgroundColor: Color(0xFF0EA5E9),
      foregroundColor: Color(0xFF0B0F19),
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_07',
      label: 'Estrella',
      icon: Icons.star_rounded,
      backgroundColor: Color(0xFFD97706),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_08',
      label: 'Plaza del pueblo',
      icon: Icons.park_rounded,
      backgroundColor: Color(0xFF15803D),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_09',
      label: 'Café al paso',
      icon: Icons.local_cafe_rounded,
      backgroundColor: Color(0xFF92400E),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_10',
      label: 'Música en viaje',
      icon: Icons.music_note_rounded,
      backgroundColor: Color(0xFF7C3AED),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_11',
      label: 'Mate viajero',
      icon: Icons.emoji_food_beverage_rounded,
      backgroundColor: Color(0xFF0D9488),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'avatar_12',
      label: 'Viajero frecuente',
      icon: Icons.person_pin_circle_rounded,
      backgroundColor: Color(0xFFDC2626),
      foregroundColor: Colors.white,
    ),
  ];

  static TaxiyaPresetAvatar? fromUri(String? uri) {
    if (uri == null || !uri.startsWith('preset://')) return null;
    final id = uri.replaceFirst('preset://', '');
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }
}
