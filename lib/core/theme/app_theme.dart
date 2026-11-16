import 'package:flutter/material.dart';

/// Тема ECLIPSE VPN — палитра снята с Android-приложения.
///
/// Цвета статические, потому что весь клиент использует AppTheme напрямую;
/// при смене темы AppTheme.apply() перекрашивает палитру и корень приложения
/// пересобирается. Так светлая тема работает без переписывания всех экранов.
class AppTheme {
  AppTheme._();

  static bool _dark = true;
  static bool get isDark => _dark;

  /// Текст на золотых кнопках — одинаковый в обеих темах.
  static const Color onGold = Color(0xFF05070D);

  static Color eclipseBlack = const Color(0xFF060a12);
  static Color eclipseBlackLight = const Color(0xFF0a101c);
  static Color navBackground = const Color(0xFF090f1f);
  static Color cardDark = const Color(0xFF0d1424);
  static Color cardDarkSecondary = const Color(0xFF182234);
  static Color cardBorder = const Color(0xFF1e2a3e);

  static Color goldAccent = const Color(0xFFf2c14e);
  static Color goldLight = const Color(0xFFd9a441);
  static Color goldDark = const Color(0xFFb8802f);

  static Color textPrimary = const Color(0xFFf2f5fa);
  static Color textSecondary = const Color(0xFF9aa5b8);
  static Color textMuted = const Color(0xFF667085);

  static Color successGreen = const Color(0xFF22c55e);
  static Color errorRed = const Color(0xFFe0705a);

  static LinearGradient get goldGradient => LinearGradient(
        colors: [
          _dark ? const Color(0xFFf6d47c) : const Color(0xFFD9A441),
          goldLight,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  /// Переключает палитру. Вызывается до построения дерева.
  static void apply(bool dark) {
    _dark = dark;
    if (dark) {
      eclipseBlack = const Color(0xFF060a12);
      eclipseBlackLight = const Color(0xFF0a101c);
      navBackground = const Color(0xFF090f1f);
      cardDark = const Color(0xFF0d1424);
      cardDarkSecondary = const Color(0xFF182234);
      cardBorder = const Color(0xFF1e2a3e);
      goldAccent = const Color(0xFFf2c14e);
      goldLight = const Color(0xFFd9a441);
      goldDark = const Color(0xFFb8802f);
      textPrimary = const Color(0xFFf2f5fa);
      textSecondary = const Color(0xFF9aa5b8);
      textMuted = const Color(0xFF667085);
      successGreen = const Color(0xFF22c55e);
      errorRed = const Color(0xFFe0705a);
    } else {
      eclipseBlack = const Color(0xFFF4F5F9);
      eclipseBlackLight = const Color(0xFFFFFFFF);
      navBackground = const Color(0xFFFFFFFF);
      cardDark = const Color(0xFFFFFFFF);
      cardDarkSecondary = const Color(0xFFEDF1F7);
      cardBorder = const Color(0xFFDDE2EC);
      goldAccent = const Color(0xFFA9740F);
      goldLight = const Color(0xFFB8802F);
      goldDark = const Color(0xFF8A5D0B);
      textPrimary = const Color(0xFF12151C);
      textSecondary = const Color(0xFF5C6474);
      textMuted = const Color(0xFF7A8291);
      successGreen = const Color(0xFF15803D);
      errorRed = const Color(0xFFB91C1C);
    }
  }

  static ThemeData get currentTheme => _build();

  static ThemeData _build() {
    final brightness = _dark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: eclipseBlack,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: goldAccent,
        onPrimary: onGold,
        secondary: goldLight,
        onSecondary: onGold,
        error: errorRed,
        onError: _dark ? onGold : Colors.white,
        surface: cardDark,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cardBorder),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBackground,
        selectedItemColor: goldAccent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
          foregroundColor: onGold,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: goldAccent, width: 1.5),
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
          borderSide: BorderSide(color: goldAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(color: textMuted, fontSize: 15),
      ),
      appBarTheme: AppBarTheme(
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
      dividerTheme: DividerThemeData(color: cardBorder),
    );
  }
}
