import 'package:flutter/material.dart';

/// Тема ECLIPSE VPN — полная синхронизация с Android-приложением.
///
/// Цвета взяты с web-привью: https://eclipse.unlimited.bot.nu/app
/// Скриншоты: login.jpg, home.jpg, connected.jpg, modes.jpg, light.jpg
class AppTheme {
  AppTheme._();

  // ==================== ТЕМНАЯ ТЕМА (основная) ====================
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: eclipseBlack,
        colorScheme: const ColorScheme.dark(
          primary: goldAccent,
          secondary: goldLight,
          surface: cardDark,
          background: eclipseBlack,
          onPrimary: eclipseBlack,
          onSecondary: eclipseBlack,
          onSurface: textPrimary,
          onBackground: textPrimary,
        ),
        fontFamily: 'Inter',
        textTheme: _textTheme,
        cardTheme: CardThemeData(
          color: cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: eclipseBlack,
          selectedItemColor: goldAccent,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: goldAccent,
            foregroundColor: eclipseBlack,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: goldAccent,
            side: const BorderSide(color: goldAccent, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: goldAccent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        ),
      );

  // ==================== СВЕТЛАЯ ТЕМА ====================
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: eclipseWhite,
        colorScheme: const ColorScheme.light(
          primary: goldDark,
          secondary: goldAccent,
          surface: cardLight,
          background: eclipseWhite,
          onPrimary: Colors.white,
          onSecondary: eclipseBlack,
          onSurface: eclipseBlack,
          onBackground: eclipseBlack,
        ),
        fontFamily: 'Inter',
        textTheme: _textThemeLight,
        cardTheme: CardThemeData(
          color: cardLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: eclipseWhite,
          selectedItemColor: goldDark,
          unselectedItemColor: textMutedLight,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: goldDark,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: goldDark,
            side: const BorderSide(color: goldDark, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: goldDark, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: textMutedLight, fontSize: 15),
        ),
      );

  // ==================== ЦВЕТА ====================
  static const Color eclipseBlack = Color(0xFF0b0b0f);
  static const Color eclipseBlackLight = Color(0xFF14141b);
  static const Color cardDark = Color(0xFF1a1a22);
  static const Color cardDarkSecondary = Color(0xFF23232d);

  static const Color eclipseWhite = Color(0xFFf0f0f5);
  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color goldAccent = Color(0xFFefbd6b);
  static const Color goldLight = Color(0xFFd69e4a);
  static const Color goldDark = Color(0xFFb8802f);
  static const Color goldGlow = Color(0x403a3020);

  static const Color textPrimary = Color(0xFFe8e6e3);
  static const Color textSecondary = Color(0xFFa8a8b4);
  static const Color textMuted = Color(0xFF6f6f7c);

  static const Color textPrimaryLight = Color(0xFF0b0b0f);
  static const Color textSecondaryLight = Color(0xFF6f6f7c);
  static const Color textMutedLight = Color(0xFF9a9aa8);

  static const Color successGreen = Color(0xFF4ade80);
  static const Color errorRed = Color(0xFFe0705a);

  // ==================== ГРАДИЕНТЫ ====================
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, goldAccent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient goldGradientVertical = LinearGradient(
    colors: [goldAccent, goldLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ==================== ТЕКСТОВЫЕ СТИЛИ ====================
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
    bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
    bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
  );

  static const TextTheme _textThemeLight = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryLight),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryLight),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimaryLight),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryLight),
    bodyLarge: TextStyle(fontSize: 16, color: textPrimaryLight),
    bodyMedium: TextStyle(fontSize: 14, color: textSecondaryLight),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryLight),
  );
}
