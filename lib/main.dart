import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/core/utils/responsive_layout.dart';
import 'package:savedex/data/services/foreground_enrichment_service.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PackageInfo?> _loadPackageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  ForegroundEnrichmentService.initCommunicationPort();
  final (prefs, packageInfo) = await (
    SharedPreferences.getInstance(),
    _loadPackageInfo(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        packageInfoProvider.overrideWithValue(packageInfo),
      ],
      child: const SavedexApp(),
    ),
  );
}

class SavedexApp extends ConsumerWidget {
  const SavedexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(
      settingsViewModelProvider.select(
        (s) => (
          themeMode: s.themeMode,
          catppuccinLightFlavor: s.catppuccinLightFlavor,
          catppuccinDarkFlavor: s.catppuccinDarkFlavor,
          catppuccinAccent: s.catppuccinAccent,
          useDynamicColor: s.useDynamicColor,
          isAmoled: s.isAmoled,
          useCatppuccinSeed: s.useCatppuccinSeed,
        ),
      ),
    );

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final rawLightDynamic = lightDynamic != null
            ? Color(lightDynamic.primary.toARGB32())
            : null;
        final darkDynamicScheme = darkDynamic ?? lightDynamic;
        final rawDarkDynamic = darkDynamicScheme != null
            ? Color(darkDynamicScheme.primary.toARGB32())
            : null;

        final lightPalette = themeSettings.catppuccinLightFlavor.palette;
        final darkPalette = themeSettings.catppuccinDarkFlavor.palette;
        final lightAccent =
            themeSettings.catppuccinAccent != null &&
                themeSettings.catppuccinAccent!.isNotEmpty
            ? themeSettings.catppuccinAccent!
            : 'Maroon';
        final darkAccent =
            themeSettings.catppuccinAccent != null &&
                themeSettings.catppuccinAccent!.isNotEmpty
            ? themeSettings.catppuccinAccent!
            : 'Red';

        final lightTheme = AppTheme.catppuccinTheme(
          palette: lightPalette,
          accentName: lightAccent,
          accentOverride: themeSettings.useDynamicColor
              ? rawLightDynamic
              : null,
          isAmoled: themeSettings.isAmoled,
          useSeedOnly: themeSettings.useCatppuccinSeed,
        );
        final darkTheme = AppTheme.catppuccinTheme(
          palette: darkPalette,
          accentName: darkAccent,
          accentOverride: themeSettings.useDynamicColor
              ? rawDarkDynamic
              : null,
          isAmoled: themeSettings.isAmoled,
          useSeedOnly: themeSettings.useCatppuccinSeed,
        );

        return DynamicAccentScope(
          lightAccent: rawLightDynamic,
          darkAccent: rawDarkDynamic,
          child: MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeSettings.themeMode,
            builder: (context, child) => ResponsiveScope(
              child: Builder(
                builder: (ctx) {
                  final theme = Theme.of(ctx);
                  final isDesktop = ResponsiveLayout.isDesktop(ctx);
                  return SnackBarTheme(
                    data: theme.snackBarTheme.copyWith(
                      behavior: isDesktop
                          ? SnackBarBehavior.floating
                          : theme.snackBarTheme.behavior,
                      width: isDesktop ? kDesktopSnackBarMaxWidth : null,
                      insetPadding: isDesktop
                          ? const EdgeInsets.fromLTRB(16, 6, 16, 16)
                          : theme.snackBarTheme.insetPadding,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              ),
            ),
            home: const AppShell(),
          ),
        );
      },
    );
  }
}
