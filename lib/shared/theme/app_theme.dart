import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ThemeType { dark, light, magenta }

class ThemeService extends StateNotifier<ThemeType> {
  static const _kTheme = 'app_theme_type_v2';
  static final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: false),
  );

  ThemeService() : super(ThemeType.dark) {
    loadTheme();
  }

  Future<void> loadTheme() async {
    try {
      final saved = await _storage.read(key: _kTheme);
      if (saved != null) {
        state = ThemeType.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => ThemeType.dark,
        );
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setTheme(ThemeType type) async {
    state = type;
    await _storage.write(key: _kTheme, value: type.name);
  }
}

final themeTypeProvider = StateNotifierProvider<ThemeService, ThemeType>((ref) {
  return ThemeService();
});

class ThemeInfo {
  final ThemeType type;
  final String name;
  final Color primaryColor;

  ThemeInfo(this.type, this.name, this.primaryColor);
}

class AppTheme {
  static List<ThemeInfo> get allThemes => [
    ThemeInfo(ThemeType.dark, '经典深色', darkAccent),
    ThemeInfo(ThemeType.light, '明亮模式', lightAccent),
    ThemeInfo(ThemeType.magenta, '极客品红', magentaAccent),
  ];

  // --- Colors for Magenta Dark (Based on image) ---
  static const Color magentaBg = Color(0xFF0A0A0A);
  static const Color magentaSurface = Color(0xFF161618);
  static const Color magentaSurfaceElevated = Color(0xFF1F1F22);
  static const Color magentaAccent = Color(0xFFE91E63);
  static const Color magentaBorder = Color(0xFF2C2C2E);

  // --- Colors for Classic Dark ---
  static const Color darkBg = Color(0xFF050505);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceElevated = Color(0xFF1E1E1E);
  static const Color darkAccent = Color(0xFF1ED760);
  static const Color darkBorder = Color(0xFF282828);

  // --- Colors for Light Theme ---
  static const Color lightBg = Color(0xFFF9F9F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF0F0F0);
  static const Color lightAccent = Color(0xFF2196F3);
  static const Color lightBorder = Color(0xFFE0E0E0);

  // --- Common Text Colors ---
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFA7ADAA);
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);

  static ThemeData getTheme(ThemeType type) {
    switch (type) {
      case ThemeType.light:
        return _buildTheme(
          brightness: Brightness.light,
          bg: lightBg,
          surface: lightSurface,
          accent: lightAccent,
          textPrimary: textPrimaryLight,
          textSecondary: textSecondaryLight,
          border: lightBorder,
        );
      case ThemeType.magenta:
        return _buildTheme(
          brightness: Brightness.dark,
          bg: magentaBg,
          surface: magentaSurface,
          accent: magentaAccent,
          textPrimary: textPrimaryDark,
          textSecondary: textSecondaryDark,
          border: magentaBorder,
        );
      case ThemeType.dark:
        return _buildTheme(
          brightness: Brightness.dark,
          bg: darkBg,
          surface: darkSurface,
          accent: darkAccent,
          textPrimary: textPrimaryDark,
          textSecondary: textSecondaryDark,
          border: darkBorder,
        );
    }
  }

  // --- Compatibility Layer (Fixes lint errors in existing files) ---
  static const Color bgBase = darkBg;
  static const Color surface = darkSurface;
  static const Color surfaceElevated = darkSurfaceElevated;
  static const Color border = darkBorder;
  static const Color accent = darkAccent;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;

  static ThemeData get darkTheme => getTheme(ThemeType.dark);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: accent,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}
