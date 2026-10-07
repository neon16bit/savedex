import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/repositories/settings_repository.dart';

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, UserSettings>(() {
      return SettingsViewModel();
    });

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

  void setSeedColorIndex(int index) {
    state = state.copyWith(seedColorIndex: index);
    ref.read(settingsRepositoryProvider).updateSettings(state);
  }

  void toggleDynamicColor(bool useDynamic) {
    state = state.copyWith(useDynamicColor: useDynamic);
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
}
