import 'package:flutter/material.dart';

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

  static ThemeData lightTheme({required Color seedColor}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
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
      return ThemeData(colorScheme: baseScheme);
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
    );
  }
}
