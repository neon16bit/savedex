import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ArchiveBackend {
  automatic('Automatic (PullPush, then Arctic Shift)'),
  pullPush('PullPush'),
  arcticShift('Arctic Shift');

  final String label;
  const ArchiveBackend(this.label);
}

class UserSettings {
  static const int defaultOauthEnrichmentWorkers = 5;
  static const int defaultOauthEnrichmentDelayMs = 50;
  static const int defaultAnonymousRequestDelayMs = 1200;
  static const int defaultSubredditMetadataDelayMs = 250;
  static const int defaultArchiveBatchDelayMs = 1000;
  static const int defaultPullPushRequestDelayMs = 300;
  static const int defaultArcticShiftRequestDelayMs = 600;

  final ThemeMode themeMode;
  final bool isAmoled;
  final bool useDynamicColor;
  final CatppuccinFlavor catppuccinLightFlavor;
  final CatppuccinFlavor catppuccinDarkFlavor;
  final String? catppuccinAccent;
  final bool useCatppuccinSeed;
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
  final ArchiveBackend archiveBackend;
  final bool startVideosMuted;
  final bool hideNsfwInFeed;
  final bool enableFrostedEffects;
  final bool hasSeenOnboarding;
  final int pullToRefreshPages;
  final int oauthEnrichmentWorkers;
  final int oauthEnrichmentDelayMs;
  final int anonymousRequestDelayMs;
  final int subredditMetadataDelayMs;
  final int archiveBatchDelayMs;
  final int pullPushRequestDelayMs;
  final int arcticShiftRequestDelayMs;

  const UserSettings({
    this.themeMode = ThemeMode.system,
    this.isAmoled = false,
    this.useDynamicColor = false,
    this.catppuccinLightFlavor = CatppuccinFlavor.latte,
    this.catppuccinDarkFlavor = CatppuccinFlavor.mocha,
    this.catppuccinAccent,
    this.useCatppuccinSeed = false,
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
    this.archiveBackend = ArchiveBackend.arcticShift,
    this.startVideosMuted = false,
    this.hideNsfwInFeed = false,
    this.enableFrostedEffects = true,
    this.hasSeenOnboarding = false,
    this.pullToRefreshPages = 1,
    this.oauthEnrichmentWorkers = defaultOauthEnrichmentWorkers,
    this.oauthEnrichmentDelayMs = defaultOauthEnrichmentDelayMs,
    this.anonymousRequestDelayMs = defaultAnonymousRequestDelayMs,
    this.subredditMetadataDelayMs = defaultSubredditMetadataDelayMs,
    this.archiveBatchDelayMs = defaultArchiveBatchDelayMs,
    this.pullPushRequestDelayMs = defaultPullPushRequestDelayMs,
    this.arcticShiftRequestDelayMs = defaultArcticShiftRequestDelayMs,
  });

  bool get isAuthenticatedWithOAuth =>
      redditRefreshToken != null &&
      redditRefreshToken!.isNotEmpty &&
      redditClientId != null &&
      redditClientId!.isNotEmpty;

  ThemeFlavor get themeFlavor => switch (themeMode) {
    ThemeMode.system => ThemeFlavor.system,
    ThemeMode.light => ThemeFlavor.latte,
    ThemeMode.dark => switch (catppuccinDarkFlavor) {
      CatppuccinFlavor.frappe => ThemeFlavor.frappe,
      CatppuccinFlavor.macchiato => ThemeFlavor.macchiato,
      CatppuccinFlavor.latte || CatppuccinFlavor.mocha => ThemeFlavor.mocha,
    },
  };

  String effectiveAccentFor(Brightness brightness) {
    if (catppuccinAccent != null && catppuccinAccent!.isNotEmpty) {
      return catppuccinAccent!;
    }
    return brightness == Brightness.light ? 'Maroon' : 'Red';
  }

  UserSettings copyWith({
    ThemeMode? themeMode,
    bool? isAmoled,
    bool? useDynamicColor,
    CatppuccinFlavor? catppuccinLightFlavor,
    CatppuccinFlavor? catppuccinDarkFlavor,
    String? catppuccinAccent,
    bool? useCatppuccinSeed,
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
    ArchiveBackend? archiveBackend,
    bool? startVideosMuted,
    bool? hideNsfwInFeed,
    bool? enableFrostedEffects,
    bool? hasSeenOnboarding,
    int? pullToRefreshPages,
    int? oauthEnrichmentWorkers,
    int? oauthEnrichmentDelayMs,
    int? anonymousRequestDelayMs,
    int? subredditMetadataDelayMs,
    int? archiveBatchDelayMs,
    int? pullPushRequestDelayMs,
    int? arcticShiftRequestDelayMs,
    bool clearOAuthTokens = false,
    bool clearRedditClientId = false,
    bool clearRedditClientSecret = false,
    bool clearRedditRedirectUri = false,
    bool clearUserAgent = false,
    bool clearRedditUsername = false,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      isAmoled: isAmoled ?? this.isAmoled,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      catppuccinLightFlavor:
          catppuccinLightFlavor ?? this.catppuccinLightFlavor,
      catppuccinDarkFlavor: catppuccinDarkFlavor ?? this.catppuccinDarkFlavor,
      catppuccinAccent: catppuccinAccent ?? this.catppuccinAccent,
      useCatppuccinSeed: useCatppuccinSeed ?? this.useCatppuccinSeed,
      feedLayoutMode: feedLayoutMode ?? this.feedLayoutMode,
      redditClientId: clearRedditClientId
          ? null
          : (redditClientId ?? this.redditClientId),
      redditClientSecret: clearRedditClientSecret
          ? null
          : (redditClientSecret ?? this.redditClientSecret),
      redditRedirectUri: clearRedditRedirectUri
          ? null
          : (redditRedirectUri ?? this.redditRedirectUri),
      userAgent: clearUserAgent ? null : (userAgent ?? this.userAgent),
      redditRefreshToken: clearOAuthTokens
          ? null
          : (redditRefreshToken ?? this.redditRefreshToken),
      redditAccessToken: clearOAuthTokens
          ? null
          : (redditAccessToken ?? this.redditAccessToken),
      redditTokenExpiry: clearOAuthTokens
          ? null
          : (redditTokenExpiry ?? this.redditTokenExpiry),
      redditUsername: (clearOAuthTokens || clearRedditUsername)
          ? null
          : (redditUsername ?? this.redditUsername),
      autoEnrichOnImport: autoEnrichOnImport ?? this.autoEnrichOnImport,
      archiveBackend: archiveBackend ?? this.archiveBackend,
      startVideosMuted: startVideosMuted ?? this.startVideosMuted,
      hideNsfwInFeed: hideNsfwInFeed ?? this.hideNsfwInFeed,
      enableFrostedEffects: enableFrostedEffects ?? this.enableFrostedEffects,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      pullToRefreshPages: (pullToRefreshPages ?? this.pullToRefreshPages).clamp(
        1,
        10,
      ),
      oauthEnrichmentWorkers:
          (oauthEnrichmentWorkers ?? this.oauthEnrichmentWorkers).clamp(1, 10),
      oauthEnrichmentDelayMs:
          (oauthEnrichmentDelayMs ?? this.oauthEnrichmentDelayMs).clamp(
            0,
            1000,
          ),
      anonymousRequestDelayMs:
          (anonymousRequestDelayMs ?? this.anonymousRequestDelayMs).clamp(
            200,
            3000,
          ),
      subredditMetadataDelayMs:
          (subredditMetadataDelayMs ?? this.subredditMetadataDelayMs).clamp(
            0,
            2000,
          ),
      archiveBatchDelayMs: (archiveBatchDelayMs ?? this.archiveBatchDelayMs)
          .clamp(0, 5000),
      pullPushRequestDelayMs:
          (pullPushRequestDelayMs ?? this.pullPushRequestDelayMs).clamp(
            0,
            3000,
          ),
      arcticShiftRequestDelayMs:
          (arcticShiftRequestDelayMs ?? this.arcticShiftRequestDelayMs).clamp(
            0,
            3000,
          ),
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

    final isAmoled = _prefs.getBool('is_amoled') ?? false;
    final useDynamicColor = _prefs.getBool('use_dynamic_color') ?? false;

    final catppuccinLightFlavorIndex =
        _prefs.getInt('catppuccin_light_flavor') ??
        CatppuccinFlavor.latte.index;
    final catppuccinLightFlavor =
        CatppuccinFlavor.values.elementAtOrNull(catppuccinLightFlavorIndex) ??
        CatppuccinFlavor.latte;

    final catppuccinDarkFlavorIndex =
        _prefs.getInt('catppuccin_dark_flavor') ?? CatppuccinFlavor.mocha.index;
    final catppuccinDarkFlavor =
        CatppuccinFlavor.values.elementAtOrNull(catppuccinDarkFlavorIndex) ??
        CatppuccinFlavor.mocha;

    final rawCatppuccinAccent = _prefs.getString('catppuccin_accent');
    final String? catppuccinAccent = rawCatppuccinAccent == null
        ? null
        : CatppuccinPalette.accentNames
              .where(
                (name) =>
                    name.toLowerCase() == rawCatppuccinAccent.toLowerCase(),
              )
              .firstOrNull;
    final useCatppuccinSeed = _prefs.getBool('use_catppuccin_seed') ?? false;

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
    final archiveBackendIndex =
        _prefs.getInt('archive_backend') ?? ArchiveBackend.arcticShift.index;
    final archiveBackend =
        ArchiveBackend.values.elementAtOrNull(archiveBackendIndex) ??
        ArchiveBackend.arcticShift;
    final startVideosMuted = _prefs.getBool('start_videos_muted') ?? false;
    final hideNsfwInFeed = _prefs.getBool('hide_nsfw_in_feed') ?? false;
    final enableFrostedEffects =
        _prefs.getBool('enable_frosted_effects') ?? true;
    final hasSeenOnboarding = _prefs.getBool('has_seen_onboarding') ?? false;
    final pullToRefreshPages = (_prefs.getInt('pull_to_refresh_pages') ?? 1)
        .clamp(1, 10);
    final oauthEnrichmentWorkers =
        (_prefs.getInt('oauth_enrichment_workers') ??
                UserSettings.defaultOauthEnrichmentWorkers)
            .clamp(1, 10);
    final oauthEnrichmentDelayMs =
        (_prefs.getInt('oauth_enrichment_delay_ms') ??
                UserSettings.defaultOauthEnrichmentDelayMs)
            .clamp(0, 1000);
    final anonymousRequestDelayMs =
        (_prefs.getInt('anonymous_request_delay_ms') ??
                UserSettings.defaultAnonymousRequestDelayMs)
            .clamp(200, 3000);
    final subredditMetadataDelayMs =
        (_prefs.getInt('subreddit_metadata_delay_ms') ??
                UserSettings.defaultSubredditMetadataDelayMs)
            .clamp(0, 2000);
    final archiveBatchDelayMs =
        (_prefs.getInt('archive_batch_delay_ms') ??
                UserSettings.defaultArchiveBatchDelayMs)
            .clamp(0, 5000);
    final pullPushRequestDelayMs =
        (_prefs.getInt('pullpush_request_delay_ms') ??
                UserSettings.defaultPullPushRequestDelayMs)
            .clamp(0, 3000);
    final arcticShiftRequestDelayMs =
        (_prefs.getInt('arctic_shift_request_delay_ms') ??
                UserSettings.defaultArcticShiftRequestDelayMs)
            .clamp(0, 3000);

    return UserSettings(
      themeMode: themeMode,
      isAmoled: isAmoled,
      useDynamicColor: useDynamicColor,
      catppuccinLightFlavor: catppuccinLightFlavor,
      catppuccinDarkFlavor: catppuccinDarkFlavor,
      catppuccinAccent: catppuccinAccent,
      useCatppuccinSeed: useCatppuccinSeed,
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
      archiveBackend: archiveBackend,
      startVideosMuted: startVideosMuted,
      hideNsfwInFeed: hideNsfwInFeed,
      enableFrostedEffects: enableFrostedEffects,
      hasSeenOnboarding: hasSeenOnboarding,
      pullToRefreshPages: pullToRefreshPages,
      oauthEnrichmentWorkers: oauthEnrichmentWorkers,
      oauthEnrichmentDelayMs: oauthEnrichmentDelayMs,
      anonymousRequestDelayMs: anonymousRequestDelayMs,
      subredditMetadataDelayMs: subredditMetadataDelayMs,
      archiveBatchDelayMs: archiveBatchDelayMs,
      pullPushRequestDelayMs: pullPushRequestDelayMs,
      arcticShiftRequestDelayMs: arcticShiftRequestDelayMs,
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
    await prefs.setBool('is_amoled', newSettings.isAmoled);
    await prefs.setBool('use_dynamic_color', newSettings.useDynamicColor);
    await prefs.setInt(
      'catppuccin_light_flavor',
      newSettings.catppuccinLightFlavor.index,
    );
    await prefs.setInt(
      'catppuccin_dark_flavor',
      newSettings.catppuccinDarkFlavor.index,
    );
    if (newSettings.catppuccinAccent != null &&
        newSettings.catppuccinAccent!.isNotEmpty) {
      await prefs.setString('catppuccin_accent', newSettings.catppuccinAccent!);
    } else {
      await prefs.remove('catppuccin_accent');
    }
    await prefs.setBool('use_catppuccin_seed', newSettings.useCatppuccinSeed);
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
    await prefs.setInt('archive_backend', newSettings.archiveBackend.index);
    await prefs.setBool('start_videos_muted', newSettings.startVideosMuted);
    await prefs.setBool('hide_nsfw_in_feed', newSettings.hideNsfwInFeed);
    await prefs.setBool(
      'enable_frosted_effects',
      newSettings.enableFrostedEffects,
    );
    await prefs.setBool('has_seen_onboarding', newSettings.hasSeenOnboarding);
    await prefs.setInt(
      'pull_to_refresh_pages',
      newSettings.pullToRefreshPages.clamp(1, 10),
    );
    await prefs.setInt(
      'oauth_enrichment_workers',
      newSettings.oauthEnrichmentWorkers.clamp(1, 10),
    );
    await prefs.setInt(
      'oauth_enrichment_delay_ms',
      newSettings.oauthEnrichmentDelayMs.clamp(0, 1000),
    );
    await prefs.setInt(
      'anonymous_request_delay_ms',
      newSettings.anonymousRequestDelayMs.clamp(200, 3000),
    );
    await prefs.setInt(
      'subreddit_metadata_delay_ms',
      newSettings.subredditMetadataDelayMs.clamp(0, 2000),
    );
    await prefs.setInt(
      'archive_batch_delay_ms',
      newSettings.archiveBatchDelayMs.clamp(0, 5000),
    );
    await prefs.setInt(
      'pullpush_request_delay_ms',
      newSettings.pullPushRequestDelayMs.clamp(0, 3000),
    );
    await prefs.setInt(
      'arctic_shift_request_delay_ms',
      newSettings.arcticShiftRequestDelayMs.clamp(0, 3000),
    );
  }
}
