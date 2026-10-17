import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/repositories/saved_item_repository.dart';
import 'package:savedex/data/repositories/settings_repository.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/repositories/collection_repository.dart';
import 'package:savedex/data/services/backup_export_service.dart';
import 'package:savedex/data/services/arctic_shift_api_service.dart';
import 'package:savedex/data/services/pullpush_api_service.dart';
import 'package:savedex/data/services/csv_parser_service.dart';
import 'package:savedex/data/services/reddit_api_service.dart';
import 'package:savedex/data/services/redgifs_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final csvParserServiceProvider = Provider<CsvParserService>((ref) {
  return CsvParserService();
});

final redditApiServiceProvider = Provider<RedditApiService>((ref) {
  final api = RedditApiService();
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final settings = settingsRepo.settings;
  api.updateCredentials(
    clientId: settings.redditClientId,
    clientSecret: settings.redditClientSecret,
    redirectUri: settings.redditRedirectUri,
    userAgent: settings.userAgent,
    refreshToken: settings.redditRefreshToken,
    accessToken: settings.redditAccessToken,
    tokenExpiry: settings.redditTokenExpiry,
  );
  api.onTokenRefreshed = (accessToken, expiresIn) {
    final expiry = DateTime.now().toUtc().add(
      Duration(seconds: (expiresIn - 300).clamp(60, expiresIn)),
    );
    settingsRepo.updateSettings(
      settingsRepo.settings.copyWith(
        redditAccessToken: accessToken,
        redditTokenExpiry: expiry,
      ),
    );
  };
  ref.onDispose(() => api.dispose());
  return api;
});

final arcticShiftApiServiceProvider = Provider<ArcticShiftApiService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider).settings;
  final api = ArcticShiftApiService(userAgent: settings.userAgent);
  ref.onDispose(api.dispose);
  return api;
});

final pullPushApiServiceProvider = Provider<PullPushApiService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider).settings;
  final api = PullPushApiService(userAgent: settings.userAgent);
  ref.onDispose(api.dispose);
  return api;
});

final redgifsApiServiceProvider = Provider<RedGifsApiService>((ref) {
  final api = RedGifsApiService();
  ref.onDispose(api.dispose);
  return api;
});

final backupExportServiceProvider = Provider<BackupExportService>((ref) {
  return BackupExportService();
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CollectionRepository(db);
});

final savedItemRepositoryProvider = Provider<SavedItemRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final parser = ref.watch(csvParserServiceProvider);
  final api = ref.watch(redditApiServiceProvider);
  final arcticShiftApi = ref.watch(arcticShiftApiServiceProvider);
  final pullPushApi = ref.watch(pullPushApiServiceProvider);
  return SavedItemRepository(
    db: db,
    csvParser: parser,
    redditApi: api,
    arcticShiftApi: arcticShiftApi,
    pullPushApi: pullPushApi,
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});

final pendingEnrichmentCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.watchPendingEnrichmentCount();
});

final archiveRecoveryCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.watchArchiveRecoveryCount();
});

final allCollectionsProvider = StreamProvider<List<Collection>>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return repo.watchAllCollections();
});

final itemCollectionsProvider = StreamProvider.family<List<Collection>, String>(
  (ref, itemId) {
    final repo = ref.watch(collectionRepositoryProvider);
    return repo.watchCollectionsForItem(itemId);
  },
);
