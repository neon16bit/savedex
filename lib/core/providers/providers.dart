import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

final packageInfoProvider = Provider<PackageInfo?>((ref) => null);

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
    ref
        .read(settingsViewModelProvider.notifier)
        .saveRefreshedToken(accessToken, expiresIn);
  };
  ref.onDispose(() {
    api.onTokenRefreshed = null;
    api.dispose();
  });
  return api;
});

final arcticShiftApiServiceProvider = Provider<ArcticShiftApiService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final api = ArcticShiftApiService(
    userAgentProvider: () => settingsRepo.settings.userAgent,
  );
  ref.onDispose(api.dispose);
  return api;
});

final pullPushApiServiceProvider = Provider<PullPushApiService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final api = PullPushApiService(
    userAgentProvider: () => settingsRepo.settings.userAgent,
  );
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

final archiveUnavailableCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.watchArchiveUnavailableCount();
});

final allCollectionsProvider = StreamProvider<List<Collection>>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return repo.watchAllCollections();
});

final itemCollectionsProvider = StreamProvider.autoDispose
    .family<List<Collection>, String>((ref, itemId) {
      final repo = ref.watch(collectionRepositoryProvider);
      return repo.watchCollectionsForItem(itemId);
    });

class ItemCollectionsOverrideNotifier
    extends Notifier<Map<String, List<Collection>>> {
  @override
  Map<String, List<Collection>> build() => const {};

  void setCollections(String itemId, List<Collection> collections) {
    state = {...state, itemId: collections};
  }

  void clear() {
    if (state.isNotEmpty) {
      state = const {};
    }
  }
}

final itemCollectionsOverrideProvider =
    NotifierProvider<
      ItemCollectionsOverrideNotifier,
      Map<String, List<Collection>>
    >(ItemCollectionsOverrideNotifier.new);
