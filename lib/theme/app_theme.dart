import 'package:material_ui/material_ui.dart';
import 'package:savedex/theme/catppuccin_palette.dart';

export 'package:savedex/theme/catppuccin_palette.dart';

class AppTheme {
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

  static ThemeData catppuccinTheme({
    required CatppuccinPalette palette,
    required String accentName,
    Color? accentOverride,
    bool isAmoled = false,
    bool useSeedOnly = false,
  }) {
    final accent = accentOverride ?? palette.getColorByName(accentName);
    final isDark = palette.brightness == Brightness.dark;

    if (useSeedOnly) {
      return isDark
          ? darkTheme(seedColor: accent, isAmoled: isAmoled)
          : lightTheme(seedColor: accent);
    }

    final isAccentLight =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.light;
    final onAccent = isAccentLight
        ? (isDark ? palette.crust : CatppuccinPalette.mocha.crust)
        : (isDark ? palette.text : palette.base);

    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: palette.brightness,
    );

    final Color surface;
    final Color surfaceDim;
    final Color surfaceBright;
    final Color surfaceContainerLowest;
    final Color surfaceContainerLow;
    final Color surfaceContainer;
    final Color surfaceContainerHigh;
    final Color surfaceContainerHighest;

    if (isDark && isAmoled) {
      surface = Colors.black;
      surfaceDim = Colors.black;
      surfaceContainerLowest = Colors.black;
      surfaceContainerLow = palette.crust;
      surfaceContainer = palette.mantle;
      surfaceContainerHigh = palette.base;
      surfaceContainerHighest = palette.surface0;
      surfaceBright = palette.surface0;
    } else if (isDark) {
      surface = palette.base;
      surfaceDim = palette.mantle;
      surfaceContainerLowest = palette.crust;
      surfaceContainerLow = Color.alphaBlend(
        palette.surface0.withValues(alpha: 0.6),
        palette.base,
      );
      surfaceContainer = palette.surface0;
      surfaceContainerHigh = palette.surface1;
      surfaceContainerHighest = palette.surface2;
      surfaceBright = palette.surface2;
    } else {
      surface = palette.base;
      surfaceBright = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.55),
        palette.base,
      );
      surfaceContainerLowest = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.55),
        palette.base,
      );
      surfaceContainerLow = palette.mantle;
      surfaceContainer = Color.alphaBlend(
        palette.crust.withValues(alpha: 0.55),
        palette.mantle,
      );
      surfaceContainerHigh = palette.crust;
      surfaceContainerHighest = palette.surface0;
      surfaceDim = palette.surface0;
    }

    final scheme = baseScheme.copyWith(
      brightness: palette.brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.24 : 0.18),
        surfaceContainer,
      ),
      onPrimaryContainer: isDark ? accent : palette.text,
      secondary: palette.subtext1,
      onSecondary: isDark ? palette.crust : palette.base,
      secondaryContainer: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.18 : 0.14),
        surfaceContainerHigh,
      ),
      onSecondaryContainer: palette.text,
      tertiary: baseScheme.tertiary,
      onTertiary: baseScheme.onTertiary,
      tertiaryContainer: surfaceContainerHigh,
      onTertiaryContainer: palette.text,
      error: palette.red,
      onError: isDark ? palette.crust : palette.base,
      errorContainer: Color.alphaBlend(
        palette.red.withValues(alpha: isDark ? 0.24 : 0.16),
        surfaceContainer,
      ),
      onErrorContainer: isDark ? palette.red : palette.text,
      surface: surface,
      onSurface: palette.text,
      onSurfaceVariant: palette.subtext1,
      surfaceDim: surfaceDim,
      surfaceBright: surfaceBright,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: isDark ? palette.overlay1 : palette.overlay0,
      outlineVariant: isDark ? palette.surface2 : palette.surface1,
      inverseSurface: palette.text,
      onInverseSurface: palette.base,
      inversePrimary: accentOverride != null
          ? baseScheme.inversePrimary
          : (isDark
                ? CatppuccinPalette.latte.getColorByName(accentName)
                : CatppuccinPalette.mocha.getColorByName(accentName)),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      cardTheme: CardThemeData(
        color: surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: surface),
      snackBarTheme: _buildSnackBarTheme(scheme, isDark: isDark),
    );
  }
}

class DynamicAccentScope extends InheritedWidget {
  final Color? lightAccent;
  final Color? darkAccent;

  const DynamicAccentScope({
    super.key,
    required this.lightAccent,
    required this.darkAccent,
    required super.child,
  });

  static Color? of(BuildContext context, Brightness brightness) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DynamicAccentScope>();
    if (scope == null) return null;
    return brightness == Brightness.dark
        ? (scope.darkAccent ?? scope.lightAccent)
        : (scope.lightAccent ?? scope.darkAccent);
  }

  @override
  bool updateShouldNotify(covariant DynamicAccentScope oldWidget) {
    return oldWidget.lightAccent != lightAccent ||
        oldWidget.darkAccent != darkAccent;
  }
}
