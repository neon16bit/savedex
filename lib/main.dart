import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SavedexApp(),
    ),
  );
}

class SavedexApp extends ConsumerWidget {
  const SavedexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final seedColor = settings.useDynamicColor && lightDynamic != null
            ? Color(lightDynamic.primary.toARGB32())
            : settings.currentSeedColor;

        final lightTheme = AppTheme.lightTheme(seedColor: seedColor);
        final darkTheme = AppTheme.darkTheme(seedColor: seedColor);

        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: settings.themeMode,
          home: const AppShell(),
        );
      },
    );
  }
}
