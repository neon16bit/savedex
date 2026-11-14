import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/repositories/settings_repository.dart';
import 'package:savedex/theme/app_theme.dart';

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, UserSettings>(() {
      return SettingsViewModel();
    });

final sessionMuteStateProvider =
    NotifierProvider<SessionMuteStateNotifier, bool?>(() {
      return SessionMuteStateNotifier();
    });

class SessionMuteStateNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void setMuted(bool isMuted) {
    state = isMuted;
  }
}

class SettingsViewModel extends Notifier<UserSettings> {
  @override
  UserSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.settings;
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void setThemeFlavor(ThemeFlavor flavor) {
    state = switch (flavor) {
      ThemeFlavor.system => state.copyWith(
        themeMode: ThemeMode.system,
        catppuccinLightFlavor: CatppuccinFlavor.latte,
        catppuccinDarkFlavor: CatppuccinFlavor.mocha,
      ),
      ThemeFlavor.latte => state.copyWith(
        themeMode: ThemeMode.light,
        catppuccinLightFlavor: CatppuccinFlavor.latte,
      ),
      ThemeFlavor.frappe => state.copyWith(
        themeMode: ThemeMode.dark,
        catppuccinDarkFlavor: CatppuccinFlavor.frappe,
      ),
      ThemeFlavor.macchiato => state.copyWith(
        themeMode: ThemeMode.dark,
        catppuccinDarkFlavor: CatppuccinFlavor.macchiato,
      ),
      ThemeFlavor.mocha => state.copyWith(
        themeMode: ThemeMode.dark,
        catppuccinDarkFlavor: CatppuccinFlavor.mocha,
      ),
    };
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleDynamicColor(bool useDynamic) {
    state = state.copyWith(useDynamicColor: useDynamic);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void setCatppuccinLightFlavor(CatppuccinFlavor flavor) {
    state = state.copyWith(catppuccinLightFlavor: flavor);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void setCatppuccinDarkFlavor(CatppuccinFlavor flavor) {
    state = state.copyWith(catppuccinDarkFlavor: flavor);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void setCatppuccinFlavorForBrightness(
    CatppuccinFlavor flavor,
    Brightness brightness,
  ) {
    if (brightness == Brightness.light) {
      setCatppuccinLightFlavor(flavor);
    } else {
      setCatppuccinDarkFlavor(flavor);
    }
  }

  void setCatppuccinAccent(String accent) {
    state = state.copyWith(useDynamicColor: false, catppuccinAccent: accent);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleCatppuccinSeed([bool? value]) {
    final nextValue = value ?? !state.useCatppuccinSeed;
    state = state.copyWith(useCatppuccinSeed: nextValue);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleAmoled(bool isAmoled) {
    state = state.copyWith(isAmoled: isAmoled);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void setFeedLayoutMode(FeedLayoutMode mode) {
    state = state.copyWith(feedLayoutMode: mode);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleStartVideosMuted(bool val) {
    state = state.copyWith(startVideosMuted: val);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleHideNsfwInFeed([bool? value]) {
    final nextValue = value ?? !state.hideNsfwInFeed;
    state = state.copyWith(hideNsfwInFeed: nextValue);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleFrostedEffects([bool? value]) {
    final nextValue = value ?? !state.enableFrostedEffects;
    state = state.copyWith(enableFrostedEffects: nextValue);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void updateRedditCredentials({
    required String? clientId,
    String? clientSecret,
    required String? redirectUri,
    required String? userAgent,
  }) {
    state = state.copyWith(
      redditClientId: clientId?.trim().isEmpty == true
          ? null
          : clientId?.trim(),
      redditClientSecret: clientSecret?.trim().isEmpty == true
          ? null
          : clientSecret?.trim(),
      redditRedirectUri: redirectUri?.trim().isEmpty == true
          ? null
          : redirectUri?.trim(),
      userAgent: userAgent?.trim().isEmpty == true ? null : userAgent?.trim(),
    );
    ref.read(settingsRepositoryProvider).updateSettings(state);

    ref
        .read(redditApiServiceProvider)
        .updateCredentials(
          clientId: state.redditClientId,
          clientSecret: state.redditClientSecret,
          redirectUri: state.redditRedirectUri,
          userAgent: state.userAgent,
        );
  }

  void setOAuthTokens({
    required String accessToken,
    required String? refreshToken,
    required int expiresIn,
  }) {
    final expiry = DateTime.now().toUtc().add(
      Duration(seconds: (expiresIn - 300).clamp(60, expiresIn)),
    );
    state = state.copyWith(
      redditAccessToken: accessToken,
      redditRefreshToken: refreshToken,
      redditTokenExpiry: expiry,
    );
    ref.read(settingsRepositoryProvider).updateSettings(state);

    ref
        .read(redditApiServiceProvider)
        .updateCredentials(
          accessToken: accessToken,
          refreshToken: refreshToken,
          tokenExpiry: expiry,
        );
  }

  void saveRefreshedToken(String accessToken, int expiresIn) {
    final expiry = DateTime.now().toUtc().add(
      Duration(seconds: (expiresIn - 300).clamp(60, expiresIn)),
    );
    state = state.copyWith(
      redditAccessToken: accessToken,
      redditTokenExpiry: expiry,
    );
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void clearOAuthAuth() {
    state = state.copyWith(clearOAuthTokens: true);
    ref.read(settingsRepositoryProvider).updateSettings(state);

    ref.read(redditApiServiceProvider).updateCredentials(clearTokens: true);
  }

  void setRedditUsername(String? username) {
    state = state.copyWith(redditUsername: username);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleAutoEnrich(bool autoEnrich) {
    state = state.copyWith(autoEnrichOnImport: autoEnrich);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void setArchiveBackend(ArchiveBackend backend) {
    state = state.copyWith(archiveBackend: backend);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }
}
