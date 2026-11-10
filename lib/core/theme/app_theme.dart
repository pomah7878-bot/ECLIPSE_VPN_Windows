import 'package:flutter/material.dart';

/// Тема ECLIPSE VPN — палитра снята с Android-приложения
/// (скриншоты /static/app-preview/: login, home, connected, modes).
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: eclipseBlack,
        colorScheme: const ColorScheme.dark(
          primary: goldAccent,
          secondary: goldLight,
          surface: cardDark,
          onPrimary: eclipseBlack,
          onSecondary: eclipseBlack,
          onSurface: textPrimary,
        ),
        cardTheme: CardThemeData(
          color: cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: cardBorder),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: navBackground,
          selectedItemColor: goldAccent,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: goldAccent,
            foregroundColor: eclipseBlack,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: const BorderSide(color: goldAccent, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: eclipseBlack,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
      );

  // ==================== ЦВЕТА (сэмплированы со скриншотов Android) ====================
  static const Color eclipseBlack = Color(0xFF060a12);
  static const Color eclipseBlackLight = Color(0xFF0a101c);
  static const Color navBackground = Color(0xFF090f1f);
  static const Color cardDark = Color(0xFF0d1424);
  static const Color cardDarkSecondary = Color(0xFF182234);
  static const Color cardBorder = Color(0xFF1e2a3e);

  static const Color goldAccent = Color(0xFFf2c14e);
  static const Color goldLight = Color(0xFFd9a441);
  static const Color goldDark = Color(0xFFb8802f);

  static const Color textPrimary = Color(0xFFf2f5fa);
  static const Color textSecondary = Color(0xFF9aa5b8);
  static const Color textMuted = Color(0xFF667085);

  static const Color successGreen = Color(0xFF22c55e);
  static const Color errorRed = Color(0xFFe0705a);

  // ==================== ГРАДИЕНТЫ ====================
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFf6d47c), goldLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
