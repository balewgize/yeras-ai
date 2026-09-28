import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color accent = Color(0xFF2563EB);

  static const Color _lightBackground = Color(0xFFFAFAFB);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceContainer = Color(0xFFE9E9EC);
  static const Color _darkBackground = Color(0xFF101011);
  static const Color _darkSurface = Color(0xFF171718);
  static const Color _darkSurfaceContainer = Color(0xFF242427);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      surface: _lightSurface,
      surfaceContainerHighest: _lightSurfaceContainer,
    );
    return _base(scheme, _lightBackground);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceContainer,
    );
    return _base(scheme, _darkBackground);
  }

  static ThemeData _base(ColorScheme scheme, Color background) {
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
