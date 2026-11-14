import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/services/foreground_enrichment_service.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  ForegroundEnrichmentService.initCommunicationPort();
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
        final rawLightDynamic = lightDynamic != null
            ? Color(lightDynamic.primary.toARGB32())
            : null;
        final darkDynamicScheme = darkDynamic ?? lightDynamic;
        final rawDarkDynamic = darkDynamicScheme != null
            ? Color(darkDynamicScheme.primary.toARGB32())
            : null;

        final lightPalette = settings.catppuccinLightFlavor.palette;
        final darkPalette = settings.catppuccinDarkFlavor.palette;

        final lightTheme = AppTheme.catppuccinTheme(
          palette: lightPalette,
          accentName: settings.effectiveAccentFor(lightPalette.brightness),
          accentOverride: settings.useDynamicColor ? rawLightDynamic : null,
          isAmoled: settings.isAmoled,
          useSeedOnly: settings.useCatppuccinSeed,
        );
        final darkTheme = AppTheme.catppuccinTheme(
          palette: darkPalette,
          accentName: settings.effectiveAccentFor(darkPalette.brightness),
          accentOverride: settings.useDynamicColor ? rawDarkDynamic : null,
          isAmoled: settings.isAmoled,
          useSeedOnly: settings.useCatppuccinSeed,
        );

        return DynamicAccentScope(
          lightAccent: rawLightDynamic,
          darkAccent: rawDarkDynamic,
          child: MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: settings.themeMode,
            home: const AppShell(),
          ),
        );
      },
    );
  }
}
