import 'package:flutter/material.dart';

/// Rol del catálogo al que pertenece el avatar predefinido.
enum TaxiyaAvatarRole { passenger, driver }

/// Avatar predefinido dentro del catálogo oficial de TaxiYa (12 por rol).
@immutable
class TaxiyaPresetAvatar {
  const TaxiyaPresetAvatar({
    required this.id,
    required this.fileName,
    required this.role,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String id;
  final String fileName;
  final TaxiyaAvatarRole role;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  String get assetPath => 'packages/taxiya_core/assets/avatars/$fileName';
  String get storageUri => 'preset://$id';
}

abstract final class TaxiyaAvatars {
  /// 12 avatares exclusivos para pasajeros (`pasajero_masc_1..6` y `pasajero_fem_1..6`).
  static const List<TaxiyaPresetAvatar> passengerCatalog = [
    TaxiyaPresetAvatar(
      id: 'pasajero_masc_1',
      fileName: 'pasajero_masc_1.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajero 1',
      icon: Icons.person_rounded,
      backgroundColor: Color(0xFF0284C7),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_masc_2',
      fileName: 'pasajero_masc_2.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajero 2',
      icon: Icons.face_rounded,
      backgroundColor: Color(0xFF0EA5E9),
      foregroundColor: Color(0xFF0B0F19),
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_masc_3',
      fileName: 'pasajero_masc_3.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajero 3',
      icon: Icons.hiking_rounded,
      backgroundColor: Color(0xFF15803D),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_masc_4',
      fileName: 'pasajero_masc_4.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajero 4',
      icon: Icons.landscape_rounded,
      backgroundColor: Color(0xFF0D9488),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_masc_5',
      fileName: 'pasajero_masc_5.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajero 5',
      icon: Icons.emoji_food_beverage_rounded,
      backgroundColor: Color(0xFF92400E),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_masc_6',
      fileName: 'pasajero_masc_6.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajero 6',
      icon: Icons.explore_rounded,
      backgroundColor: Color(0xFF151C2C),
      foregroundColor: Color(0xFFFBBF24),
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_fem_1',
      fileName: 'pasajero_fem_1.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajera 1',
      icon: Icons.face_3_rounded,
      backgroundColor: Color(0xFFF59E0B),
      foregroundColor: Color(0xFF0F172A),
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_fem_2',
      fileName: 'pasajero_fem_2.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajera 2',
      icon: Icons.park_rounded,
      backgroundColor: Color(0xFF16A34A),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_fem_3',
      fileName: 'pasajero_fem_3.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajera 3',
      icon: Icons.wb_sunny_rounded,
      backgroundColor: Color(0xFFEA580C),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_fem_4',
      fileName: 'pasajero_fem_4.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajera 4',
      icon: Icons.music_note_rounded,
      backgroundColor: Color(0xFF7C3AED),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_fem_5',
      fileName: 'pasajero_fem_5.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajera 5',
      icon: Icons.local_cafe_rounded,
      backgroundColor: Color(0xFFD97706),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'pasajero_fem_6',
      fileName: 'pasajero_fem_6.png',
      role: TaxiyaAvatarRole.passenger,
      label: 'Pasajera 6',
      icon: Icons.person_pin_circle_rounded,
      backgroundColor: Color(0xFFDC2626),
      foregroundColor: Colors.white,
    ),
  ];

  /// 12 avatares exclusivos para conductores (`conductor_masc_1..8` y `conductor_fem_1..4`).
  static const List<TaxiyaPresetAvatar> driverCatalog = [
    TaxiyaPresetAvatar(
      id: 'conductor_masc_1',
      fileName: 'conductor_masc_1.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 1',
      icon: Icons.local_taxi_rounded,
      backgroundColor: Color(0xFFF59E0B),
      foregroundColor: Color(0xFF0F172A),
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_masc_2',
      fileName: 'conductor_masc_2.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 2',
      icon: Icons.directions_car_rounded,
      backgroundColor: Color(0xFF0284C7),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_masc_3',
      fileName: 'conductor_masc_3.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 3',
      icon: Icons.shield_rounded,
      backgroundColor: Color(0xFF16A34A),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_masc_4',
      fileName: 'conductor_masc_4.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 4',
      icon: Icons.nights_stay_rounded,
      backgroundColor: Color(0xFF151C2C),
      foregroundColor: Color(0xFFFBBF24),
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_masc_5',
      fileName: 'conductor_masc_5.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 5',
      icon: Icons.route_rounded,
      backgroundColor: Color(0xFF0D9488),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_masc_6',
      fileName: 'conductor_masc_6.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 6',
      icon: Icons.star_rounded,
      backgroundColor: Color(0xFFD97706),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_masc_7',
      fileName: 'conductor_masc_7.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 7',
      icon: Icons.landscape_rounded,
      backgroundColor: Color(0xFF0EA5E9),
      foregroundColor: Color(0xFF0B0F19),
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_masc_8',
      fileName: 'conductor_masc_8.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductor 8',
      icon: Icons.verified_user_rounded,
      backgroundColor: Color(0xFF15803D),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_fem_1',
      fileName: 'conductor_fem_1.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductora 1',
      icon: Icons.local_taxi_rounded,
      backgroundColor: Color(0xFFEA580C),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_fem_2',
      fileName: 'conductor_fem_2.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductora 2',
      icon: Icons.explore_rounded,
      backgroundColor: Color(0xFF7C3AED),
      foregroundColor: Colors.white,
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_fem_3',
      fileName: 'conductor_fem_3.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductora 3',
      icon: Icons.wb_sunny_rounded,
      backgroundColor: Color(0xFFF59E0B),
      foregroundColor: Color(0xFF0F172A),
    ),
    TaxiyaPresetAvatar(
      id: 'conductor_fem_4',
      fileName: 'conductor_fem_4.png',
      role: TaxiyaAvatarRole.driver,
      label: 'Conductora 4',
      icon: Icons.shield_rounded,
      backgroundColor: Color(0xFF0284C7),
      foregroundColor: Colors.white,
    ),
  ];

  static const List<TaxiyaPresetAvatar> allCatalog = [
    ...driverCatalog,
    ...passengerCatalog,
  ];

  /// Catálogo completo para compatibilidad al renderizar avatares de cualquier rol.
  static const List<TaxiyaPresetAvatar> catalog = allCatalog;

  static const Map<String, String> _legacyAliases = {
    'avatar_01': 'conductor_masc_1',
    'avatar_02': 'conductor_masc_2',
    'avatar_03': 'conductor_masc_3',
    'avatar_04': 'conductor_masc_4',
    'avatar_05': 'conductor_fem_1',
    'avatar_06': 'conductor_fem_2',
    'avatar_07': 'pasajero_masc_1',
    'avatar_08': 'pasajero_fem_1',
    'avatar_09': 'pasajero_masc_2',
    'avatar_10': 'pasajero_fem_2',
    'avatar_11': 'pasajero_masc_3',
    'avatar_12': 'pasajero_fem_3',
  };

  static TaxiyaPresetAvatar? fromUri(String? uri) {
    if (uri == null || !uri.startsWith('preset://')) return null;
    final rawId = uri.replaceFirst('preset://', '');
    final id = _legacyAliases[rawId] ?? rawId;
    for (final item in allCatalog) {
      if (item.id == id || item.fileName == rawId) return item;
    }
    return null;
  }
}
