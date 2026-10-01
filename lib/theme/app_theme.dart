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

  static ThemeData darkTheme({required Color seedColor}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
