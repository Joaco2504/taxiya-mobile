import 'package:flutter/material.dart';

/// Colores oficiales de TaxiYa definidos en `.agent/memory.md`.
abstract final class TaxiyaColors {
  // Modo Claro (Daylight Mode)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightPrimary = Color(0xFFF59E0B);
  static const Color lightOnPrimary = Color(0xFF0F172A);
  static const Color lightSecondary = Color(0xFF0284C7);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightWarning = Color(0xFFEA580C);
  static const Color lightError = Color(0xFFDC2626);

  // Modo Oscuro (Night Shift Mode)
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkCard = Color(0xFF151C2C);
  static const Color darkBorder = Color(0xFF263147);
  static const Color darkPrimary = Color(0xFFFBBF24);
  static const Color darkOnPrimary = Color(0xFF0B0F19);
  static const Color darkSecondary = Color(0xFF38BDF8);
  static const Color darkOnSecondary = Color(0xFF0B0F19);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkWarning = Color(0xFFFB923C);
  static const Color darkError = Color(0xFFF87171);
}

/// Extensión semántica para acceder rápido a éxito, alerta, error, bordes y texto secundario.
@immutable
class TaxiyaSemanticColors extends ThemeExtension<TaxiyaSemanticColors> {
  const TaxiyaSemanticColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
    required this.textSecondary,
    required this.surfaceCard,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color border;
  final Color textSecondary;
  final Color surfaceCard;

  static const TaxiyaSemanticColors light = TaxiyaSemanticColors(
    success: TaxiyaColors.lightSuccess,
    warning: TaxiyaColors.lightWarning,
    error: TaxiyaColors.lightError,
    border: TaxiyaColors.lightBorder,
    textSecondary: TaxiyaColors.lightTextSecondary,
    surfaceCard: TaxiyaColors.lightCard,
  );

  static const TaxiyaSemanticColors dark = TaxiyaSemanticColors(
    success: TaxiyaColors.darkSuccess,
    warning: TaxiyaColors.darkWarning,
    error: TaxiyaColors.darkError,
    border: TaxiyaColors.darkBorder,
    textSecondary: TaxiyaColors.darkTextSecondary,
    surfaceCard: TaxiyaColors.darkCard,
  );

  @override
  TaxiyaSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? border,
    Color? textSecondary,
    Color? surfaceCard,
  }) {
    return TaxiyaSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      border: border ?? this.border,
      textSecondary: textSecondary ?? this.textSecondary,
      surfaceCard: surfaceCard ?? this.surfaceCard,
    );
  }

  @override
  TaxiyaSemanticColors lerp(
    covariant ThemeExtension<TaxiyaSemanticColors>? other,
    double t,
  ) {
    if (other is! TaxiyaSemanticColors) return this;
    return TaxiyaSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
    );
  }
}

extension TaxiyaThemeContext on BuildContext {
  TaxiyaSemanticColors get taxiyaColors =>
      Theme.of(this).extension<TaxiyaSemanticColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? TaxiyaSemanticColors.dark
          : TaxiyaSemanticColors.light);
}

abstract final class TaxiyaTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeMode themeModeFromString(String? mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? TaxiyaColors.darkBackground : TaxiyaColors.lightBackground;
    final card = isDark ? TaxiyaColors.darkCard : TaxiyaColors.lightCard;
    final border = isDark ? TaxiyaColors.darkBorder : TaxiyaColors.lightBorder;
    final primary = isDark ? TaxiyaColors.darkPrimary : TaxiyaColors.lightPrimary;
    final onPrimary =
        isDark ? TaxiyaColors.darkOnPrimary : TaxiyaColors.lightOnPrimary;
    final secondary =
        isDark ? TaxiyaColors.darkSecondary : TaxiyaColors.lightSecondary;
    final onSecondary =
        isDark ? TaxiyaColors.darkOnSecondary : TaxiyaColors.lightOnSecondary;
    final textPrimary =
        isDark ? TaxiyaColors.darkTextPrimary : TaxiyaColors.lightTextPrimary;
    final textSecondary =
        isDark ? TaxiyaColors.darkTextSecondary : TaxiyaColors.lightTextSecondary;
    final error = isDark ? TaxiyaColors.darkError : TaxiyaColors.lightError;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: error,
      onError: isDark ? TaxiyaColors.darkOnPrimary : Colors.white,
      surface: card,
      onSurface: textPrimary,
      outline: border,
      surfaceContainerHighest: isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFF1F5F9),
      onSurfaceVariant: textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      extensions: [
        isDark ? TaxiyaSemanticColors.dark : TaxiyaSemanticColors.light,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(color: bg),
      ),
    );
  }
}
