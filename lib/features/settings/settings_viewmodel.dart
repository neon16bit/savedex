import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/repositories/settings_repository.dart';
import 'package:savedex/data/services/reddit_api_service.dart';
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
    if (mode == state.themeMode) return;
    _commitSettings(state.copyWith(themeMode: mode));
  }

  void setThemeFlavor(ThemeFlavor flavor) {
    final nextState = switch (flavor) {
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
    if (nextState.themeMode == state.themeMode &&
        nextState.catppuccinLightFlavor == state.catppuccinLightFlavor &&
        nextState.catppuccinDarkFlavor == state.catppuccinDarkFlavor) {
      return;
    }
    _commitSettings(nextState);
  }

  void toggleDynamicColor(bool useDynamic) {
    if (useDynamic == state.useDynamicColor) return;
    _commitSettings(state.copyWith(useDynamicColor: useDynamic));
  }

  void setCatppuccinLightFlavor(CatppuccinFlavor flavor) {
    if (flavor == state.catppuccinLightFlavor) return;
    _commitSettings(state.copyWith(catppuccinLightFlavor: flavor));
  }

  void setCatppuccinDarkFlavor(CatppuccinFlavor flavor) {
    if (flavor == state.catppuccinDarkFlavor) return;
    _commitSettings(state.copyWith(catppuccinDarkFlavor: flavor));
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
    if (!state.useDynamicColor && accent == state.catppuccinAccent) return;
    _commitSettings(
      state.copyWith(useDynamicColor: false, catppuccinAccent: accent),
    );
  }

  void toggleCatppuccinSeed([bool? value]) {
    final nextValue = value ?? !state.useCatppuccinSeed;
    if (nextValue == state.useCatppuccinSeed) return;
    _commitSettings(state.copyWith(useCatppuccinSeed: nextValue));
  }

  void toggleAmoled(bool isAmoled) {
    if (isAmoled == state.isAmoled) return;
    _commitSettings(state.copyWith(isAmoled: isAmoled));
  }

  void setFeedLayoutMode(FeedLayoutMode mode) {
    if (mode == state.feedLayoutMode) return;
    _commitSettings(state.copyWith(feedLayoutMode: mode));
  }

  void toggleStartVideosMuted(bool val) {
    if (val == state.startVideosMuted) return;
    _commitSettings(state.copyWith(startVideosMuted: val));
  }

  void toggleHideNsfwInFeed([bool? value]) {
    final nextValue = value ?? !state.hideNsfwInFeed;
    if (nextValue == state.hideNsfwInFeed) return;
    _commitSettings(state.copyWith(hideNsfwInFeed: nextValue));
  }

  void toggleFrostedEffects([bool? value]) {
    final nextValue = value ?? !state.enableFrostedEffects;
    if (nextValue == state.enableFrostedEffects) return;
    _commitSettings(state.copyWith(enableFrostedEffects: nextValue));
  }

  void setHasSeenOnboarding([bool value = true]) {
    if (value == state.hasSeenOnboarding) return;
    _commitSettings(state.copyWith(hasSeenOnboarding: value));
  }

  void _commitSettings(UserSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).updateSettings(next);
  }

  void setPullToRefreshPages(int pages) {
    final clamped = pages.clamp(1, 10);
    if (clamped == state.pullToRefreshPages) return;
    _commitSettings(state.copyWith(pullToRefreshPages: clamped));
  }

  void setOauthEnrichmentWorkers(int workers) {
    final clamped = workers.clamp(1, 10);
    if (clamped == state.oauthEnrichmentWorkers) return;
    _commitSettings(state.copyWith(oauthEnrichmentWorkers: clamped));
  }

  void setOauthEnrichmentDelayMs(int delayMs) {
    final clamped = delayMs.clamp(0, 1000);
    if (clamped == state.oauthEnrichmentDelayMs) return;
    _commitSettings(state.copyWith(oauthEnrichmentDelayMs: clamped));
  }

  void setAnonymousRequestDelayMs(int delayMs) {
    final clamped = delayMs.clamp(200, 3000);
    if (clamped == state.anonymousRequestDelayMs) return;
    _commitSettings(state.copyWith(anonymousRequestDelayMs: clamped));
  }

  void setSubredditMetadataDelayMs(int delayMs) {
    final clamped = delayMs.clamp(0, 2000);
    if (clamped == state.subredditMetadataDelayMs) return;
    _commitSettings(state.copyWith(subredditMetadataDelayMs: clamped));
  }

  void setArchiveBatchDelayMs(int delayMs) {
    final clamped = delayMs.clamp(0, 5000);
    if (clamped == state.archiveBatchDelayMs) return;
    _commitSettings(state.copyWith(archiveBatchDelayMs: clamped));
  }

  void setPullPushRequestDelayMs(int delayMs) {
    final clamped = delayMs.clamp(0, 3000);
    if (clamped == state.pullPushRequestDelayMs) return;
    _commitSettings(state.copyWith(pullPushRequestDelayMs: clamped));
  }

  void setArcticShiftRequestDelayMs(int delayMs) {
    final clamped = delayMs.clamp(0, 3000);
    if (clamped == state.arcticShiftRequestDelayMs) return;
    _commitSettings(state.copyWith(arcticShiftRequestDelayMs: clamped));
  }

  void resetRateLimitsToDefaults() {
    if (state.oauthEnrichmentWorkers ==
            UserSettings.defaultOauthEnrichmentWorkers &&
        state.oauthEnrichmentDelayMs ==
            UserSettings.defaultOauthEnrichmentDelayMs &&
        state.anonymousRequestDelayMs ==
            UserSettings.defaultAnonymousRequestDelayMs &&
        state.subredditMetadataDelayMs ==
            UserSettings.defaultSubredditMetadataDelayMs &&
        state.archiveBatchDelayMs == UserSettings.defaultArchiveBatchDelayMs &&
        state.pullPushRequestDelayMs ==
            UserSettings.defaultPullPushRequestDelayMs &&
        state.arcticShiftRequestDelayMs ==
            UserSettings.defaultArcticShiftRequestDelayMs) {
      return;
    }
    _commitSettings(
      state.copyWith(
        oauthEnrichmentWorkers: UserSettings.defaultOauthEnrichmentWorkers,
        oauthEnrichmentDelayMs: UserSettings.defaultOauthEnrichmentDelayMs,
        anonymousRequestDelayMs: UserSettings.defaultAnonymousRequestDelayMs,
        subredditMetadataDelayMs: UserSettings.defaultSubredditMetadataDelayMs,
        archiveBatchDelayMs: UserSettings.defaultArchiveBatchDelayMs,
        pullPushRequestDelayMs: UserSettings.defaultPullPushRequestDelayMs,
        arcticShiftRequestDelayMs:
            UserSettings.defaultArcticShiftRequestDelayMs,
      ),
    );
  }

  void updateRedditCredentials({
    required String? clientId,
    String? clientSecret,
    required String? redirectUri,
    required String? userAgent,
  }) {
    final trimmedClientId = clientId?.trim();
    final nextClientId = (trimmedClientId == null || trimmedClientId.isEmpty)
        ? null
        : trimmedClientId;
    final trimmedSecret = clientSecret?.trim();
    final nextClientSecret = (trimmedSecret == null || trimmedSecret.isEmpty)
        ? null
        : trimmedSecret;
    final trimmedRedirectUri = redirectUri?.trim();
    final nextRedirectUri =
        (trimmedRedirectUri == null || trimmedRedirectUri.isEmpty)
        ? null
        : trimmedRedirectUri;
    final trimmedUserAgent = userAgent?.trim();
    final nextUserAgent = (trimmedUserAgent == null || trimmedUserAgent.isEmpty)
        ? null
        : trimmedUserAgent;

    _commitSettings(
      state.copyWith(
        redditClientId: nextClientId,
        clearRedditClientId: nextClientId == null,
        redditClientSecret: nextClientSecret,
        clearRedditClientSecret:
            clientSecret != null && nextClientSecret == null,
        redditRedirectUri: nextRedirectUri,
        clearRedditRedirectUri: nextRedirectUri == null,
        userAgent: nextUserAgent,
        clearUserAgent: nextUserAgent == null,
      ),
    );

    ref
        .read(redditApiServiceProvider)
        .updateCredentials(
          clientId: state.redditClientId,
          clearClientId: state.redditClientId == null,
          clientSecret: state.redditClientSecret,
          clearClientSecret: state.redditClientSecret == null,
          redirectUri: state.redditRedirectUri,
          clearRedirectUri: state.redditRedirectUri == null,
          userAgent: state.userAgent,
          clearUserAgent: state.userAgent == null,
        );
  }

  void setOAuthTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) {
    final trimmedRefresh = refreshToken.trim();
    if (trimmedRefresh.isEmpty) return;

    final expiry = DateTime.now().toUtc().add(
      RedditApiService.safeTokenLifetime(expiresIn),
    );
    _commitSettings(
      state.copyWith(
        redditAccessToken: accessToken,
        redditRefreshToken: trimmedRefresh,
        redditTokenExpiry: expiry,
        clearRedditUsername: true,
      ),
    );

    ref
        .read(redditApiServiceProvider)
        .updateCredentials(
          accessToken: accessToken,
          refreshToken: trimmedRefresh,
          tokenExpiry: expiry,
        );
  }

  void saveRefreshedToken(String accessToken, int expiresIn) {
    if (!state.isAuthenticatedWithOAuth) return;
    final expiry = DateTime.now().toUtc().add(
      RedditApiService.safeTokenLifetime(expiresIn),
    );
    _commitSettings(
      state.copyWith(redditAccessToken: accessToken, redditTokenExpiry: expiry),
    );
  }

  void clearOAuthAuth() {
    _commitSettings(state.copyWith(clearOAuthTokens: true));

    ref.read(redditApiServiceProvider).updateCredentials(clearTokens: true);
  }

  void setRedditUsername(String? username) {
    if (username == null || username == state.redditUsername) return;
    _commitSettings(state.copyWith(redditUsername: username));
  }

  void toggleAutoEnrich(bool autoEnrich) {
    if (autoEnrich == state.autoEnrichOnImport) return;
    _commitSettings(state.copyWith(autoEnrichOnImport: autoEnrich));
  }

  void setArchiveBackend(ArchiveBackend backend) {
    if (backend == state.archiveBackend) return;
    _commitSettings(state.copyWith(archiveBackend: backend));
  }
}
