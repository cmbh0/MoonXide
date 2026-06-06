import 'package:flutter/material.dart';

class MoonXideTheme {
  static const Color snow = Color(0xFFF7FBFF);
  static const Color ice = Color(0xFFEAF6FF);
  static const Color frost = Color(0xFFD7ECFF);
  static const Color alpineBlue = Color(0xFF5BA7D8);
  static const Color deepBlue = Color(0xFF16496B);

  static Color _seed(String variant) {
    switch (variant) {
      case 'forest':
        return const Color(0xFF32B67A);
      case 'violet':
        return const Color(0xFF8B6DFF);
      case 'sunset':
        return const Color(0xFFFF8A65);
      case 'arctic':
      default:
        return alpineBlue;
    }
  }

  static Color _primary(String variant, Brightness brightness) {
    if (brightness == Brightness.dark) {
      switch (variant) {
        case 'forest':
          return const Color(0xFF7FE3B0);
        case 'violet':
          return const Color(0xFFC1B5FF);
        case 'sunset':
          return const Color(0xFFFFB199);
        case 'arctic':
        default:
          return const Color(0xFF8ED8FF);
      }
    }
    switch (variant) {
      case 'forest':
        return const Color(0xFF16885A);
      case 'violet':
        return const Color(0xFF6652D9);
      case 'sunset':
        return const Color(0xFFE66745);
      case 'arctic':
      default:
        return const Color(0xFF2F8CCB);
    }
  }

  static ThemeData light([String variant = 'arctic']) {
    final primary = _primary(variant, Brightness.light);
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed(variant),
      brightness: Brightness.light,
      primary: primary,
      secondary: Color.lerp(primary, Colors.white, 0.38)!,
      surface: const Color(0xF8FFFFFF),
      surfaceContainerHighest: Color.lerp(primary, Colors.white, 0.90)!,
    );
    return _base(scheme).copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: snow,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white.withOpacity(0.72),
        foregroundColor: deepBlue,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x333B8FC7),
        titleTextStyle: const TextStyle(
          color: deepBlue,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static ThemeData dark([String variant = 'arctic']) {
    final primary = _primary(variant, Brightness.dark);
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed(variant),
      brightness: Brightness.dark,
      primary: primary,
      secondary: Color.lerp(primary, Colors.white, 0.25)!,
      surface: const Color(0xFF0F2230),
      surfaceContainerHighest: Color.lerp(const Color(0xFF1A3345), primary, 0.16)!,
    );
    return _base(scheme).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF071722),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xAA0F2230),
        foregroundColor: Color(0xFFE9F8FF),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface.withOpacity(0.78),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x293B8FC7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 4,
          shadowColor: const Color(0x553B8FC7),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide(color: scheme.primary.withOpacity(0.32)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withOpacity(0.68),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary.withOpacity(0.60), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surface.withOpacity(0.82),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(0.14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withOpacity(0.45), space: 24),
    );
  }
}
