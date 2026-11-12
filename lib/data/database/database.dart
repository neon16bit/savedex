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
        },
      );
    });
  }

  @override
  int get schemaVersion => 13;

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
      await _createIndexes(this);
      _ftsInitFuture = Future.value();
    },
  );

  static String _cleanSubSql(String colExpr) =>
      "LOWER(CASE WHEN $colExpr LIKE 'r/%' THEN SUBSTR($colExpr, 3) WHEN $colExpr LIKE 'u/%' THEN 'u_' || SUBSTR($colExpr, 3) ELSE $colExpr END)";

  static String _buildEffectiveNsfwSql(String alias) =>
      "($alias.is_nsfw = 1 OR EXISTS (SELECT 1 FROM subreddits_table sub WHERE sub.name = ${_cleanSubSql('$alias.subreddit')} AND sub.is_nsfw = 1))";

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

  (List<String>, List<Variable>) _buildFilterClauses(FilterCriteria filter) {
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
    if (filter.selectedCollectionIds.isNotEmpty) {
      where.add(
        's.id IN (SELECT item_id FROM item_collections_table WHERE collection_id IN (${List.filled(filter.selectedCollectionIds.length, '?').join(',')}))',
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

    return (where, vars);
  }

  Future<PagedRows<SavedItemEntry>> getSavedItemsKeysetPage({
    required FilterCriteria filter,
    FeedCursor? cursor,
    int limit = 100,
  }) async {
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      await ensureFtsSchema();
    }
    final (where, vars) = _buildFilterClauses(filter);

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

    vars.add(Variable.withInt(limit + 1));
    final sql =
        '''
      SELECT s.*
      FROM saved_items_table s
      $whereClause
      $orderBy
      LIMIT ?
    ''';

    final rows = await customSelect(
      sql,
      variables: vars,
      readsFrom: {savedItemsTable, if (filter.isNsfw != null) subredditsTable},
    ).get();

    final entries = rows.map((r) => savedItemsTable.map(r.data)).toList();
    final hasMore = entries.length > limit;
    final pageRows = hasMore ? entries.sublist(0, limit) : entries;

    FeedCursor? nextCursor;
    if (hasMore && pageRows.isNotEmpty) {
      nextCursor = _extractCursor(pageRows.last, filter.sortOption);
    }

    return PagedRows(items: pageRows, nextCursor: nextCursor, hasMore: hasMore);
  }

  Future<int> countFilteredSavedItems(FilterCriteria filter) async {
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      await ensureFtsSchema();
    }
    final (where, vars) = _buildFilterClauses(filter);
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final sql = 'SELECT COUNT(*) AS c FROM saved_items_table s $whereClause';

    final row = await customSelect(
      sql,
      variables: vars,
      readsFrom: {savedItemsTable, if (filter.isNsfw != null) subredditsTable},
    ).getSingle();

    return row.read<int>('c');
  }

  // bulk upsert items nondestructively using ON CONFLICT DO UPDATE
  Future<void> upsertBatch(List<SavedItemsTableCompanion> entries) async {
    if (entries.isEmpty) return;
    const chunkSize = 500;
    await transaction(() async {
      for (var i = 0; i < entries.length; i += chunkSize) {
        final chunk = entries.sublist(
          i,
          i + chunkSize > entries.length ? entries.length : i + chunkSize,
        );
        await batch((batch) {
          batch.insertAllOnConflictUpdate(savedItemsTable, chunk);
        });
      }
    });
  }

  Future<Map<String, SubredditEntry>> getAllSubredditsMap() async {
    final entries = await select(subredditsTable).get();
    return {for (final e in entries) e.name.toLowerCase(): e};
  }

  Future<List<SubredditEntry>> getAllSubreddits() async {
    return select(subredditsTable).get();
  }

  Future<bool> isSubredditNsfw(String subreddit) async {
    final clean = SavedItem.normalizeSubredditKey(subreddit);
    if (clean.isEmpty) return false;
    final entry = await (select(
      subredditsTable,
    )..where((t) => t.name.equals(clean))).getSingleOrNull();
    return entry?.isNsfw == true;
  }

  Future<void> upsertSubreddit(SubredditsTableCompanion entry) async {
    await into(subredditsTable).insertOnConflictUpdate(entry);
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
  }

  Future<List<SubredditInfo>> getSubredditsWithCounts() async {
    final rows = await customSelect(
      '''
      WITH grouped_subs AS (
        SELECT
          subreddit,
          COUNT(id) AS item_count,
          SUM(CASE WHEN is_nsfw = 1 THEN 1 ELSE 0 END) AS nsfw_count,
          ${_cleanSubSql('subreddit')} AS clean_sub
        FROM saved_items_table
        GROUP BY subreddit
      )
      SELECT
        g.subreddit,
        g.item_count,
        g.nsfw_count,
        s.is_nsfw AS verified_nsfw,
        s.icon_url,
        s.last_checked
      FROM grouped_subs g
      LEFT JOIN subreddits_table s ON s.name = g.clean_sub
      ORDER BY g.item_count DESC
      ''',
      readsFrom: {savedItemsTable, subredditsTable},
    ).get();

    return rows.map((row) {
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
    }).toList();
  }

  Stream<List<SubredditInfo>> watchSubredditsWithCounts() {
    return _watchThrottled(
      fetch: getSubredditsWithCounts,
      tables: [savedItemsTable, subredditsTable],
      shouldRefetch: (updates) => updates.any(
        (u) =>
            u.table == subredditsTable.actualTableName ||
            u.kind == UpdateKind.insert ||
            u.kind == UpdateKind.delete ||
            u.kind == null,
      ),
    ).distinct(listEquals);
  }

  Stream<T> _watchThrottled<T>({
    required Future<T> Function() fetch,
    required List<TableInfo> tables,
    bool Function(Set<TableUpdate> updates)? shouldRefetch,
  }) {
    late final StreamController<T> controller;
    StreamSubscription<Set<TableUpdate>>? sub;
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

    controller = StreamController<T>(
      onListen: () {
        fetchAndEmit();
        sub = tableUpdates(TableUpdateQuery.onAllTables(tables))
            .listen((updates) {
              if (shouldRefetch != null && !shouldRefetch(updates)) return;
              if (debounceTimer?.isActive ?? false) return;
              debounceTimer = Timer(
                const Duration(milliseconds: 800),
                fetchAndEmit,
              );
            });
      },
      onCancel: () async {
        debounceTimer?.cancel();
        await sub?.cancel();
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

  Future<List<AuthorInfo>> getAuthorsWithCounts() async {
    final rows = await customSelect(
      '''
      WITH cleaned_authors AS (
        SELECT
          TRIM(
            CASE
              WHEN SUBSTR(author, 1, 2) COLLATE NOCASE IN ('u/', 'r/', 'u_')
              THEN SUBSTR(author, 3)
              ELSE author
            END
          ) AS clean_author,
          id
        FROM saved_items_table
        WHERE author IS NOT NULL AND author != ''
      ),
      author_counts AS (
        SELECT
          clean_author,
          COUNT(id) AS item_count
        FROM cleaned_authors
        WHERE clean_author != ''
          AND clean_author COLLATE NOCASE NOT IN ('[deleted]', '[removed]', 'deleted', 'removed')
        GROUP BY clean_author COLLATE NOCASE
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

    return [
      for (final r in rows)
        AuthorInfo(
          name: r.read<String>('clean_author'),
          count: r.read<int>('item_count'),
          iconUrl: r.read<String?>('icon_url'),
          isNsfw: r.read<bool?>('is_nsfw') ?? false,
          isVerified:
              r.read<bool?>('is_nsfw') != null ||
              r.read<DateTime?>('last_checked') != null,
        ),
    ];
  }

  Stream<List<AuthorInfo>> watchAuthorsWithCounts() => _watchThrottled(
    fetch: getAuthorsWithCounts,
    tables: [savedItemsTable, subredditsTable],
  ).distinct(listEquals);

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
