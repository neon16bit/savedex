import 'package:material_ui/material_ui.dart';

class AppTheme {
  static List<Color> presets = [
    Colors.blue,
    Colors.deepOrangeAccent,
    Colors.deepPurple,
    Colors.green,
    Colors.red,
    Colors.yellow,
    Colors.cyan,
  ];

  static SnackBarThemeData _buildSnackBarTheme(
    ColorScheme colorScheme, {
    required bool isDark,
    bool isAmoled = false,
  }) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isAmoled
          ? const Color(0xFF1C1C1C)
          : colorScheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: colorScheme.primary,
      disabledActionTextColor: colorScheme.onSurfaceVariant.withValues(
        alpha: 0.38,
      ),
      closeIconColor: colorScheme.onSurfaceVariant,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.45 : 0.35,
          ),
        ),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
    );
  }

  static ThemeData lightTheme({required Color seedColor}) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: lightScheme,
      snackBarTheme: _buildSnackBarTheme(lightScheme, isDark: false),
    );
  }

  static ThemeData darkTheme({
    required Color seedColor,
    bool isAmoled = false,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    if (!isAmoled) {
      return ThemeData(
        colorScheme: baseScheme,
        snackBarTheme: _buildSnackBarTheme(baseScheme, isDark: true),
      );
    }

    final amoledScheme = baseScheme.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: const Color(0xFF1E1E1E),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0D0D0D),
      surfaceContainer: const Color(0xFF141414),
      surfaceContainerHigh: const Color(0xFF1C1C1C),
      surfaceContainerHighest: const Color(0xFF262626),
    );

    return ThemeData(
      colorScheme: amoledScheme,
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF141414)),
      cardTheme: const CardThemeData(color: Color(0xFF101010)),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.black,
      ),
      snackBarTheme: _buildSnackBarTheme(
        amoledScheme,
        isDark: true,
        isAmoled: true,
      ),
    );
  }
}
