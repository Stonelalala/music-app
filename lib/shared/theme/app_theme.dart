import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ThemeType { system, dark, light, magenta }

class ThemeService extends StateNotifier<ThemeType> {
  static const _storageKey = 'app_theme_type_v3';
  static final _storage = FlutterSecureStorage();

  ThemeService() : super(ThemeType.system) {
    loadTheme();
  }

  Future<void> loadTheme() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null) {
        state = ThemeType.values.firstWhere(
          (value) => value.name == saved,
          orElse: () => ThemeType.system,
        );
      }
    } catch (error) {
      debugPrint('Failed to load theme: $error');
    }
  }

  Future<void> setTheme(ThemeType type) async {
    state = type;
    await _storage.write(key: _storageKey, value: type.name);
  }
}

final themeTypeProvider = StateNotifierProvider<ThemeService, ThemeType>((ref) {
  return ThemeService();
});

class ThemeInfo {
  const ThemeInfo(this.type, this.name, this.primaryColor);

  final ThemeType type;
  final String name;
  final Color primaryColor;
}

class AppTheme {
  static const Color vinylBg = Color(0xFF06090C);
  static const Color vinylSurface = Color(0xFF10161C);
  static const Color vinylSurfaceElevated = Color(0xFF17222A);
  static const Color vinylAccent = Color(0xFF28E07A);
  static const Color vinylSecondary = Color(0xFFFFB84D);
  static const Color vinylBorder = Color(0xFF24333E);
  static const Color vinylText = Color(0xFFF5F7FA);
  static const Color vinylTextMuted = Color(0xFFA6B3BE);

  static const Color lightBg = Color(0xFFF7F8FA);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceElevated = Color(0xFFF0F3F6);
  static const Color lightAccent = Color(0xFF1F78FF);
  static const Color lightSecondary = Color(0xFF15B89A);
  static const Color lightBorder = Color(0xFFD6DEE6);
  static const Color lightText = Color(0xFF101317);
  static const Color lightTextMuted = Color(0xFF6F7A85);

  static const Color magentaBg = Color(0xFF0D0811);
  static const Color magentaSurface = Color(0xFF191121);
  static const Color magentaSurfaceElevated = Color(0xFF24162D);
  static const Color magentaAccent = Color(0xFFF04BA5);
  static const Color magentaSecondary = Color(0xFF7CFFEA);
  static const Color magentaBorder = Color(0xFF342140);
  static const Color magentaText = Color(0xFFF8F2F8);
  static const Color magentaTextMuted = Color(0xFFB7AABC);

  static List<ThemeInfo> get allThemes => const [
    ThemeInfo(ThemeType.system, '跟随系统', vinylAccent),
    ThemeInfo(ThemeType.dark, '黑胶夜幕', vinylAccent),
    ThemeInfo(ThemeType.light, '云光浅色', lightAccent),
    ThemeInfo(ThemeType.magenta, '霓虹玫红', magentaAccent),
  ];

  static ThemeData getTheme(ThemeType type) {
    switch (type) {
      case ThemeType.system:
      case ThemeType.dark:
        return _buildTheme(
          brightness: Brightness.dark,
          bg: vinylBg,
          surface: vinylSurface,
          surfaceElevated: vinylSurfaceElevated,
          primary: vinylAccent,
          secondary: vinylSecondary,
          outline: vinylBorder,
          textPrimary: vinylText,
          textSecondary: vinylTextMuted,
        );
      case ThemeType.light:
        return _buildTheme(
          brightness: Brightness.light,
          bg: lightBg,
          surface: lightSurface,
          surfaceElevated: lightSurfaceElevated,
          primary: lightAccent,
          secondary: lightSecondary,
          outline: lightBorder,
          textPrimary: lightText,
          textSecondary: lightTextMuted,
        );
      case ThemeType.magenta:
        return _buildTheme(
          brightness: Brightness.dark,
          bg: magentaBg,
          surface: magentaSurface,
          surfaceElevated: magentaSurfaceElevated,
          primary: magentaAccent,
          secondary: magentaSecondary,
          outline: magentaBorder,
          textPrimary: magentaText,
          textSecondary: magentaTextMuted,
        );
    }
  }

  static ThemeData get darkTheme => getTheme(ThemeType.dark);

  // Compatibility aliases used by existing widgets.
  static const Color bgBase = vinylBg;
  static const Color surface = vinylSurface;
  static const Color surfaceElevated = vinylSurfaceElevated;
  static const Color border = vinylBorder;
  static const Color accent = vinylAccent;
  static const Color textPrimary = vinylText;
  static const Color textSecondary = vinylTextMuted;
  static const Color errorColor = Color(0xFFFF5C63);
  static const Color successColor = Color(0xFF2DD082);

  static LinearGradient heroGradient(ColorScheme scheme) => LinearGradient(
    colors: [
      scheme.primary.withValues(alpha: 0.18),
      scheme.secondary.withValues(alpha: 0.08),
      scheme.surfaceContainerHighest.withValues(alpha: 0.26),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceElevated,
    required Color primary,
    required Color secondary,
    required Color outline,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          secondary: secondary,
          onSecondary: brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          surface: surface,
          onSurface: textPrimary,
          surfaceContainer: surfaceElevated,
          surfaceContainerHigh: Color.alphaBlend(
            primary.withValues(alpha: 0.08),
            surfaceElevated,
          ),
          surfaceContainerHighest: Color.alphaBlend(
            primary.withValues(alpha: 0.12),
            surfaceElevated,
          ),
          outline: outline,
          outlineVariant: outline.withValues(alpha: 0.72),
          onSurfaceVariant: textSecondary,
          error: const Color(0xFFFF5C63),
          onError: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14, height: 1.42),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.18)),
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        disabledColor: scheme.surfaceContainerHighest.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        hintStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.2),
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: scheme.outlineVariant.withValues(alpha: 0.22),
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
