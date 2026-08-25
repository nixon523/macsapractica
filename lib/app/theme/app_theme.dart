import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _primaryColor = Color(0xFF37474F);
  static const Color _secondaryColor = Color(0xFF546E7A);
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _backgroundColor = Color(0xFFF5F5F5);
  static const Color _errorColor = Color(0xFFC62828);
  static const Color _textPrimary = Color(0xFF212121);
  static const Color _textSecondary = Color(0xFF616161);
  static const Color _dividerColor = Color(0xFFE0E0E0);

  static const Color sidebarBackground = Color(0xFF263238);
  static const Color sidebarSelected = Color(0xFF37474F);
  static const Color sidebarHover = Color(0xFF2F3E44);
  static const Color sidebarText = Color(0xFFCFD8DC);
  static const Color sidebarTextSelected = Color(0xFFFFFFFF);
  static const Color sidebarIcon = Color(0xFF90A4AE);
  static const Color sidebarIconSelected = Color(0xFFFFFFFF);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      primary: _primaryColor,
      secondary: _secondaryColor,
      surface: _surfaceColor,
      error: _errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceColor,
        foregroundColor: _textPrimary,
        elevation: 0,
        shadowColor: Color(0x0D000000),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceColor,
        elevation: 1,
        shadowColor: Colors.black.withAlpha(13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: _textSecondary),
      ),
      dividerTheme: const DividerThemeData(
        color: _dividerColor,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(color: _textPrimary),
        bodySmall: TextStyle(color: _textSecondary),
      ),
    );
  }
}
