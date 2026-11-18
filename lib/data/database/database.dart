import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/tables/collections_table.dart';
import 'package:savedex/data/database/tables/saved_items_table.dart';
import 'package:savedex/data/database/tables/subreddits_table.dart';
import 'package:savedex/data/models/author_info.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/models/subreddit_info.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    SavedItemsTable,
    CollectionsTable,
    ItemCollectionsTable,
    SubredditsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._([QueryExecutor? e]) : super(e ?? _openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  factory AppDatabase([QueryExecutor? e]) {
    if (e != null) {
      return AppDatabase._(e);
    }
    return instance;
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbDir = await getApplicationSupportDirectory();
      final file = File(p.join(dbDir.path, 'savedex_db.sqlite'));
      final cachebase = (await getTemporaryDirectory()).path;
      sqlite3.tempDirectory = cachebase;

      return NativeDatabase.createInBackground(
        file,
        readPool: 2,
        setup: (rawDb) {
          rawDb.execute('PRAGMA journal_mode = WAL;');
          rawDb.execute('PRAGMA synchronous = NORMAL;');
          rawDb.execute('PRAGMA cache_size = -12000;');
          rawDb.execute('PRAGMA mmap_size = 67108864;');
          rawDb.execute('PRAGMA temp_store = MEMORY;');
          rawDb.execute('PRAGMA foreign_keys = ON;');
          rawDb.execute('PRAGMA busy_timeout = 5000;');
          rawDb.execute('PRAGMA analysis_limit = 1000;');
        },
      );
    });
  }

  bool _dbOpened = false;
  int _collectionsCacheEpoch = 0;
  Map<int, Collection>? _collectionsByIdCache;
  StreamSubscription<Set<TableUpdate>>? _collectionsCacheSub;

  void invalidateCollectionsCache() {
    _collectionsCacheEpoch++;
    _collectionsByIdCache = null;
  }

  Future<Map<int, Collection>> _getCollectionsByIdMap() async {
    final cached = _collectionsByIdCache;
    if (cached != null) return cached;

    late Map<int, Collection> map;
    for (var attempt = 0; attempt < 2; attempt++) {
      final epoch = _collectionsCacheEpoch;
      final entries = await select(collectionsTable).get();
      map = <int, Collection>{
        for (final e in entries)
          e.id: Collection(
            id: e.id,
            name: e.name,
            description: e.description,
            colorValue: e.colorValue,
            createdAtUtc: e.createdAtUtc,
          ),
      };
      if (epoch == _collectionsCacheEpoch) {
        _collectionsByIdCache = map;
        return map;
      }
    }
    return map;
  }

  Future<void> runAnalyzeIfNonEmpty() async {
    try {
      final hasRows = await customSelect(
        'SELECT 1 FROM saved_items_table LIMIT 1',
      ).getSingleOrNull();
      if (hasRows == null) return;
      await customStatement('PRAGMA analysis_limit = 1000;');
      await customStatement('ANALYZE;');
    } catch (e) {
      debugPrint('[Database] Analyze note: $e');
    }
  }

  final StreamController<bool> _subredditMetadataChanges =
      StreamController<bool>.broadcast();
  final StreamController<bool> _authorMetadataChanges =
      StreamController<bool>.broadcast();
  final StreamController<bool> _authorItemsChanged =
      StreamController<bool>.broadcast();

  Stream<bool> get subredditMetadataChanges => _subredditMetadataChanges.stream;
  Stream<bool> get authorMetadataChanges => _authorMetadataChanges.stream;
  Stream<void> get authorItemsChanged => _authorItemsChanged.stream;

  void notifyAuthorItemsChanged() {
    if (!_authorItemsChanged.isClosed) {
      _authorItemsChanged.add(false);
    }
  }

  @override
  Future<void> close() async {
    await _collectionsCacheSub?.cancel();
    _collectionsCacheSub = null;
    invalidateCollectionsCache();
    if (_dbOpened) {
      try {
        await customStatement('PRAGMA analysis_limit = 1000;');
        await customStatement('PRAGMA optimize;');
      } catch (_) {}
    }
    await _subredditMetadataChanges.close();
    await _authorMetadataChanges.close();
    await _authorItemsChanged.close();
    await super.close();
  }

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createFts5(this);
      await _createIndexes(this);
      _ftsInitFuture = Future.value();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(savedItemsTable, savedItemsTable.postFlair);
        await m.addColumn(savedItemsTable, savedItemsTable.subredditType);
        await _rebuildFts(this);
      }
      if (from < 3) {
        await _createIndexes(this);
      }
      if (from < 4) {
        await _rebuildFts(this);
      }
      if (from < 5) {
        await _createIndexes(this);
      }
      if (from < 6) {
        await customStatement('DROP TABLE IF EXISTS item_tags_table;');
        await customStatement('DROP TABLE IF EXISTS tags_table;');
        await m.createTable(collectionsTable);
        await m.createTable(itemCollectionsTable);
      }
      if (from < 7) {
        await m.addColumn(savedItemsTable, savedItemsTable.isArchiveRecovered);
      }
      if (from < 8) {
        await m.addColumn(savedItemsTable, savedItemsTable.galleryImages);
      }
      if (from < 9) {
        await m.addColumn(
          savedItemsTable,
          savedItemsTable.galleryPreviewImages,
        );
      }
      if (from < 10) {
        await m.createTable(subredditsTable);
      }
      if (from < 11) {
        await _createIndexes(this);
        await _createFts5(this);
        _ftsInitFuture = Future.value();
      }
      if (from < 12) {
        await customStatement('DROP INDEX IF EXISTS idx_saved_order_asc;');
        await customStatement(
          'DROP INDEX IF EXISTS idx_saved_archived_order_asc;',
        );
        await customStatement(
          'DROP INDEX IF EXISTS idx_saved_archived_date_asc;',
        );
        await customStatement('DROP INDEX IF EXISTS idx_saved_date_asc;');
        await customStatement('DROP INDEX IF EXISTS idx_saved_score_asc;');
        await customStatement('DROP INDEX IF EXISTS idx_saved_starred_asc;');
        await _rebuildFts(this);
      }
      if (from < 13) {
        await m.addColumn(
          savedItemsTable,
          savedItemsTable.isArchiveUnavailable,
        );
        await customStatement(
          'DROP INDEX IF EXISTS idx_saved_archive_recovery;',
        );
      }
      if (from < 14) {
        await customStatement('''
          UPDATE saved_items_table
          SET subreddit = CASE
            WHEN SUBSTR(TRIM(subreddit), 1, 2) COLLATE NOCASE = 'u/' THEN
              CASE
                WHEN LENGTH(TRIM(SUBSTR(TRIM(subreddit), 3))) > 0
                  THEN 'u_' || TRIM(SUBSTR(TRIM(subreddit), 3))
                ELSE 'reddit'
              END
            WHEN SUBSTR(TRIM(subreddit), 1, 3) COLLATE NOCASE = '/u/' THEN
              CASE
                WHEN LENGTH(TRIM(SUBSTR(TRIM(subreddit), 4))) > 0
                  THEN 'u_' || TRIM(SUBSTR(TRIM(subreddit), 4))
                ELSE 'reddit'
              END
            WHEN SUBSTR(TRIM(subreddit), 1, 2) COLLATE NOCASE = 'r/' THEN
              COALESCE(NULLIF(TRIM(SUBSTR(TRIM(subreddit), 3)), ''), 'reddit')
            WHEN SUBSTR(TRIM(subreddit), 1, 3) COLLATE NOCASE = '/r/' THEN
              COALESCE(NULLIF(TRIM(SUBSTR(TRIM(subreddit), 4)), ''), 'reddit')
            ELSE COALESCE(NULLIF(TRIM(subreddit), ''), 'reddit')
          END
          WHERE subreddit != TRIM(subreddit)
             OR SUBSTR(TRIM(subreddit), 1, 2) COLLATE NOCASE IN ('u/', 'r/')
             OR SUBSTR(TRIM(subreddit), 1, 3) COLLATE NOCASE IN ('/u/', '/r/')
             OR TRIM(subreddit) = '';
        ''');
        await customStatement('''
          UPDATE saved_items_table
          SET author = NULLIF(
            TRIM(
              CASE
                WHEN SUBSTR(TRIM(author), 1, 2) COLLATE NOCASE IN ('u/', 'r/')
                  THEN TRIM(SUBSTR(TRIM(author), 3))
                WHEN SUBSTR(TRIM(author), 1, 3) COLLATE NOCASE IN ('/u/', '/r/')
                  THEN TRIM(SUBSTR(TRIM(author), 4))
                ELSE TRIM(author)
              END
            ),
            ''
          )
          WHERE author IS NOT NULL
            AND (
              author = ''
              OR author != TRIM(author)
              OR SUBSTR(TRIM(author), 1, 2) COLLATE NOCASE IN ('u/', 'r/')
              OR SUBSTR(TRIM(author), 1, 3) COLLATE NOCASE IN ('/u/', '/r/')
            );
        ''');
      }
      await _createIndexes(this);
      await runAnalyzeIfNonEmpty();
      _ftsInitFuture = Future.value();
    },
    beforeOpen: (details) async {
      _dbOpened = true;
      _collectionsCacheSub ??= tableUpdates(
        TableUpdateQuery.onAllTables([collectionsTable]),
      ).listen((_) => invalidateCollectionsCache());
    },
  );

  static String _cleanSubSql(String colExpr) =>
      "LOWER(CASE WHEN $colExpr LIKE 'r/%' THEN SUBSTR($colExpr, 3) WHEN $colExpr LIKE 'u/%' THEN 'u_' || SUBSTR($colExpr, 3) ELSE $colExpr END)";

  static String _buildEffectiveNsfwSql(String alias) =>
      "($alias.is_nsfw = 1 OR EXISTS (SELECT 1 FROM subreddits_table sub WHERE sub.name IN (${_cleanSubSql('$alias.subreddit')}, 'u_' || LOWER(COALESCE($alias.author, ''))) AND sub.is_nsfw = 1))";

  Future<void>? _ftsInitFuture;

  Future<void> ensureFtsSchema() {
    return _ftsInitFuture ??= () async {
      try {
        await _createFts5(this);
      } catch (e) {
        _ftsInitFuture = null;
        rethrow;
      }
    }();
  }

  static Future<void> _createIndexes(AppDatabase db) async {
    try {
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_order_desc ON saved_items_table (import_order DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_archived_order_desc ON saved_items_table (is_archived, import_order DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_archived_date_desc ON saved_items_table (is_archived, COALESCE(created_at_utc, 0) DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_starred_desc ON saved_items_table (import_order DESC, id DESC) WHERE is_starred = 1;
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_date_desc ON saved_items_table (COALESCE(created_at_utc, 0) DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_score_desc ON saved_items_table (score DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_sub_nocase ON saved_items_table (subreddit COLLATE NOCASE, id);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_author_nocase ON saved_items_table (COALESCE(author, '') COLLATE NOCASE, id);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_title_nocase ON saved_items_table (title COLLATE NOCASE, id);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_comments_desc ON saved_items_table (num_comments DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_enrichment_status ON saved_items_table (enrichment_status, import_order ASC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_flair_nocase ON saved_items_table (post_flair COLLATE NOCASE);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_item_collections_col_item
        ON item_collections_table (collection_id, item_id);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_archive_recovery
        ON saved_items_table (import_order ASC)
        WHERE is_archive_recovered = 0 AND is_archive_unavailable = 0;
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_sub_counts
        ON saved_items_table (subreddit COLLATE NOCASE, is_nsfw);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_author_counts
        ON saved_items_table (author COLLATE NOCASE)
        WHERE author IS NOT NULL
          AND author != ''
          AND author COLLATE NOCASE NOT IN ('[deleted]', '[removed]', 'deleted', 'removed');
      ''');
    } catch (e, stack) {
      debugPrint('[Database] Create indexes note: $e\n$stack');
    }
  }

  static Future<void> _createFts5(AppDatabase db) async {
    try {
      bool needsRebuild = false;
      try {
        final rows = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE name = 'saved_items_fts' AND type = 'table';",
            )
            .get();
        if (rows.isEmpty ||
            !rows.first
                .read<String>('sql')
                .contains("content='saved_items_table'")) {
          needsRebuild = true;
        }
      } catch (_) {
        needsRebuild = true;
      }

      if (needsRebuild) {
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ai');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ad');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au');
        await db.customStatement('DROP TABLE IF EXISTS saved_items_fts');
      }

      await db.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS saved_items_fts USING fts5(
          title,
          body,
          parent_post_title,
          user_note,
          content='saved_items_table',
          content_rowid='rowid',
          tokenize = 'unicode61'
        );
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_ai AFTER INSERT ON saved_items_table BEGIN
          INSERT INTO saved_items_fts(rowid, title, body, parent_post_title, user_note)
          VALUES (
            new.rowid,
            new.title,
            coalesce(new.body, ''),
            coalesce(new.parent_post_title, ''),
            coalesce(new.user_note, '')
          );
        END;
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_ad AFTER DELETE ON saved_items_table BEGIN
          INSERT INTO saved_items_fts(saved_items_fts, rowid, title, body, parent_post_title, user_note)
          VALUES (
            'delete',
            old.rowid,
            old.title,
            coalesce(old.body, ''),
            coalesce(old.parent_post_title, ''),
            coalesce(old.user_note, '')
          );
        END;
      ''');

      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au;');
      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_au
        AFTER UPDATE OF title, body, parent_post_title, user_note ON saved_items_table
        WHEN old.title != new.title
          OR coalesce(old.body, '') != coalesce(new.body, '')
          OR coalesce(old.parent_post_title, '') != coalesce(new.parent_post_title, '')
          OR coalesce(old.user_note, '') != coalesce(new.user_note, '')
        BEGIN
          INSERT INTO saved_items_fts(saved_items_fts, rowid, title, body, parent_post_title, user_note)
          VALUES (
            'delete',
            old.rowid,
            old.title,
            coalesce(old.body, ''),
            coalesce(old.parent_post_title, ''),
            coalesce(old.user_note, '')
          );
          INSERT INTO saved_items_fts(rowid, title, body, parent_post_title, user_note)
          VALUES (
            new.rowid,
            new.title,
            coalesce(new.body, ''),
            coalesce(new.parent_post_title, ''),
            coalesce(new.user_note, '')
          );
        END;
      ''');

      if (needsRebuild) {
        await db.customStatement(
          "INSERT INTO saved_items_fts(saved_items_fts) VALUES('rebuild');",
        );
      }
    } catch (e, stack) {
      debugPrint('[Database] FTS5 initialization note: $e\n$stack');
      try {
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ai');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ad');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au');
      } catch (_) {}
    }
  }

  static Future<void> _rebuildFts(AppDatabase db) async {
    try {
      db._ftsInitFuture = null;
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ai');
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ad');
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au');
      await db.customStatement('DROP TABLE IF EXISTS saved_items_fts');
      await _createFts5(db);
      db._ftsInitFuture = Future.value();
    } catch (e, stack) {
      debugPrint('[Database] FTS5 rebuild failed: $e\n$stack');
      rethrow;
    }
  }

  Stream<List<SavedItemEntry>> watchFilteredSavedItems({
    String? searchQuery,
    Set<String> subreddits = const {},
    Set<String> authors = const {},
    Set<String> flairs = const {},
    Set<MediaType> mediaTypes = const {},
    ItemType? itemType,
    EnrichmentStatus? enrichmentStatus,
    bool? isNsfw,
    bool? isStarred,
    bool? isArchived,
    Set<int> collectionIds = const {},
    SortOption sortOption = SortOption.savedOrderDesc,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
  }) {
    final query = select(savedItemsTable);

    query.where((tbl) {
      Expression<bool> predicate = const Constant(true);

      if (isArchived != null) {
        predicate = predicate & tbl.isArchived.equals(isArchived);
      }

      if (itemType != null) {
        predicate = predicate & tbl.itemType.equals(itemType.index);
      }

      if (enrichmentStatus != null) {
        predicate =
            predicate & tbl.enrichmentStatus.equals(enrichmentStatus.index);
      }

      if (isNsfw != null) {
        final nsfwExpr = CustomExpression<bool>(
          _buildEffectiveNsfwSql(tbl.actualTableName),
        );
        predicate = predicate & (isNsfw ? nsfwExpr : nsfwExpr.not());
      }

      if (isStarred != null) {
        predicate = predicate & tbl.isStarred.equals(isStarred);
      }

      if (subreddits.isNotEmpty) {
        predicate =
            predicate & tbl.subreddit.collate(Collate.noCase).isIn(subreddits);
      }

      if (authors.isNotEmpty) {
        predicate =
            predicate &
            coalesce([tbl.author, const Constant('')])
                .collate(Collate.noCase)
                .isIn(authors);
      }

      if (flairs.isNotEmpty) {
        predicate = predicate & tbl.postFlair.isIn(flairs);
      }

      if (mediaTypes.isNotEmpty) {
        predicate =
            predicate & tbl.mediaType.isIn(mediaTypes.map((m) => m.index));
      }

      if (dateRangeStart != null) {
        predicate =
            predicate &
            tbl.createdAtUtc.isBiggerOrEqualValue(dateRangeStart.toUtc());
      }

      if (dateRangeEnd != null) {
        final inclusiveEnd =
            (dateRangeEnd.hour == 0 &&
                dateRangeEnd.minute == 0 &&
                dateRangeEnd.second == 0 &&
                dateRangeEnd.millisecond == 0)
            ? DateTime(
                dateRangeEnd.year,
                dateRangeEnd.month,
                dateRangeEnd.day,
                23,
                59,
                59,
                999,
              ).toUtc()
            : dateRangeEnd.toUtc();
        predicate =
            predicate & tbl.createdAtUtc.isSmallerOrEqualValue(inclusiveEnd);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final ftsToken = _sanitizeFtsQuery(searchQuery);
        if (ftsToken != null) {
          final escaped = ftsToken.replaceAll("'", "''");
          predicate =
              predicate &
              CustomExpression<bool>(
                'rowid IN (SELECT rowid FROM saved_items_fts WHERE saved_items_fts MATCH \'$escaped\')',
              );
        }
      }

      return predicate;
    });

    if (collectionIds.isNotEmpty) {
      query.where((tbl) {
        final matchingItemsQuery = selectOnly(itemCollectionsTable)
          ..addColumns([itemCollectionsTable.itemId])
          ..where(itemCollectionsTable.collectionId.isIn(collectionIds));
        return tbl.id.isInQuery(matchingItemsQuery);
      });
    }

    // apply sorting
    query.orderBy([
      (tbl) {
        switch (sortOption) {
          case SortOption.savedOrderDesc:
            return OrderingTerm(
              expression: tbl.importOrder,
              mode: OrderingMode.desc,
            );
          case SortOption.savedOrderAsc:
            return OrderingTerm(
              expression: tbl.importOrder,
              mode: OrderingMode.asc,
            );
          case SortOption.createdDateDesc:
            return OrderingTerm(
              expression: coalesce([
                tbl.createdAtUtc,
                Constant(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
              ]),
              mode: OrderingMode.desc,
            );
          case SortOption.createdDateAsc:
            return OrderingTerm(
              expression: coalesce([
                tbl.createdAtUtc,
                Constant(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
              ]),
              mode: OrderingMode.asc,
            );
          case SortOption.scoreDesc:
            return OrderingTerm(expression: tbl.score, mode: OrderingMode.desc);
          case SortOption.scoreAsc:
            return OrderingTerm(expression: tbl.score, mode: OrderingMode.asc);
          case SortOption.subredditAsc:
            return OrderingTerm(
              expression: tbl.subreddit.collate(Collate.noCase),
              mode: OrderingMode.asc,
            );
          case SortOption.subredditDesc:
            return OrderingTerm(
              expression: tbl.subreddit.collate(Collate.noCase),
              mode: OrderingMode.desc,
            );
          case SortOption.authorAsc:
            return OrderingTerm(
              expression: coalesce([tbl.author, const Constant('')])
                  .collate(Collate.noCase),
              mode: OrderingMode.asc,
            );
          case SortOption.authorDesc:
            return OrderingTerm(
              expression: coalesce([tbl.author, const Constant('')])
                  .collate(Collate.noCase),
              mode: OrderingMode.desc,
            );
          case SortOption.titleAsc:
            return OrderingTerm(
              expression: tbl.title.collate(Collate.noCase),
              mode: OrderingMode.asc,
            );
          case SortOption.commentsDesc:
            return OrderingTerm(
              expression: tbl.numComments,
              mode: OrderingMode.desc,
            );
        }
      },
    ]);

    return query.watch();
  }

  static String? _sanitizeFtsQuery(String? raw) {
    if (raw == null) return null;
    final terms = raw
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'["*]'), ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*')
        .join(' ');
    return terms.isEmpty ? null : terms;
  }

  static FeedCursor _extractCursor(SavedItemEntry entry, SortOption sort) {
    switch (sort) {
      case SortOption.savedOrderDesc:
      case SortOption.savedOrderAsc:
        return FeedCursor(sortValue: entry.importOrder, id: entry.id);
      case SortOption.createdDateDesc:
      case SortOption.createdDateAsc:
        return FeedCursor(
          sortValue: entry.createdAtUtc?.millisecondsSinceEpoch ?? 0,
          id: entry.id,
        );
      case SortOption.scoreDesc:
      case SortOption.scoreAsc:
        return FeedCursor(sortValue: entry.score, id: entry.id);
      case SortOption.subredditAsc:
      case SortOption.subredditDesc:
        return FeedCursor(sortValue: entry.subreddit, id: entry.id);
      case SortOption.authorAsc:
      case SortOption.authorDesc:
        return FeedCursor(sortValue: entry.author ?? '', id: entry.id);
      case SortOption.titleAsc:
        return FeedCursor(sortValue: entry.title, id: entry.id);
      case SortOption.commentsDesc:
        return FeedCursor(sortValue: entry.numComments, id: entry.id);
    }
  }

  static (String, List<Variable>) _buildKeysetRowValue(
    SortOption sort,
    FeedCursor cursor,
  ) {
    switch (sort) {
      case SortOption.savedOrderDesc:
        return (
          '(s.import_order, s.id) < (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.savedOrderAsc:
        return (
          '(s.import_order, s.id) > (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.createdDateDesc:
        return (
          '(COALESCE(s.created_at_utc, 0), s.id) < (?, ?)',
          [
            Variable.withDateTime(
              DateTime.fromMillisecondsSinceEpoch(
                cursor.sortValue as int,
                isUtc: true,
              ),
            ),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.createdDateAsc:
        return (
          '(COALESCE(s.created_at_utc, 0), s.id) > (?, ?)',
          [
            Variable.withDateTime(
              DateTime.fromMillisecondsSinceEpoch(
                cursor.sortValue as int,
                isUtc: true,
              ),
            ),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.scoreDesc:
        return (
          '(s.score, s.id) < (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.scoreAsc:
        return (
          '(s.score, s.id) > (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.subredditAsc:
        return (
          '(s.subreddit COLLATE NOCASE, s.id) > (?, ?)',
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.subredditDesc:
        return (
          '(s.subreddit COLLATE NOCASE, s.id) < (?, ?)',
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.authorAsc:
        return (
          "(COALESCE(s.author, '') COLLATE NOCASE, s.id) > (?, ?)",
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.authorDesc:
        return (
          "(COALESCE(s.author, '') COLLATE NOCASE, s.id) < (?, ?)",
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.titleAsc:
        return (
          '(s.title COLLATE NOCASE, s.id) > (?, ?)',
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.commentsDesc:
        return (
          '(s.num_comments, s.id) < (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
    }
  }

  static String _buildOrderBySql(SortOption sort) {
    switch (sort) {
      case SortOption.savedOrderDesc:
        return 's.import_order DESC, s.id DESC';
      case SortOption.savedOrderAsc:
        return 's.import_order ASC, s.id ASC';
      case SortOption.createdDateDesc:
        return 'COALESCE(s.created_at_utc, 0) DESC, s.id DESC';
      case SortOption.createdDateAsc:
        return 'COALESCE(s.created_at_utc, 0) ASC, s.id ASC';
      case SortOption.scoreDesc:
        return 's.score DESC, s.id DESC';
      case SortOption.scoreAsc:
        return 's.score ASC, s.id ASC';
      case SortOption.subredditAsc:
        return 's.subreddit COLLATE NOCASE ASC, s.id ASC';
      case SortOption.subredditDesc:
        return 's.subreddit COLLATE NOCASE DESC, s.id DESC';
      case SortOption.authorAsc:
        return "COALESCE(s.author, '') COLLATE NOCASE ASC, s.id ASC";
      case SortOption.authorDesc:
        return "COALESCE(s.author, '') COLLATE NOCASE DESC, s.id DESC";
      case SortOption.titleAsc:
        return 's.title COLLATE NOCASE ASC, s.id ASC';
      case SortOption.commentsDesc:
        return 's.num_comments DESC, s.id DESC';
    }
  }

  ({String joinSql, List<String> where, List<Variable> vars})
  _buildFilterQueryParts(FilterCriteria filter) {
    var joinSql = '';
    final where = <String>[];
    final vars = <Variable>[];

    if (filter.isArchived != null) {
      where.add('s.is_archived = ?');
      vars.add(Variable.withBool(filter.isArchived!));
    }
    if (filter.itemType != null) {
      where.add('s.item_type = ?');
      vars.add(Variable.withInt(filter.itemType!.index));
    }
    if (filter.enrichmentStatus != null) {
      where.add('s.enrichment_status = ?');
      vars.add(Variable.withInt(filter.enrichmentStatus!.index));
    }
    if (filter.isNsfw != null) {
      final effectiveNsfw = _buildEffectiveNsfwSql('s');
      where.add(filter.isNsfw! ? effectiveNsfw : 'NOT $effectiveNsfw');
    }
    if (filter.isStarred != null) {
      where.add('s.is_starred = ?');
      vars.add(Variable.withBool(filter.isStarred!));
    }
    if (filter.selectedSubreddits.isNotEmpty) {
      where.add(
        's.subreddit COLLATE NOCASE IN (${List.filled(filter.selectedSubreddits.length, '?').join(',')})',
      );
      vars.addAll(filter.selectedSubreddits.map(Variable.withString));
    }
    if (filter.selectedAuthors.isNotEmpty) {
      where.add(
        "COALESCE(s.author, '') COLLATE NOCASE IN (${List.filled(filter.selectedAuthors.length, '?').join(',')})",
      );
      vars.addAll(filter.selectedAuthors.map(Variable.withString));
    }
    if (filter.selectedFlairs.isNotEmpty) {
      where.add(
        's.post_flair IN (${List.filled(filter.selectedFlairs.length, '?').join(',')})',
      );
      vars.addAll(filter.selectedFlairs.map(Variable.withString));
    }
    if (filter.selectedMediaTypes.isNotEmpty) {
      where.add(
        's.media_type IN (${List.filled(filter.selectedMediaTypes.length, '?').join(',')})',
      );
      vars.addAll(
        filter.selectedMediaTypes.map((m) => Variable.withInt(m.index)),
      );
    }
    if (filter.dateRangeStart != null) {
      where.add('s.created_at_utc >= ?');
      vars.add(Variable.withDateTime(filter.dateRangeStart!.toUtc()));
    }
    if (filter.dateRangeEnd != null) {
      final end = filter.dateRangeEnd!;
      final inclusiveEnd =
          (end.hour == 0 &&
              end.minute == 0 &&
              end.second == 0 &&
              end.millisecond == 0)
          ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999).toUtc()
          : end.toUtc();
      where.add('s.created_at_utc <= ?');
      vars.add(Variable.withDateTime(inclusiveEnd));
    }
    if (filter.selectedCollectionIds.length == 1) {
      // Single-collection scoping avoids ephemeral IN subqueries and lets
      // SQLite choose between idx_item_collections_col_item and order index.
      joinSql = 'INNER JOIN item_collections_table ic ON ic.item_id = s.id';
      where.add('ic.collection_id = ?');
      vars.add(Variable.withInt(filter.selectedCollectionIds.first));
    } else if (filter.selectedCollectionIds.length > 1) {
      where.add(
        'EXISTS (SELECT 1 FROM item_collections_table ic WHERE ic.item_id = s.id AND ic.collection_id IN (${List.filled(filter.selectedCollectionIds.length, '?').join(',')}))',
      );
      vars.addAll(filter.selectedCollectionIds.map(Variable.withInt));
    }
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      final ftsToken = _sanitizeFtsQuery(filter.searchQuery!);
      if (ftsToken != null) {
        where.add(
          's.rowid IN (SELECT rowid FROM saved_items_fts WHERE saved_items_fts MATCH ?)',
        );
        vars.add(Variable.withString(ftsToken));
      }
    }

    return (joinSql: joinSql, where: where, vars: vars);
  }

  Future<({List<QueryRow> rows, bool hasMore})> _querySavedItemsKeysetPage({
    required FilterCriteria filter,
    FeedCursor? cursor,
    int limit = 100,
    bool includeCollectionIds = false,
  }) async {
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      await ensureFtsSchema();
    }
    final parts = _buildFilterQueryParts(filter);
    final where = parts.where;
    final vars = parts.vars;

    if (cursor != null) {
      final (clause, cursorVars) = _buildKeysetRowValue(
        filter.sortOption,
        cursor,
      );
      where.add(clause);
      vars.addAll(cursorVars);
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final orderBy = 'ORDER BY ${_buildOrderBySql(filter.sortOption)}';
    final collectionIdsExpr = includeCollectionIds
        ? ', (SELECT GROUP_CONCAT(ic2.collection_id) FROM item_collections_table ic2 WHERE ic2.item_id = s.id) AS _collection_ids'
        : '';

    vars.add(Variable.withInt(limit + 1));
    final sql =
        '''
      SELECT s.*$collectionIdsExpr
      FROM saved_items_table s
      ${parts.joinSql}
      $whereClause
      $orderBy
      LIMIT ?
    ''';

    final rows = await customSelect(
      sql,
      variables: vars,
      readsFrom: {
        savedItemsTable,
        if (filter.isNsfw != null) subredditsTable,
        if (filter.selectedCollectionIds.isNotEmpty || includeCollectionIds)
          itemCollectionsTable,
      },
    ).get();

    final hasMore = rows.length > limit;
    final pageRawRows = hasMore ? rows.sublist(0, limit) : rows;
    return (rows: pageRawRows, hasMore: hasMore);
  }

  Future<PagedRows<SavedItemEntry>> getSavedItemsKeysetPage({
    required FilterCriteria filter,
    FeedCursor? cursor,
    int limit = 100,
  }) async {
    final result = await _querySavedItemsKeysetPage(
      filter: filter,
      cursor: cursor,
      limit: limit,
    );
    final pageRows = result.rows
        .map((r) => savedItemsTable.map(r.data))
        .toList();

    FeedCursor? nextCursor;
    if (result.hasMore && pageRows.isNotEmpty) {
      nextCursor = _extractCursor(pageRows.last, filter.sortOption);
    }

    return PagedRows(
      items: pageRows,
      nextCursor: nextCursor,
      hasMore: result.hasMore,
    );
  }

  Future<PagedRows<SavedItem>> getSavedItemsPageWithCollections({
    required FilterCriteria filter,
    FeedCursor? cursor,
    int limit = 100,
  }) async {
    final result = await _querySavedItemsKeysetPage(
      filter: filter,
      cursor: cursor,
      limit: limit,
      includeCollectionIds: true,
    );
    if (result.rows.isEmpty) {
      return const PagedRows(items: [], nextCursor: null, hasMore: false);
    }

    var hasAnyCollectionIds = false;
    final parsedIdsPerRow = <List<int>>[];
    for (final row in result.rows) {
      final raw = row.data['_collection_ids'];
      final rawStr = raw is String ? raw : raw?.toString();
      if (rawStr == null || rawStr.isEmpty) {
        parsedIdsPerRow.add(const []);
      } else {
        hasAnyCollectionIds = true;
        final ids = <int>[];
        for (final part in rawStr.split(',')) {
          final cid = int.tryParse(part);
          if (cid != null) ids.add(cid);
        }
        parsedIdsPerRow.add(ids);
      }
    }

    Map<int, Collection> collectionsMap = const {};
    if (hasAnyCollectionIds) {
      collectionsMap = await _getCollectionsByIdMap();
      var needsRefresh = false;
      for (final ids in parsedIdsPerRow) {
        for (final cid in ids) {
          if (!collectionsMap.containsKey(cid)) {
            needsRefresh = true;
            break;
          }
        }
        if (needsRefresh) break;
      }
      if (needsRefresh) {
        invalidateCollectionsCache();
        collectionsMap = await _getCollectionsByIdMap();
      }
    }

    final entries = <SavedItemEntry>[];
    final items = <SavedItem>[];
    for (var i = 0; i < result.rows.length; i++) {
      final entry = savedItemsTable.map(result.rows[i].data);
      entries.add(entry);
      final ids = parsedIdsPerRow[i];
      final itemCollections = ids.isEmpty
          ? const <Collection>[]
          : [
              for (final cid in ids)
                if (collectionsMap[cid] != null) collectionsMap[cid]!,
            ];
      items.add(entry.toDomain(collections: itemCollections));
    }

    final nextCursor = result.hasMore && entries.isNotEmpty
        ? _extractCursor(entries.last, filter.sortOption)
        : null;

    return PagedRows(
      items: items,
      nextCursor: nextCursor,
      hasMore: result.hasMore,
    );
  }

  Future<int> countFilteredSavedItems(FilterCriteria filter) async {
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      await ensureFtsSchema();
    }
    final parts = _buildFilterQueryParts(filter);
    if (filter.isArchived == null &&
        filter.selectedCollectionIds.length == 1 &&
        parts.where.length == 1) {
      final row = await customSelect(
        'SELECT COUNT(*) AS c FROM item_collections_table WHERE collection_id = ?',
        variables: [Variable.withInt(filter.selectedCollectionIds.first)],
        readsFrom: {itemCollectionsTable},
      ).getSingle();
      return row.read<int>('c');
    }

    final whereClause = parts.where.isEmpty
        ? ''
        : 'WHERE ${parts.where.join(' AND ')}';
    final sql =
        'SELECT COUNT(*) AS c FROM saved_items_table s ${parts.joinSql} $whereClause';

    final row = await customSelect(
      sql,
      variables: parts.vars,
      readsFrom: {
        savedItemsTable,
        if (filter.isNsfw != null) subredditsTable,
        if (filter.selectedCollectionIds.isNotEmpty) itemCollectionsTable,
      },
    ).getSingle();

    return row.read<int>('c');
  }

  SavedItemsTableCompanion _normalizeCompanionForStorage(
    SavedItemsTableCompanion entry,
  ) {
    final hasSub = entry.subreddit.present;
    final hasAuthor = entry.author.present;
    if (!hasSub && !hasAuthor) return entry;

    final nextSub = hasSub
        ? SavedItem.normalizeSubredditForStorage(entry.subreddit.value)
        : null;
    final nextAuthor = hasAuthor
        ? SavedItem.normalizeAuthorForStorage(entry.author.value)
        : null;

    final subNeedsUpdate = hasSub && nextSub != entry.subreddit.value;
    final authorNeedsUpdate = hasAuthor && nextAuthor != entry.author.value;
    if (!subNeedsUpdate && !authorNeedsUpdate) return entry;

    return entry.copyWith(
      subreddit: subNeedsUpdate ? Value(nextSub!) : entry.subreddit,
      author: authorNeedsUpdate ? Value(nextAuthor) : entry.author,
    );
  }

  // bulk upsert items nondestructively using ON CONFLICT DO UPDATE
  Future<void> upsertBatch(
    List<SavedItemsTableCompanion> entries, {
    bool runAnalyze = true,
  }) async {
    if (entries.isEmpty) return;
    List<SavedItemsTableCompanion>? normalizedEntries;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final normalized = _normalizeCompanionForStorage(entry);
      if (!identical(normalized, entry)) {
        normalizedEntries ??= List<SavedItemsTableCompanion>.of(entries);
        normalizedEntries[i] = normalized;
      }
    }
    final effectiveEntries = normalizedEntries ?? entries;
    const chunkSize = 500;
    await transaction(() async {
      for (var i = 0; i < effectiveEntries.length; i += chunkSize) {
        final chunk = effectiveEntries.sublist(
          i,
          i + chunkSize > effectiveEntries.length
              ? effectiveEntries.length
              : i + chunkSize,
        );
        await batch((batch) {
          batch.insertAllOnConflictUpdate(savedItemsTable, chunk);
        });
      }
    });
    if (runAnalyze && effectiveEntries.length >= 200) {
      await runAnalyzeIfNonEmpty();
    }
  }

  Future<Map<String, SubredditEntry>> getAllSubredditsMap() async {
    final entries = await select(subredditsTable).get();
    return {for (final e in entries) e.name.toLowerCase(): e};
  }

  Future<Map<String, SubredditEntry>> getSubredditsByNames(
    Iterable<String> names,
  ) async {
    final unique = {
      for (final name in names)
        if (name.isNotEmpty) name.toLowerCase(),
    }.toList(growable: false);
    if (unique.isEmpty) return const {};

    const chunkSize = 500;
    final map = <String, SubredditEntry>{};
    for (var i = 0; i < unique.length; i += chunkSize) {
      final end = (i + chunkSize > unique.length)
          ? unique.length
          : i + chunkSize;
      final chunk = unique.sublist(i, end);
      final entries = await (select(
        subredditsTable,
      )..where((t) => t.name.isIn(chunk))).get();
      for (final e in entries) {
        map[e.name.toLowerCase()] = e;
      }
    }
    return map;
  }

  Future<List<SubredditEntry>> getAllSubreddits() async {
    return select(subredditsTable).get();
  }

  Future<bool> isSubredditNsfw(String subreddit, {String? author}) async {
    final cleanSub = SavedItem.normalizeSubredditKey(subreddit);
    final cleanAuthor = (author ?? '').trim().toLowerCase().replaceFirst(
      RegExp(r'^/?[ru]/'),
      '',
    );
    final keys = <String>[
      if (cleanSub.isNotEmpty) cleanSub,
      if (cleanAuthor.isNotEmpty && !SavedItem.isRemovedMarker(cleanAuthor))
        'u_$cleanAuthor',
    ];
    if (keys.isEmpty) return false;
    final entries = await (select(
      subredditsTable,
    )..where((t) => t.name.isIn(keys) & t.isNsfw.equals(true))).get();
    return entries.isNotEmpty;
  }

  Future<bool?> getSubredditNsfwEntry(String key) async {
    final clean = SavedItem.normalizeSubredditKey(key);
    if (clean.isEmpty) return null;
    final entry = await (select(
      subredditsTable,
    )..where((t) => t.name.equals(clean))).getSingleOrNull();
    return entry?.isNsfw;
  }

  Future<void> upsertSubreddit(
    SubredditsTableCompanion entry, {
    bool isManualOverride = false,
  }) async {
    await into(subredditsTable).insertOnConflictUpdate(entry);
    if (entry.name.present) {
      _emitSubredditMetadataChange([
        entry.name.value,
      ], isManualOverride: isManualOverride);
    }
  }

  Future<void> upsertSubredditsBatch(
    List<SubredditsTableCompanion> entries,
  ) async {
    if (entries.isEmpty) return;
    const chunkSize = 500;
    await transaction(() async {
      for (var i = 0; i < entries.length; i += chunkSize) {
        final chunk = entries.sublist(
          i,
          i + chunkSize > entries.length ? entries.length : i + chunkSize,
        );
        await batch((batch) {
          batch.insertAllOnConflictUpdate(subredditsTable, chunk);
        });
      }
    });
    _emitSubredditMetadataChange([
      for (final e in entries)
        if (e.name.present) e.name.value,
    ]);
  }

  void _emitSubredditMetadataChange(
    Iterable<String> keys, {
    bool isManualOverride = false,
  }) {
    var hasSubreddit = false;
    var hasAuthor = false;
    for (final rawKey in keys) {
      final lower = rawKey.toLowerCase();
      if (lower.startsWith('u_')) {
        hasAuthor = true;
        if (isManualOverride) {
          hasSubreddit = true;
        }
      } else if (lower.isNotEmpty) {
        hasSubreddit = true;
      }
      if (hasSubreddit && hasAuthor) break;
    }
    if (hasSubreddit && !_subredditMetadataChanges.isClosed) {
      _subredditMetadataChanges.add(isManualOverride);
    }
    if (hasAuthor && !_authorMetadataChanges.isClosed) {
      _authorMetadataChanges.add(isManualOverride);
    }
  }

  static String _escapeLikePattern(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static ({
    String? cursorWhere,
    List<Variable> whereVars,
    String havingClause,
    List<Variable> havingVars,
    String innerOrderBy,
    String outerOrderBy,
  })
  _buildDirectorySortParts({
    required String rawColumn,
    required SubredditSortOption sort,
    FeedCursor? cursor,
  }) {
    switch (sort) {
      case SubredditSortOption.mostSaved:
        return (
          cursorWhere: null,
          whereVars: const [],
          havingClause: cursor == null
              ? ''
              : 'HAVING (COUNT(*) < ?) OR (COUNT(*) = ? AND MIN($rawColumn) COLLATE NOCASE > ?)',
          havingVars: cursor == null
              ? const []
              : [
                  Variable.withInt(cursor.sortValue as int),
                  Variable.withInt(cursor.sortValue as int),
                  Variable.withString(cursor.id),
                ],
          innerOrderBy: 'item_count DESC, $rawColumn COLLATE NOCASE ASC',
          outerOrderBy: 'p.item_count DESC, p.entry_name COLLATE NOCASE ASC',
        );
      case SubredditSortOption.leastSaved:
        return (
          cursorWhere: null,
          whereVars: const [],
          havingClause: cursor == null
              ? ''
              : 'HAVING (COUNT(*) > ?) OR (COUNT(*) = ? AND MIN($rawColumn) COLLATE NOCASE > ?)',
          havingVars: cursor == null
              ? const []
              : [
                  Variable.withInt(cursor.sortValue as int),
                  Variable.withInt(cursor.sortValue as int),
                  Variable.withString(cursor.id),
                ],
          innerOrderBy: 'item_count ASC, $rawColumn COLLATE NOCASE ASC',
          outerOrderBy: 'p.item_count ASC, p.entry_name COLLATE NOCASE ASC',
        );
      case SubredditSortOption.alphabeticalAZ:
        return (
          cursorWhere: cursor == null ? null : '$rawColumn COLLATE NOCASE > ?',
          whereVars: cursor == null
              ? const []
              : [Variable.withString(cursor.id)],
          havingClause: '',
          havingVars: const [],
          innerOrderBy: '$rawColumn COLLATE NOCASE ASC',
          outerOrderBy: 'p.entry_name COLLATE NOCASE ASC',
        );
      case SubredditSortOption.alphabeticalZA:
        return (
          cursorWhere: cursor == null ? null : '$rawColumn COLLATE NOCASE < ?',
          whereVars: cursor == null
              ? const []
              : [Variable.withString(cursor.id)],
          havingClause: '',
          havingVars: const [],
          innerOrderBy: '$rawColumn COLLATE NOCASE DESC',
          outerOrderBy: 'p.entry_name COLLATE NOCASE DESC',
        );
    }
  }

  static FeedCursor _directoryCursorFor({
    required SubredditSortOption sort,
    required int count,
    required String name,
  }) {
    switch (sort) {
      case SubredditSortOption.mostSaved:
      case SubredditSortOption.leastSaved:
        return FeedCursor(sortValue: count, id: name);
      case SubredditSortOption.alphabeticalAZ:
      case SubredditSortOption.alphabeticalZA:
        return FeedCursor(sortValue: name, id: name);
    }
  }

  static SubredditInfo _subredditInfoFromRow(QueryRow row) {
    final name = row.read<String>('subreddit');
    final count = row.read<int>('item_count');
    final nsfwCount = row.read<int?>('nsfw_count') ?? 0;
    final verifiedNsfw = row.read<bool?>('verified_nsfw');
    final iconUrl = row.read<String?>('icon_url');
    final lastChecked = row.read<DateTime?>('last_checked');

    final bool isNsfw;
    final bool isVerified;
    if (verifiedNsfw != null) {
      isNsfw = verifiedNsfw;
      isVerified = true;
    } else {
      isNsfw = count > 0 && nsfwCount == count;
      isVerified = lastChecked != null;
    }

    return SubredditInfo(
      name: name,
      count: count,
      isNsfw: isNsfw,
      iconUrl: iconUrl,
      isVerified: isVerified,
    );
  }

  Future<List<SubredditInfo>> getSubredditsWithCounts() async {
    final rows = await customSelect(
      '''
      WITH grouped_subs AS (
        SELECT
          MIN(subreddit) AS subreddit,
          COUNT(*) AS item_count,
          SUM(CASE WHEN is_nsfw = 1 THEN 1 ELSE 0 END) AS nsfw_count
        FROM saved_items_table
        GROUP BY subreddit COLLATE NOCASE
      )
      SELECT
        g.subreddit,
        g.item_count,
        g.nsfw_count,
        s.is_nsfw AS verified_nsfw,
        s.icon_url,
        s.last_checked
      FROM grouped_subs g
      LEFT JOIN subreddits_table s ON s.name = ${_cleanSubSql('g.subreddit')}
      ORDER BY g.item_count DESC, g.subreddit COLLATE NOCASE ASC
      ''',
      readsFrom: {savedItemsTable, subredditsTable},
    ).get();

    return rows.map(_subredditInfoFromRow).toList();
  }

  Future<PagedRows<SubredditInfo>> getSubredditsPage({
    String query = '',
    SubredditSortOption sort = SubredditSortOption.mostSaved,
    FeedCursor? cursor,
    int limit = 100,
    bool hideNsfw = false,
  }) async {
    final cleanQuery = query
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^/?r/'), '')
        .replaceFirst(RegExp(r'^/?u/'), 'u_');
    final where = <String>[];
    final vars = <Variable>[];
    if (cleanQuery.isNotEmpty) {
      where.add("subreddit LIKE ? ESCAPE '\\'");
      vars.add(Variable.withString('%${_escapeLikePattern(cleanQuery)}%'));
    }

    final sortParts = _buildDirectorySortParts(
      rawColumn: 'subreddit',
      sort: sort,
      cursor: cursor,
    );
    if (sortParts.cursorWhere != null) {
      where.add(sortParts.cursorWhere!);
      vars.addAll(sortParts.whereVars);
    }
    vars.addAll(sortParts.havingVars);
    vars.add(Variable.withInt(limit + 1));

    final innerOrderAndLimit = hideNsfw
        ? ''
        : 'ORDER BY ${sortParts.innerOrderBy} LIMIT ?';
    final outerWhere = hideNsfw
        ? 'WHERE COALESCE(s.is_nsfw, CASE WHEN p.nsfw_count = p.item_count THEN 1 ELSE 0 END) = 0'
        : '';
    final outerLimit = hideNsfw ? 'LIMIT ?' : '';
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await customSelect(
      '''
      WITH page_rows AS (
        SELECT
          MIN(subreddit) AS entry_name,
          COUNT(*) AS item_count,
          SUM(CASE WHEN is_nsfw = 1 THEN 1 ELSE 0 END) AS nsfw_count
        FROM saved_items_table
        $whereClause
        GROUP BY subreddit COLLATE NOCASE
        ${sortParts.havingClause}
        $innerOrderAndLimit
      )
      SELECT
        p.entry_name AS subreddit,
        p.item_count,
        p.nsfw_count,
        s.is_nsfw AS verified_nsfw,
        s.icon_url,
        s.last_checked
      FROM page_rows p
      LEFT JOIN subreddits_table s ON s.name = ${_cleanSubSql('p.entry_name')}
      $outerWhere
      ORDER BY ${sortParts.outerOrderBy}
      $outerLimit
      ''',
      variables: vars,
      readsFrom: {savedItemsTable, subredditsTable},
    ).get();

    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.sublist(0, limit) : rows;
    final items = pageRows.map(_subredditInfoFromRow).toList();
    final nextCursor = hasMore && items.isNotEmpty
        ? _directoryCursorFor(
            sort: sort,
            count: items.last.count,
            name: items.last.name,
          )
        : null;

    return PagedRows(items: items, nextCursor: nextCursor, hasMore: hasMore);
  }

  Stream<List<SubredditInfo>> watchSubredditsWithCounts() {
    return _watchThrottled(
      fetch: getSubredditsWithCounts,
      tables: [savedItemsTable],
      extraTriggers: [_subredditMetadataChanges.stream],
      shouldRefetch: (updates) => updates.any(
        (u) =>
            u.kind == UpdateKind.insert ||
            u.kind == UpdateKind.delete ||
            u.kind == null,
      ),
    ).distinct(listEquals);
  }

  Future<int> getSubredditCount({bool hideNsfw = false}) async {
    final sql = hideNsfw
        ? '''
          WITH grouped_subs AS (
            SELECT
              MIN(subreddit) AS entry_name,
              COUNT(*) AS item_count,
              SUM(CASE WHEN is_nsfw = 1 THEN 1 ELSE 0 END) AS nsfw_count
            FROM saved_items_table
            GROUP BY subreddit COLLATE NOCASE
          )
          SELECT COUNT(*) AS c
          FROM grouped_subs p
          LEFT JOIN subreddits_table s ON s.name = ${_cleanSubSql('p.entry_name')}
          WHERE COALESCE(s.is_nsfw, CASE WHEN p.nsfw_count = p.item_count THEN 1 ELSE 0 END) = 0
          '''
        : '''
          SELECT COUNT(*) AS c
          FROM (
            SELECT 1
            FROM saved_items_table
            GROUP BY subreddit COLLATE NOCASE
          )
          ''';
    final row = await customSelect(
      sql,
      readsFrom: {savedItemsTable, if (hideNsfw) subredditsTable},
    ).getSingle();
    return row.read<int>('c');
  }

  Stream<int> watchSubredditCount({bool hideNsfw = false}) => _watchThrottled(
    fetch: () => getSubredditCount(hideNsfw: hideNsfw),
    tables: [savedItemsTable],
    extraTriggers: [if (hideNsfw) _subredditMetadataChanges.stream],
    shouldRefetch: (updates) => updates.any(
      (u) =>
          u.kind == UpdateKind.insert ||
          u.kind == UpdateKind.delete ||
          u.kind == null,
    ),
  ).distinct();

  Stream<T> _watchThrottled<T>({
    required Future<T> Function() fetch,
    required List<TableInfo> tables,
    List<Stream<bool>> extraTriggers = const [],
    bool Function(Set<TableUpdate> updates)? shouldRefetch,
  }) {
    late final StreamController<T> controller;
    StreamSubscription<Set<TableUpdate>>? sub;
    final extraSubs = <StreamSubscription<bool>>[];
    Timer? debounceTimer;
    var isFetching = false;
    var needsRefetch = false;

    Future<void> fetchAndEmit() async {
      if (isFetching) {
        needsRefetch = true;
        return;
      }
      isFetching = true;
      try {
        do {
          needsRefetch = false;
          final data = await fetch();
          if (controller.hasListener && !controller.isClosed) {
            controller.add(data);
          }
        } while (needsRefetch &&
            controller.hasListener &&
            !controller.isClosed);
      } catch (e, st) {
        if (controller.hasListener && !controller.isClosed) {
          controller.addError(e, st);
        }
      } finally {
        isFetching = false;
      }
    }

    void scheduleFetch() {
      if (debounceTimer?.isActive ?? false) return;
      debounceTimer = Timer(const Duration(milliseconds: 800), fetchAndEmit);
    }

    controller = StreamController<T>(
      onListen: () {
        fetchAndEmit();
        sub = tableUpdates(TableUpdateQuery.onAllTables(tables))
            .listen((updates) {
              if (shouldRefetch != null && !shouldRefetch(updates)) return;
              scheduleFetch();
            });
        for (final trigger in extraTriggers) {
          extraSubs.add(
            trigger.listen((isManualOverride) {
              if (isManualOverride) {
                debounceTimer?.cancel();
                debounceTimer = null;
                unawaited(fetchAndEmit());
              } else {
                scheduleFetch();
              }
            }),
          );
        }
      },
      onCancel: () async {
        debounceTimer?.cancel();
        await sub?.cancel();
        for (final extraSub in extraSubs) {
          await extraSub.cancel();
        }
        extraSubs.clear();
      },
    );

    return controller.stream;
  }

  Future<Set<String>> filterSfwSubreddits(Set<String> subreddits) async {
    if (subreddits.isEmpty) return const {};
    final placeholders = List.filled(subreddits.length, '?').join(',');
    final rows = await customSelect(
      '''
      SELECT
        s.subreddit,
        sub.is_nsfw AS verified_nsfw,
        SUM(CASE WHEN s.is_nsfw = 0 THEN 1 ELSE 0 END) AS sfw_count
      FROM saved_items_table s
      LEFT JOIN subreddits_table sub
        ON sub.name = ${_cleanSubSql('s.subreddit')}
      WHERE s.subreddit COLLATE NOCASE IN ($placeholders)
      GROUP BY s.subreddit COLLATE NOCASE
      ''',
      variables: subreddits.map(Variable.withString).toList(),
      readsFrom: {savedItemsTable, subredditsTable},
    ).get();
    final allowedLowers = <String>{};
    for (final r in rows) {
      final verifiedNsfw = r.read<bool?>('verified_nsfw');
      final sfwCount = r.read<int?>('sfw_count') ?? 0;
      final isSubNsfw = verifiedNsfw ?? (sfwCount == 0);
      if (!isSubNsfw) {
        allowedLowers.add(r.read<String>('subreddit').toLowerCase());
      }
    }
    return {
      for (final sub in subreddits)
        if (allowedLowers.contains(sub.toLowerCase())) sub,
    };
  }

  Future<List<(String, int)>> searchSubredditsWithCounts({
    String query = '',
    int limit = 15,
    int? collectionId,
    String? author,
    bool? isNsfw,
  }) async {
    final countExp = savedItemsTable.id.count();
    final cleanedQuery = query.trim().toLowerCase().replaceFirst(
      RegExp(r'^[ru]/'),
      '',
    );

    final selectQuery = selectOnly(savedItemsTable)
      ..addColumns([savedItemsTable.subreddit, countExp]);

    Expression<bool>? predicate;

    if (collectionId != null) {
      selectQuery.join([
        innerJoin(
          itemCollectionsTable,
          itemCollectionsTable.itemId.equalsExp(savedItemsTable.id),
        ),
      ]);
      predicate = itemCollectionsTable.collectionId.equals(collectionId);
    }

    if (author != null && author.trim().isNotEmpty) {
      final cleanAuthor = author.trim().replaceFirst(RegExp(r'^[ru]/'), '');
      final authorExp = coalesce([savedItemsTable.author, const Constant('')])
          .collate(Collate.noCase)
          .equals(cleanAuthor);
      predicate = predicate == null ? authorExp : (predicate & authorExp);
    }

    if (isNsfw != null) {
      final nsfwExpr = CustomExpression<bool>(
        _buildEffectiveNsfwSql(savedItemsTable.actualTableName),
      );
      final targetExpr = isNsfw ? nsfwExpr : nsfwExpr.not();
      predicate = predicate == null ? targetExpr : (predicate & targetExpr);
    }

    if (cleanedQuery.isNotEmpty) {
      final queryExp = savedItemsTable.subreddit.lower().like(
        '%$cleanedQuery%',
      );
      predicate = predicate == null ? queryExp : (predicate & queryExp);
    }

    if (predicate != null) {
      selectQuery.where(predicate);
    }

    selectQuery
      ..groupBy([savedItemsTable.subreddit.collate(Collate.noCase)])
      ..orderBy([OrderingTerm(expression: countExp, mode: OrderingMode.desc)])
      ..limit(limit);

    final rows = await selectQuery.get();
    return rows.map((row) {
      return (row.read(savedItemsTable.subreddit)!, row.read(countExp) ?? 0);
    }).toList();
  }

  static AuthorInfo _authorInfoFromRow(QueryRow r) {
    return AuthorInfo(
      name: r.read<String>('clean_author'),
      count: r.read<int>('item_count'),
      iconUrl: r.read<String?>('icon_url'),
      isNsfw: r.read<bool?>('is_nsfw') ?? false,
      isVerified:
          r.read<bool?>('is_nsfw') != null ||
          r.read<DateTime?>('last_checked') != null,
    );
  }

  Future<List<AuthorInfo>> getAuthorsWithCounts() async {
    final rows = await customSelect(
      '''
      WITH author_counts AS (
        SELECT
          MIN(author) AS clean_author,
          COUNT(*) AS item_count
        FROM saved_items_table
        WHERE author IS NOT NULL
          AND author != ''
          AND author COLLATE NOCASE NOT IN ('[deleted]', '[removed]', 'deleted', 'removed')
        GROUP BY author COLLATE NOCASE
      )
      SELECT
        c.clean_author,
        c.item_count,
        sub.icon_url,
        sub.is_nsfw,
        sub.last_checked
      FROM author_counts c
      LEFT JOIN subreddits_table sub
        ON sub.name = 'u_' || LOWER(c.clean_author)
      ORDER BY c.item_count DESC, c.clean_author COLLATE NOCASE ASC
      ''',
      readsFrom: {savedItemsTable, subredditsTable},
    ).get();

    return [for (final r in rows) _authorInfoFromRow(r)];
  }

  Future<PagedRows<AuthorInfo>> getAuthorsPage({
    String query = '',
    SubredditSortOption sort = SubredditSortOption.mostSaved,
    FeedCursor? cursor,
    int limit = 100,
    bool hideNsfw = false,
  }) async {
    final cleanQuery = query.trim().toLowerCase().replaceFirst(
      RegExp(r'^/?u/'),
      '',
    );
    final where = <String>[
      'author IS NOT NULL',
      "author != ''",
      "author COLLATE NOCASE NOT IN ('[deleted]', '[removed]', 'deleted', 'removed')",
    ];
    final vars = <Variable>[];
    if (cleanQuery.isNotEmpty) {
      where.add("author LIKE ? ESCAPE '\\'");
      vars.add(Variable.withString('%${_escapeLikePattern(cleanQuery)}%'));
    }

    final sortParts = _buildDirectorySortParts(
      rawColumn: 'author',
      sort: sort,
      cursor: cursor,
    );
    if (sortParts.cursorWhere != null) {
      where.add(sortParts.cursorWhere!);
      vars.addAll(sortParts.whereVars);
    }
    vars.addAll(sortParts.havingVars);
    vars.add(Variable.withInt(limit + 1));

    final innerOrderAndLimit = hideNsfw
        ? ''
        : 'ORDER BY ${sortParts.innerOrderBy} LIMIT ?';
    final outerWhere = hideNsfw ? 'WHERE COALESCE(sub.is_nsfw, 0) = 0' : '';
    final outerLimit = hideNsfw ? 'LIMIT ?' : '';
    final rows = await customSelect(
      '''
      WITH page_rows AS (
        SELECT
          MIN(author) AS entry_name,
          COUNT(*) AS item_count
        FROM saved_items_table
        WHERE ${where.join(' AND ')}
        GROUP BY author COLLATE NOCASE
        ${sortParts.havingClause}
        $innerOrderAndLimit
      )
      SELECT
        p.entry_name AS clean_author,
        p.item_count,
        sub.icon_url,
        sub.is_nsfw,
        sub.last_checked
      FROM page_rows p
      LEFT JOIN subreddits_table sub
        ON sub.name = 'u_' || LOWER(p.entry_name)
      $outerWhere
      ORDER BY ${sortParts.outerOrderBy}
      $outerLimit
      ''',
      variables: vars,
      readsFrom: {savedItemsTable, subredditsTable},
    ).get();

    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.sublist(0, limit) : rows;
    final items = [for (final r in pageRows) _authorInfoFromRow(r)];
    final nextCursor = hasMore && items.isNotEmpty
        ? _directoryCursorFor(
            sort: sort,
            count: items.last.count,
            name: items.last.name,
          )
        : null;

    return PagedRows(items: items, nextCursor: nextCursor, hasMore: hasMore);
  }

  Stream<List<AuthorInfo>> watchAuthorsWithCounts() => _watchThrottled(
    fetch: getAuthorsWithCounts,
    tables: [savedItemsTable],
    extraTriggers: [_authorMetadataChanges.stream, _authorItemsChanged.stream],
    shouldRefetch: (updates) => updates.any(
      (u) =>
          u.kind == UpdateKind.insert ||
          u.kind == UpdateKind.delete ||
          u.kind == null,
    ),
  ).distinct(listEquals);

  Future<int> getAuthorCount({bool hideNsfw = false}) async {
    final sql = hideNsfw
        ? '''
          WITH grouped_authors AS (
            SELECT
              MIN(author) AS entry_name
            FROM saved_items_table
            WHERE author IS NOT NULL
              AND author != ''
              AND author COLLATE NOCASE NOT IN ('[deleted]', '[removed]', 'deleted', 'removed')
            GROUP BY author COLLATE NOCASE
          )
          SELECT COUNT(*) AS c
          FROM grouped_authors p
          LEFT JOIN subreddits_table sub
            ON sub.name = 'u_' || LOWER(p.entry_name)
          WHERE COALESCE(sub.is_nsfw, 0) = 0
          '''
        : '''
          SELECT COUNT(*) AS c
          FROM (
            SELECT 1
            FROM saved_items_table
            WHERE author IS NOT NULL
              AND author != ''
              AND author COLLATE NOCASE NOT IN ('[deleted]', '[removed]', 'deleted', 'removed')
            GROUP BY author COLLATE NOCASE
          )
          ''';
    final row = await customSelect(
      sql,
      readsFrom: {savedItemsTable, if (hideNsfw) subredditsTable},
    ).getSingle();
    return row.read<int>('c');
  }

  Stream<int> watchAuthorCount({bool hideNsfw = false}) => _watchThrottled(
    fetch: () => getAuthorCount(hideNsfw: hideNsfw),
    tables: [savedItemsTable],
    extraTriggers: [
      _authorItemsChanged.stream,
      if (hideNsfw) _authorMetadataChanges.stream,
    ],
    shouldRefetch: (updates) => updates.any(
      (u) =>
          u.kind == UpdateKind.insert ||
          u.kind == UpdateKind.delete ||
          u.kind == null,
    ),
  ).distinct();

  Future<List<(String, int)>> searchAuthorsWithCounts({
    String query = '',
    int limit = 15,
    int? collectionId,
    String? subreddit,
    bool? isNsfw,
  }) async {
    final countExp = savedItemsTable.id.count();
    final cleanedQuery = query.trim().toLowerCase().replaceFirst(
      RegExp(r'^[ru]/'),
      '',
    );

    Expression<bool> predicate =
        savedItemsTable.author.isNotNull() &
        savedItemsTable.author.isBiggerThanValue('') &
        savedItemsTable.author.isNotValue('[deleted]');

    if (subreddit != null && subreddit.trim().isNotEmpty) {
      final cleanSub = subreddit.trim().replaceFirst(RegExp(r'^[ru]/'), '');
      predicate =
          predicate &
          savedItemsTable.subreddit.collate(Collate.noCase).equals(cleanSub);
    }

    if (isNsfw != null) {
      final nsfwExpr = CustomExpression<bool>(
        _buildEffectiveNsfwSql(savedItemsTable.actualTableName),
      );
      predicate = predicate & (isNsfw ? nsfwExpr : nsfwExpr.not());
    }

    if (cleanedQuery.isNotEmpty) {
      predicate =
          predicate & savedItemsTable.author.lower().like('%$cleanedQuery%');
    }

    final selectQuery = selectOnly(savedItemsTable)
      ..addColumns([savedItemsTable.author, countExp]);

    if (collectionId != null) {
      selectQuery.join([
        innerJoin(
          itemCollectionsTable,
          itemCollectionsTable.itemId.equalsExp(savedItemsTable.id),
        ),
      ]);
      predicate =
          predicate & itemCollectionsTable.collectionId.equals(collectionId);
    }

    selectQuery
      ..where(predicate)
      ..groupBy([savedItemsTable.author.collate(Collate.noCase)])
      ..orderBy([OrderingTerm(expression: countExp, mode: OrderingMode.desc)])
      ..limit(limit);

    final rows = await selectQuery.get();
    return rows.map((row) {
      return (row.read(savedItemsTable.author)!, row.read(countExp) ?? 0);
    }).toList();
  }

  Future<List<(String, int)>> searchFlairsWithCounts({
    String query = '',
    int limit = 15,
    int? collectionId,
    String? subreddit,
    String? author,
    bool? isNsfw,
  }) async {
    final countExp = savedItemsTable.id.count();
    final cleanedQuery = query.trim().toLowerCase();

    Expression<bool> predicate =
        savedItemsTable.postFlair.isNotNull() &
        savedItemsTable.postFlair.isBiggerThanValue('');

    if (subreddit != null && subreddit.trim().isNotEmpty) {
      final cleanSub = subreddit.trim().replaceFirst(RegExp(r'^[ru]/'), '');
      predicate =
          predicate &
          savedItemsTable.subreddit.collate(Collate.noCase).equals(cleanSub);
    }

    if (author != null && author.trim().isNotEmpty) {
      final cleanAuthor = author.trim().replaceFirst(RegExp(r'^[ru]/'), '');
      predicate =
          predicate &
          coalesce([savedItemsTable.author, const Constant('')])
              .collate(Collate.noCase)
              .equals(cleanAuthor);
    }

    if (isNsfw != null) {
      final nsfwExpr = CustomExpression<bool>(
        _buildEffectiveNsfwSql(savedItemsTable.actualTableName),
      );
      predicate = predicate & (isNsfw ? nsfwExpr : nsfwExpr.not());
    }

    if (cleanedQuery.isNotEmpty) {
      predicate =
          predicate & savedItemsTable.postFlair.lower().like('%$cleanedQuery%');
    }

    final selectQuery = selectOnly(savedItemsTable)
      ..addColumns([savedItemsTable.postFlair, countExp]);

    if (collectionId != null) {
      selectQuery.join([
        innerJoin(
          itemCollectionsTable,
          itemCollectionsTable.itemId.equalsExp(savedItemsTable.id),
        ),
      ]);
      predicate =
          predicate & itemCollectionsTable.collectionId.equals(collectionId);
    }

    selectQuery
      ..where(predicate)
      ..groupBy([savedItemsTable.postFlair])
      ..orderBy([OrderingTerm(expression: countExp, mode: OrderingMode.desc)])
      ..limit(limit);

    final rows = await selectQuery.get();
    return rows.map((row) {
      return (row.read(savedItemsTable.postFlair)!, row.read(countExp) ?? 0);
    }).toList();
  }

  Stream<List<CollectionEntry>> watchCollectionsForItem(String itemId) {
    final query = select(collectionsTable).join([
      innerJoin(
        itemCollectionsTable,
        itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
      ),
    ])..where(itemCollectionsTable.itemId.equals(itemId));

    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(collectionsTable)).toList(),
    );
  }

  Future<List<CollectionEntry>> getCollectionsForItem(String itemId) {
    final query = select(collectionsTable).join([
      innerJoin(
        itemCollectionsTable,
        itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
      ),
    ])..where(itemCollectionsTable.itemId.equals(itemId));

    return query.map((r) => r.readTable(collectionsTable)).get();
  }

  Stream<List<(CollectionEntry, int)>> watchCollectionsWithCounts() {
    final countExp = itemCollectionsTable.itemId.count();
    final query =
        select(collectionsTable).join([
            leftOuterJoin(
              itemCollectionsTable,
              itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
            ),
          ])
          ..addColumns([countExp])
          ..groupBy([collectionsTable.id])
          ..orderBy([
            OrderingTerm(
              expression: collectionsTable.name,
              mode: OrderingMode.asc,
            ),
          ]);

    return query.watch().map((rows) {
      return rows.map((r) {
        return (r.readTable(collectionsTable), r.read(countExp) ?? 0);
      }).toList();
    });
  }

  Future<List<(CollectionEntry, int)>> getCollectionsWithCounts() async {
    final countExp = itemCollectionsTable.itemId.count();
    final query =
        select(collectionsTable).join([
            leftOuterJoin(
              itemCollectionsTable,
              itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
            ),
          ])
          ..addColumns([countExp])
          ..groupBy([collectionsTable.id])
          ..orderBy([
            OrderingTerm(
              expression: collectionsTable.name,
              mode: OrderingMode.asc,
            ),
          ]);

    final rows = await query.get();
    return rows.map((r) {
      return (r.readTable(collectionsTable), r.read(countExp) ?? 0);
    }).toList();
  }

  Future<List<SavedItemEntry>> getPendingEnrichmentItems({
    int limit = 50,
    List<String> excludeIds = const [],
  }) {
    Expression<bool> predicate = savedItemsTable.enrichmentStatus.isIn([
      EnrichmentStatus.slugOnly.index,
      EnrichmentStatus.pending.index,
    ]);
    if (excludeIds.isNotEmpty) {
      predicate = predicate & savedItemsTable.id.isNotIn(excludeIds);
    }
    return (select(savedItemsTable)
          ..where((tbl) => predicate)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.importOrder,
              mode: OrderingMode.asc,
            ),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> getPendingEnrichmentCount() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.enrichmentStatus.isIn([
          EnrichmentStatus.slugOnly.index,
          EnrichmentStatus.pending.index,
        ]),
      );
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  Expression<bool> _isArchiveRemovedField(GeneratedColumn<String> col) {
    final lower = col.lower();
    return col.isIn(['[deleted]', '[removed]', 'deleted', 'removed']) |
        lower.like('[%removed by%]') |
        lower.like('[%deleted by%]') |
        lower.like('removed by reddit%') |
        lower.like('removed by moderator%');
  }

  Future<List<SavedItemEntry>> getArchiveRecoveryItems({
    int limit = 50,
    List<String> excludeIds = const [],
  }) {
    Expression<bool> predicate =
        savedItemsTable.isArchiveRecovered.equals(false) &
        savedItemsTable.isArchiveUnavailable.equals(false) &
        (savedItemsTable.enrichmentStatus.equals(
              EnrichmentStatus.failed.index,
            ) |
            _isArchiveRemovedField(savedItemsTable.author) |
            _isArchiveRemovedField(savedItemsTable.body) |
            _isArchiveRemovedField(savedItemsTable.title));
    if (excludeIds.isNotEmpty) {
      predicate = predicate & savedItemsTable.id.isNotIn(excludeIds);
    }
    return (select(savedItemsTable)
          ..where((tbl) => predicate)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.importOrder,
              mode: OrderingMode.asc,
            ),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> getArchiveRecoveryCount() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.isArchiveRecovered.equals(false) &
            savedItemsTable.isArchiveUnavailable.equals(false) &
            (savedItemsTable.enrichmentStatus.equals(
                  EnrichmentStatus.failed.index,
                ) |
                _isArchiveRemovedField(savedItemsTable.author) |
                _isArchiveRemovedField(savedItemsTable.body) |
                _isArchiveRemovedField(savedItemsTable.title)),
      );
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  Stream<int> watchArchiveRecoveryCount() {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.isArchiveRecovered.equals(false) &
            savedItemsTable.isArchiveUnavailable.equals(false) &
            (savedItemsTable.enrichmentStatus.equals(
                  EnrichmentStatus.failed.index,
                ) |
                _isArchiveRemovedField(savedItemsTable.author) |
                _isArchiveRemovedField(savedItemsTable.body) |
                _isArchiveRemovedField(savedItemsTable.title)),
      );
    return query.watchSingle().map((row) => row.read(countExp) ?? 0).distinct();
  }

  Future<int> getArchiveUnavailableCount() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.isArchiveRecovered.equals(false) &
            savedItemsTable.isArchiveUnavailable.equals(true),
      );
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  Stream<int> watchArchiveUnavailableCount() {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.isArchiveRecovered.equals(false) &
            savedItemsTable.isArchiveUnavailable.equals(true),
      );
    return query.watchSingle().map((row) => row.read(countExp) ?? 0).distinct();
  }

  Future<int> resetArchiveUnavailableStatus() {
    return (update(
      savedItemsTable,
    )..where((t) => t.isArchiveUnavailable.equals(true))).write(
      const SavedItemsTableCompanion(isArchiveUnavailable: Value(false)),
    );
  }

  Stream<int> watchPendingEnrichmentCount() {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.enrichmentStatus.isIn([
          EnrichmentStatus.slugOnly.index,
          EnrichmentStatus.pending.index,
        ]),
      );
    return query.watchSingle().map((row) => row.read(countExp) ?? 0).distinct();
  }

  Future<int> getTotalCount() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)..addColumns([countExp]);
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  Future<void> clearAllData() async {
    _ftsInitFuture = null;
    await transaction(() async {
      await customStatement('DROP TRIGGER IF EXISTS saved_items_ai;');
      await customStatement('DROP TRIGGER IF EXISTS saved_items_ad;');
      await customStatement('DROP TRIGGER IF EXISTS saved_items_au;');
      await customStatement('DROP TABLE IF EXISTS saved_items_fts;');

      await delete(itemCollectionsTable).go();
      await delete(collectionsTable).go();
      await delete(savedItemsTable).go();
      await delete(subredditsTable).go();

      try {
        await customStatement(
          'DELETE FROM sqlite_sequence WHERE name IN (\'collections_table\', \'saved_items_table\');',
        );
      } catch (_) {}

      await _createFts5(this);
      _ftsInitFuture = Future.value();
    });

    invalidateCollectionsCache();

    try {
      await customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
      await customStatement('VACUUM;');
    } catch (e) {
      debugPrint('[Database] Post-clear compaction note: $e');
    }

    notifyUpdates({
      TableUpdate.onTable(savedItemsTable, kind: UpdateKind.delete),
      TableUpdate.onTable(collectionsTable, kind: UpdateKind.delete),
      TableUpdate.onTable(itemCollectionsTable, kind: UpdateKind.delete),
      TableUpdate.onTable(subredditsTable, kind: UpdateKind.delete),
    });
  }
}

extension SavedItemEntryExtension on SavedItemEntry {
  SavedItem toDomain({List<Collection> collections = const []}) {
    return SavedItem(
      id: id,
      permalink: permalink,
      itemType: itemType,
      parentPostId: parentPostId,
      parentPostTitle: parentPostTitle,
      title: title,
      subreddit: subreddit,
      author: author,
      body: body,
      url: url,
      thumbnailUrl: thumbnailUrl,
      mediaUrl: mediaUrl,
      galleryImages: SavedItem.parseGalleryImagesJson(galleryImages),
      galleryPreviewImages: SavedItem.parseGalleryImagesJson(
        galleryPreviewImages,
      ),
      mediaType: mediaType,
      score: score,
      numComments: numComments,
      isNsfw: isNsfw,
      isStarred: isStarred,
      isArchived: isArchived,
      userNote: userNote,
      csvSource: csvSource,
      importOrder: importOrder,
      createdAtUtc: createdAtUtc,
      savedAtUtc: savedAtUtc,
      postFlair: postFlair,
      subredditType: subredditType,
      enrichmentStatus: enrichmentStatus,
      isArchiveRecovered: isArchiveRecovered,
      isArchiveUnavailable: isArchiveUnavailable,
      collections: collections,
    );
  }
}
