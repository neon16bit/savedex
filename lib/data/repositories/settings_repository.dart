import 'package:flutter/material.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  final ThemeMode themeMode;
  final int seedColorIndex;
  final bool isAmoled;
  final bool useDynamicColor;
  final FeedLayoutMode feedLayoutMode;
  final String? redditClientId;
  final String? redditClientSecret;
  final String? redditRedirectUri;
  final String? userAgent;
  final String? redditRefreshToken;
  final String? redditAccessToken;
  final DateTime? redditTokenExpiry;
  final String? redditUsername;
  final bool autoEnrichOnImport;

  const UserSettings({
    this.themeMode = ThemeMode.system,
    this.seedColorIndex = 0,
    this.isAmoled = false,
    this.useDynamicColor = true,
    this.feedLayoutMode = FeedLayoutMode.card,
    this.redditClientId,
    this.redditClientSecret,
    this.redditRedirectUri,
    this.userAgent,
    this.redditRefreshToken,
    this.redditAccessToken,
    this.redditTokenExpiry,
    this.redditUsername,
    this.autoEnrichOnImport = true,
  });

  bool get isAuthenticatedWithOAuth =>
      redditRefreshToken != null && redditRefreshToken!.isNotEmpty;

  Color get currentSeedColor {
    if (seedColorIndex >= 0 && seedColorIndex < AppTheme.presets.length) {
      return AppTheme.presets[seedColorIndex];
    }
    return AppTheme.presets.first;
  }

  UserSettings copyWith({
    ThemeMode? themeMode,
    int? seedColorIndex,
    bool? isAmoled,
    bool? useDynamicColor,
    FeedLayoutMode? feedLayoutMode,
    String? redditClientId,
    String? redditClientSecret,
    String? redditRedirectUri,
    String? userAgent,
    String? redditRefreshToken,
    String? redditAccessToken,
    DateTime? redditTokenExpiry,
    String? redditUsername,
    bool? autoEnrichOnImport,
    bool clearOAuthTokens = false,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      seedColorIndex: seedColorIndex ?? this.seedColorIndex,
      isAmoled: isAmoled ?? this.isAmoled,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      feedLayoutMode: feedLayoutMode ?? this.feedLayoutMode,
      redditClientId: redditClientId ?? this.redditClientId,
      redditClientSecret: redditClientSecret ?? this.redditClientSecret,
      redditRedirectUri: redditRedirectUri ?? this.redditRedirectUri,
      userAgent: userAgent ?? this.userAgent,
      redditRefreshToken: clearOAuthTokens
          ? null
          : (redditRefreshToken ?? this.redditRefreshToken),
      redditAccessToken: clearOAuthTokens
          ? null
          : (redditAccessToken ?? this.redditAccessToken),
      redditTokenExpiry: clearOAuthTokens
          ? null
          : (redditTokenExpiry ?? this.redditTokenExpiry),
      redditUsername: clearOAuthTokens
          ? null
          : (redditUsername ?? this.redditUsername),
      autoEnrichOnImport: autoEnrichOnImport ?? this.autoEnrichOnImport,
    );
  }
}

class SettingsRepository {
  final SharedPreferences? _prefs;
  late UserSettings _settings;
  Future<void> _writeQueue = Future.value();

  SettingsRepository([this._prefs]) {
    _settings = _loadSettings();
  }

  UserSettings get settings => _settings;

  UserSettings _loadSettings() {
    if (_prefs == null) return const UserSettings();

    final themeModeIndex =
        _prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    final themeMode =
        ThemeMode.values.elementAtOrNull(themeModeIndex) ?? ThemeMode.system;

    final seedColorIndex = _prefs.getInt('seed_color_index') ?? 0;
    final isAmoled = _prefs.getBool('is_amoled') ?? false;
    final useDynamicColor = _prefs.getBool('use_dynamic_color') ?? true;

    final feedLayoutIndex =
        _prefs.getInt('feed_layout_mode') ?? FeedLayoutMode.card.index;
    final feedLayoutMode =
        FeedLayoutMode.values.elementAtOrNull(feedLayoutIndex) ??
        FeedLayoutMode.card;

    final redditClientId = _prefs.getString('reddit_client_id');
    final redditClientSecret = _prefs.getString('reddit_client_secret');
    final redditRedirectUri = _prefs.getString('reddit_redirect_uri');
    final userAgent = _prefs.getString('user_agent');
    final redditRefreshToken = _prefs.getString('reddit_refresh_token');
    final redditAccessToken = _prefs.getString('reddit_access_token');
    final tokenExpiryMillis = _prefs.getInt('reddit_token_expiry');
    final redditTokenExpiry = tokenExpiryMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(tokenExpiryMillis, isUtc: true)
        : null;
    final redditUsername = _prefs.getString('reddit_username');
    final autoEnrich = _prefs.getBool('auto_enrich_on_import') ?? true;

    return UserSettings(
      themeMode: themeMode,
      seedColorIndex: seedColorIndex,
      isAmoled: isAmoled,
      useDynamicColor: useDynamicColor,
      feedLayoutMode: feedLayoutMode,
      redditClientId: redditClientId,
      redditClientSecret: redditClientSecret,
      redditRedirectUri: redditRedirectUri,
      userAgent: userAgent,
      redditRefreshToken: redditRefreshToken,
      redditAccessToken: redditAccessToken,
      redditTokenExpiry: redditTokenExpiry,
      redditUsername: redditUsername,
      autoEnrichOnImport: autoEnrich,
    );
  }

  Future<void> updateSettings(UserSettings newSettings) {
    _settings = newSettings;
    if (_prefs == null) return Future.value();

    return _writeQueue = _writeQueue
        .then((_) => _persistSettings(newSettings))
        .catchError((e) {
          debugPrint('[SettingsRepository] Error persisting settings: $e');
        });
  }

  Future<void> _persistSettings(UserSettings newSettings) async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setInt('theme_mode', newSettings.themeMode.index);
    await prefs.setInt('seed_color_index', newSettings.seedColorIndex);
    await prefs.setBool('is_amoled', newSettings.isAmoled);
    await prefs.setBool('use_dynamic_color', newSettings.useDynamicColor);
    await prefs.setInt('feed_layout_mode', newSettings.feedLayoutMode.index);

    if (newSettings.redditClientId != null &&
        newSettings.redditClientId!.isNotEmpty) {
      await prefs.setString('reddit_client_id', newSettings.redditClientId!);
    } else {
      await prefs.remove('reddit_client_id');
    }

    if (newSettings.redditClientSecret != null &&
        newSettings.redditClientSecret!.isNotEmpty) {
      await prefs.setString(
        'reddit_client_secret',
        newSettings.redditClientSecret!,
      );
    } else {
      await prefs.remove('reddit_client_secret');
    }

    if (newSettings.redditRedirectUri != null &&
        newSettings.redditRedirectUri!.isNotEmpty) {
      await prefs.setString(
        'reddit_redirect_uri',
        newSettings.redditRedirectUri!,
      );
    } else {
      await prefs.remove('reddit_redirect_uri');
    }

    if (newSettings.userAgent != null && newSettings.userAgent!.isNotEmpty) {
      await prefs.setString('user_agent', newSettings.userAgent!);
    } else {
      await prefs.remove('user_agent');
    }

    if (newSettings.redditRefreshToken != null &&
        newSettings.redditRefreshToken!.isNotEmpty) {
      await prefs.setString(
        'reddit_refresh_token',
        newSettings.redditRefreshToken!,
      );
    } else {
      await prefs.remove('reddit_refresh_token');
    }

    if (newSettings.redditAccessToken != null &&
        newSettings.redditAccessToken!.isNotEmpty) {
      await prefs.setString(
        'reddit_access_token',
        newSettings.redditAccessToken!,
      );
    } else {
      await prefs.remove('reddit_access_token');
    }

    if (newSettings.redditTokenExpiry != null) {
      await prefs.setInt(
        'reddit_token_expiry',
        newSettings.redditTokenExpiry!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove('reddit_token_expiry');
    }

    if (newSettings.redditUsername != null &&
        newSettings.redditUsername!.isNotEmpty) {
      await prefs.setString('reddit_username', newSettings.redditUsername!);
    } else {
      await prefs.remove('reddit_username');
    }

    await prefs.setBool(
      'auto_enrich_on_import',
      newSettings.autoEnrichOnImport,
    );
  }

  Future<void> updateOAuthTokens({
    required String accessToken,
    required int expiresIn,
  }) {
    final expiry = DateTime.now().toUtc().add(
      Duration(seconds: expiresIn - 60),
    );
    _settings = _settings.copyWith(
      redditAccessToken: accessToken,
      redditTokenExpiry: expiry,
    );
    final prefs = _prefs;
    if (prefs == null) return Future.value();

    return _writeQueue = _writeQueue
        .then((_) async {
          await prefs.setString('reddit_access_token', accessToken);
          await prefs.setInt(
            'reddit_token_expiry',
            expiry.millisecondsSinceEpoch,
          );
        })
        .catchError((e) {
          debugPrint('[SettingsRepository] Error updating OAuth tokens: $e');
        });
  }
}
