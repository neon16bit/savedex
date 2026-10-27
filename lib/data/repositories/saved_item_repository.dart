import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/enriched_reddit_data.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/services/backup_export_service.dart';
import 'package:savedex/data/services/csv_parser_service.dart';
import 'package:savedex/data/services/arctic_shift_api_service.dart';
import 'package:savedex/data/services/pullpush_api_service.dart';
import 'package:savedex/data/services/reddit_api_service.dart';
import 'package:savedex/data/repositories/settings_repository.dart';

class SavedItemRepository {
  final AppDatabase db;
  final CsvParserService _csvParser;
  final RedditApiService _redditApi;
  final ArcticShiftApiService _arcticShiftApi;
  final PullPushApiService _pullPushApi;
  final SettingsRepository _settingsRepository;
  final BackupExportService _backupExport;
  final Map<String, Future<({bool success, String? error})>>
  _inFlightEnrichments = {};

  SavedItemRepository({
    required this.db,
    CsvParserService? csvParser,
    RedditApiService? redditApi,
    ArcticShiftApiService? arcticShiftApi,
    PullPushApiService? pullPushApi,
    SettingsRepository? settingsRepository,
    BackupExportService? backupExport,
  }) : _csvParser = csvParser ?? CsvParserService(),
       _redditApi = redditApi ?? RedditApiService(),
       _arcticShiftApi = arcticShiftApi ?? ArcticShiftApiService(),
       _pullPushApi = pullPushApi ?? PullPushApiService(),
       _settingsRepository = settingsRepository ?? SettingsRepository(),
       _backupExport = backupExport ?? BackupExportService();

  Stream<List<SavedItem>> watchSavedItems(FilterCriteria filter) {
    return db
        .watchFilteredSavedItems(
          searchQuery: filter.searchQuery,
          subreddits: filter.selectedSubreddits,
          authors: filter.selectedAuthors,
          flairs: filter.selectedFlairs,
          mediaTypes: filter.selectedMediaTypes,
          itemType: filter.itemType,
          enrichmentStatus: filter.enrichmentStatus,
          isStarred: filter.isStarred,
          isArchived: filter.isArchived,
          isNsfw: filter.isNsfw,
          collectionIds: filter.selectedCollectionIds,
          sortOption: filter.sortOption,
          dateRangeStart: filter.dateRangeStart,
          dateRangeEnd: filter.dateRangeEnd,
        )
        .asyncMap((rows) => _attachCollectionsToEntries(rows));
  }

  Future<List<SavedItem>> getAllSavedItems(FilterCriteria filter) async {
    final stream = db.watchFilteredSavedItems(
      searchQuery: filter.searchQuery,
      subreddits: filter.selectedSubreddits,
      authors: filter.selectedAuthors,
      flairs: filter.selectedFlairs,
      mediaTypes: filter.selectedMediaTypes,
      itemType: filter.itemType,
      enrichmentStatus: filter.enrichmentStatus,
      isStarred: filter.isStarred,
      isArchived: filter.isArchived,
      isNsfw: filter.isNsfw,
      collectionIds: filter.selectedCollectionIds,
      sortOption: filter.sortOption,
      dateRangeStart: filter.dateRangeStart,
      dateRangeEnd: filter.dateRangeEnd,
    );
    final rows = await stream.first;
    return _attachCollectionsToEntries(rows);
  }

  Future<PagedRows<SavedItem>> getSavedItemsPage({
    required FilterCriteria filter,
    FeedCursor? cursor,
    int limit = 100,
  }) async {
    final page = await db.getSavedItemsKeysetPage(
      filter: filter,
      cursor: cursor,
      limit: limit,
    );

    if (page.items.isEmpty) {
      return const PagedRows(items: [], nextCursor: null, hasMore: false);
    }

    final items = await _attachCollectionsToEntries(page.items);
    return PagedRows(
      items: items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<List<SavedItem>> getItemsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    const chunkSize = 200;
    final chunkFutures = <Future<List<SavedItemEntry>>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        i + chunkSize > ids.length ? ids.length : i + chunkSize,
      );
      chunkFutures.add(
        (db.select(db.savedItemsTable)..where((t) => t.id.isIn(chunk))).get(),
      );
    }
    final chunkResults = await Future.wait(chunkFutures);
    final allEntries = [for (final list in chunkResults) ...list];
    return _attachCollectionsToEntries(allEntries);
  }

  Future<List<SavedItem>> _attachCollectionsToEntries(
    List<SavedItemEntry> entries,
  ) async {
    if (entries.isEmpty) return const [];
    final itemIds = entries.map((i) => i.id).toList();
    const chunkSize = 200;
    final chunkFutures = <Future<List<TypedResult>>>[];

    for (var i = 0; i < itemIds.length; i += chunkSize) {
      final chunk = itemIds.sublist(
        i,
        i + chunkSize > itemIds.length ? itemIds.length : i + chunkSize,
      );
      chunkFutures.add(
        (db.select(db.collectionsTable).join([
          innerJoin(
            db.itemCollectionsTable,
            db.itemCollectionsTable.collectionId.equalsExp(
              db.collectionsTable.id,
            ),
          ),
        ])..where(db.itemCollectionsTable.itemId.isIn(chunk))).get(),
      );
    }

    final chunkResults = await Future.wait(chunkFutures);
    final collectionRows = [for (final list in chunkResults) ...list];

    final collectionsMap = <String, List<Collection>>{};
    for (final row in collectionRows) {
      final c = row.readTable(db.collectionsTable);
      final itemId = row.readTable(db.itemCollectionsTable).itemId;
      collectionsMap
          .putIfAbsent(itemId, () => [])
          .add(
            Collection(
              id: c.id,
              name: c.name,
              description: c.description,
              colorValue: c.colorValue,
              createdAtUtc: c.createdAtUtc,
            ),
          );
    }

    return entries
        .map((e) => e.toDomain(collections: collectionsMap[e.id] ?? const []))
        .toList();
  }

  Future<SavedItem?> getItemById(String id) async {
    final query = db.select(db.savedItemsTable)..where((t) => t.id.equals(id));
    final entry = await query.getSingleOrNull();
    if (entry == null) return null;

    final collections =
        await (db.select(db.collectionsTable).join([
          innerJoin(
            db.itemCollectionsTable,
            db.itemCollectionsTable.collectionId.equalsExp(
              db.collectionsTable.id,
            ),
          ),
        ])..where(db.itemCollectionsTable.itemId.equals(id))).map((row) {
          final c = row.readTable(db.collectionsTable);
          return Collection(
            id: c.id,
            name: c.name,
            description: c.description,
            colorValue: c.colorValue,
            createdAtUtc: c.createdAtUtc,
          );
        }).get();

    return entry.toDomain(collections: collections);
  }

  Stream<SavedItem?> watchItemById(String id) {
    final query = db.select(db.savedItemsTable)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().asyncMap((entry) async {
      if (entry == null) return null;
      final collections =
          await (db.select(db.collectionsTable).join([
            innerJoin(
              db.itemCollectionsTable,
              db.itemCollectionsTable.collectionId.equalsExp(
                db.collectionsTable.id,
              ),
            ),
          ])..where(db.itemCollectionsTable.itemId.equals(id))).map((row) {
            final c = row.readTable(db.collectionsTable);
            return Collection(
              id: c.id,
              name: c.name,
              description: c.description,
              colorValue: c.colorValue,
              createdAtUtc: c.createdAtUtc,
            );
          }).get();

      return entry.toDomain(collections: collections);
    });
  }

  Stream<({SavedItem? parentPost, List<SavedItem> comments})>
  watchRelatedThreadItems(SavedItem item) {
    final isComment = item.itemType == ItemType.comment;
    final rawPostId = isComment ? item.parentPostId : item.id;

    if (rawPostId == null || rawPostId.isEmpty) {
      return Stream.value((
        parentPost: isComment ? null : item,
        comments: <SavedItem>[],
      ));
    }

    final cleanPostId = rawPostId.startsWith('t3_')
        ? rawPostId.substring(3)
        : rawPostId;
    final candidatePostIds = [cleanPostId, 't3_$cleanPostId'];

    final commentQuery = db.select(db.savedItemsTable)
      ..where(
        (t) =>
            t.parentPostId.isIn(candidatePostIds) &
            t.itemType.equals(ItemType.comment.index),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAtUtc, mode: OrderingMode.asc),
      ]);

    return commentQuery.watch().asyncMap((commentEntries) async {
      SavedItem? parentPost;
      if (!isComment) {
        parentPost = item;
      } else {
        final postEntry =
            await (db.select(db.savedItemsTable)..where(
                  (t) =>
                      t.id.isIn(candidatePostIds) &
                      t.itemType.equals(ItemType.post.index),
                ))
                .getSingleOrNull();
        if (postEntry != null) {
          parentPost = postEntry.toDomain();
        }
      }

      final comments = commentEntries.map((e) => e.toDomain()).toList();
      return (parentPost: parentPost, comments: comments);
    });
  }

  Future<({SavedItem? parentPost, List<SavedItem> comments})>
  getRelatedThreadItems(SavedItem item) async {
    final isComment = item.itemType == ItemType.comment;
    final rawPostId = isComment ? item.parentPostId : item.id;

    if (rawPostId == null || rawPostId.isEmpty) {
      return (parentPost: isComment ? null : item, comments: <SavedItem>[]);
    }

    final cleanPostId = rawPostId.startsWith('t3_')
        ? rawPostId.substring(3)
        : rawPostId;
    final candidatePostIds = [cleanPostId, 't3_$cleanPostId'];

    SavedItem? parentPost;
    if (!isComment) {
      parentPost = item;
    } else {
      final postEntry =
          await (db.select(db.savedItemsTable)..where(
                (t) =>
                    t.id.isIn(candidatePostIds) &
                    t.itemType.equals(ItemType.post.index),
              ))
              .getSingleOrNull();
      if (postEntry != null) {
        parentPost = postEntry.toDomain();
      }
    }

    final commentEntries =
        await (db.select(db.savedItemsTable)
              ..where(
                (t) =>
                    t.parentPostId.isIn(candidatePostIds) &
                    t.itemType.equals(ItemType.comment.index),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAtUtc,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();

    final comments = commentEntries.map((e) => e.toDomain()).toList();
    return (parentPost: parentPost, comments: comments);
  }

  Future<void> toggleStar(String id, bool isStarred) async {
    await (db.update(db.savedItemsTable)..where((t) => t.id.equals(id))).write(
      SavedItemsTableCompanion(isStarred: Value(isStarred)),
    );
  }

  Future<void> updateUserNote(String id, String? note) async {
    await (db.update(db.savedItemsTable)..where((t) => t.id.equals(id))).write(
      SavedItemsTableCompanion(userNote: Value(note)),
    );
  }

  Future<void> toggleArchive(String id, bool isArchived) async {
    await (db.update(db.savedItemsTable)..where((t) => t.id.equals(id))).write(
      SavedItemsTableCompanion(isArchived: Value(isArchived)),
    );
  }

  Future<void> deleteItem(String id) async {
    await (db.delete(db.savedItemsTable)..where((t) => t.id.equals(id))).go();
  }

  Future<ImportSummary> importFromCsvContent(
    String csvContent,
    String sourceName, {
    int startOrderIndex = 0,
  }) async {
    if (BackupExportService.isSavedexBackupCsv(csvContent)) {
      final payload = _backupExport.parseSavedexCsv(csvContent);
      return restoreFromPayload(payload, sourceName: sourceName);
    }

    final parseResult = _csvParser.parseCsvContent(
      csvContent,
      sourceName: sourceName,
      startOrderIndex: startOrderIndex,
    );

    return _processAndUpsertParsedItems(
      parseResult.items,
      totalFound: parseResult.totalRows,
      sourceName: sourceName,
    );
  }

  Future<ImportSummary> restoreFromBackup(
    List<int> bytes, {
    String sourceName = 'backup.savedex',
  }) async {
    final fileType = BackupExportService.detectFileType(
      filename: sourceName,
      bytes: bytes,
    );

    switch (fileType) {
      case BackupFileType.redditZip:
        return importFromZip(bytes);
      case BackupFileType.savedexCsv:
      case BackupFileType.redditCsv:
        final content = utf8.decode(bytes, allowMalformed: true);
        return importFromCsvContent(content, sourceName);
      case BackupFileType.savedex:
      case BackupFileType.json:
        final payload = _backupExport.parseBackup(bytes);
        return restoreFromPayload(payload, sourceName: sourceName);
      case BackupFileType.unknown:
        final lower = sourceName.toLowerCase();
        final preview = utf8
            .decode(bytes.take(500).toList(), allowMalformed: true)
            .trimLeft();
        final isJsonContent =
            lower.endsWith('.json') ||
            lower.endsWith('.savedex') ||
            preview.startsWith('{') ||
            preview.startsWith('[');

        if (isJsonContent) {
          final payload = _backupExport.parseBackup(bytes);
          return await restoreFromPayload(payload, sourceName: sourceName);
        }

        try {
          final content = utf8.decode(bytes, allowMalformed: true);
          return await importFromCsvContent(content, sourceName);
        } catch (_) {
          throw const FormatException(
            'Unsupported backup file format. Expected .savedex, .json, .csv, or .zip',
          );
        }
    }
  }

  Future<ImportSummary> restoreFromPayload(
    SavedexBackupPayload payload, {
    String sourceName = 'Savedex Backup',
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final total = payload.items.length;
    if (total == 0) {
      stopwatch.stop();
      final totalInDb = await getTotalCount();
      return ImportSummary(
        totalFound: 0,
        newItemsImported: 0,
        updatedItems: 0,
        skippedItems: 0,
        duration: stopwatch.elapsed,
        sourceFile: sourceName,
        totalInDatabase: totalInDb,
      );
    }

    String fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    onProgress?.call(0.0, 'Restoring 0 of ${fmt(total)} items...');

    int newCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;
    int processed = 0;

    const chunkSize = 200;

    await db.transaction(() async {
      for (var i = 0; i < total; i += chunkSize) {
        final end = (i + chunkSize > total) ? total : i + chunkSize;
        final chunk = payload.items.sublist(i, end);

        final chunkIds = chunk
            .map((c) => c.id.present ? c.id.value : '')
            .where((id) => id.isNotEmpty)
            .toList();

        final entries = await (db.select(
          db.savedItemsTable,
        )..where((t) => t.id.isIn(chunkIds))).get();
        final existingMap = {for (final e in entries) e.id: e};

        final toUpsert = <SavedItemsTableCompanion>[];

        for (final companion in chunk) {
          final id = companion.id.present ? companion.id.value : '';
          if (id.isEmpty) continue;
          final existing = existingMap[id];

          if (existing == null) {
            newCount++;
            toUpsert.add(companion);
          } else {
            final companionStarred = companion.isStarred.present
                ? companion.isStarred.value
                : false;
            final companionArchived = companion.isArchived.present
                ? companion.isArchived.value
                : false;
            final companionArchiveRecovered =
                companion.isArchiveRecovered.present
                ? companion.isArchiveRecovered.value
                : false;
            final companionNote = companion.userNote.present
                ? companion.userNote.value
                : null;
            final companionTitle = companion.title.present
                ? companion.title.value
                : null;
            final companionEnrichment = companion.enrichmentStatus.present
                ? companion.enrichmentStatus.value
                : null;
            final companionScore = companion.score.present
                ? companion.score.value
                : null;
            final companionNumComments = companion.numComments.present
                ? companion.numComments.value
                : null;
            final companionBody = companion.body.present
                ? companion.body.value
                : null;
            final companionAuthor = companion.author.present
                ? companion.author.value
                : null;
            final companionMediaUrl = companion.mediaUrl.present
                ? companion.mediaUrl.value
                : null;
            final companionThumbnailUrl = companion.thumbnailUrl.present
                ? companion.thumbnailUrl.value
                : null;
            final companionMediaType = companion.mediaType.present
                ? companion.mediaType.value
                : null;
            final companionPostFlair = companion.postFlair.present
                ? companion.postFlair.value
                : null;
            final companionSubredditType = companion.subredditType.present
                ? companion.subredditType.value
                : null;

            final starNeedsUpdate = !existing.isStarred && companionStarred;
            final archiveNeedsUpdate =
                !existing.isArchived && companionArchived;
            final archiveRecoveredNeedsUpdate =
                !existing.isArchiveRecovered && companionArchiveRecovered;
            final noteNeedsUpdate =
                (existing.userNote == null || existing.userNote!.isEmpty) &&
                companionNote != null &&
                companionNote.isNotEmpty;
            final titleNeedsUpdate =
                (existing.title == 'Untitled Post' || existing.title.isEmpty) &&
                companionTitle != null &&
                companionTitle.isNotEmpty &&
                companionTitle != 'Untitled Post' &&
                companionTitle != '[deleted]' &&
                companionTitle != '[removed]';
            final enrichmentNeedsUpdate =
                existing.enrichmentStatus != EnrichmentStatus.enriched &&
                companionEnrichment == EnrichmentStatus.enriched;
            final scoreNeedsUpdate =
                existing.score == 0 &&
                companionScore != null &&
                companionScore != 0;
            final commentsNeedsUpdate =
                existing.numComments == 0 &&
                companionNumComments != null &&
                companionNumComments != 0;
            final bodyNeedsUpdate =
                (existing.body == null || existing.body!.isEmpty) &&
                companionBody != null &&
                companionBody.isNotEmpty &&
                companionBody != '[deleted]' &&
                companionBody != '[removed]';
            final authorNeedsUpdate =
                (existing.author == null ||
                    existing.author!.isEmpty ||
                    existing.author == '[deleted]') &&
                companionAuthor != null &&
                companionAuthor.isNotEmpty &&
                companionAuthor != '[deleted]';
            final mediaNeedsUpdate =
                (existing.mediaUrl == null || existing.mediaUrl!.isEmpty) &&
                companionMediaUrl != null &&
                companionMediaUrl.isNotEmpty;
            final thumbnailNeedsUpdate =
                companionThumbnailUrl != null &&
                companionThumbnailUrl.isNotEmpty &&
                existing.thumbnailUrl != companionThumbnailUrl;
            final mediaTypeNeedsUpdate =
                existing.mediaType == MediaType.text &&
                companionMediaType != null &&
                companionMediaType != MediaType.text;
            final flairNeedsUpdate =
                (existing.postFlair == null || existing.postFlair!.isEmpty) &&
                companionPostFlair != null &&
                companionPostFlair.isNotEmpty;
            final subTypeNeedsUpdate =
                (existing.subredditType.isEmpty ||
                    existing.subredditType == 'public') &&
                companionSubredditType != null &&
                companionSubredditType.isNotEmpty &&
                companionSubredditType != 'public';

            if (starNeedsUpdate ||
                archiveNeedsUpdate ||
                archiveRecoveredNeedsUpdate ||
                noteNeedsUpdate ||
                titleNeedsUpdate ||
                enrichmentNeedsUpdate ||
                scoreNeedsUpdate ||
                commentsNeedsUpdate ||
                bodyNeedsUpdate ||
                authorNeedsUpdate ||
                mediaNeedsUpdate ||
                thumbnailNeedsUpdate ||
                mediaTypeNeedsUpdate ||
                flairNeedsUpdate ||
                subTypeNeedsUpdate) {
              updatedCount++;
              toUpsert.add(
                companion.copyWith(
                  isStarred: Value(existing.isStarred || companionStarred),
                  isArchived: Value(existing.isArchived || companionArchived),
                  isArchiveRecovered: Value(
                    existing.isArchiveRecovered ||
                        (companion.isArchiveRecovered.present &&
                            companion.isArchiveRecovered.value),
                  ),
                  userNote: noteNeedsUpdate
                      ? Value(companionNote)
                      : Value(existing.userNote),
                  title: titleNeedsUpdate
                      ? Value(companionTitle)
                      : Value(existing.title),
                  enrichmentStatus: enrichmentNeedsUpdate
                      ? Value(companionEnrichment ?? existing.enrichmentStatus)
                      : Value(existing.enrichmentStatus),
                  score: scoreNeedsUpdate
                      ? Value(companionScore)
                      : Value(existing.score),
                  numComments: commentsNeedsUpdate
                      ? Value(companionNumComments)
                      : Value(existing.numComments),
                  body: bodyNeedsUpdate
                      ? Value(companionBody)
                      : Value(existing.body),
                  author: authorNeedsUpdate
                      ? Value(companionAuthor)
                      : Value(existing.author),
                  mediaUrl: mediaNeedsUpdate
                      ? Value(companionMediaUrl)
                      : Value(existing.mediaUrl),
                  thumbnailUrl: thumbnailNeedsUpdate
                      ? Value(companionThumbnailUrl)
                      : Value(existing.thumbnailUrl),
                  mediaType: mediaTypeNeedsUpdate
                      ? Value(companionMediaType)
                      : Value(existing.mediaType),
                  postFlair: flairNeedsUpdate
                      ? Value(companionPostFlair)
                      : Value(existing.postFlair),
                  subredditType: subTypeNeedsUpdate
                      ? Value(companionSubredditType)
                      : Value(existing.subredditType),
                  createdAtUtc: existing.createdAtUtc != null
                      ? Value(existing.createdAtUtc)
                      : (companion.createdAtUtc.present
                            ? companion.createdAtUtc
                            : const Value.absent()),
                  savedAtUtc: Value(existing.savedAtUtc),
                  importOrder: existing.importOrder > 0
                      ? Value(existing.importOrder)
                      : (companion.importOrder.present
                            ? companion.importOrder
                            : const Value.absent()),
                ),
              );
            } else {
              skippedCount++;
            }
          }
        }

        if (toUpsert.isNotEmpty) {
          await db.upsertBatch(toUpsert);
        }

        processed = end;
        final prog = processed / total;
        onProgress?.call(
          prog,
          'Restoring ${fmt(processed)} of ${fmt(total)} items...',
        );
      }

      if (payload.itemCollections.isNotEmpty) {
        final existingCollections = await db.select(db.collectionsTable).get();
        final collectionNameToId = <String, int>{};
        for (final c in existingCollections) {
          collectionNameToId[c.name.toLowerCase()] = c.id;
        }

        for (final collections in payload.itemCollections.values) {
          for (final collection in collections) {
            final lower = collection.name.toLowerCase();
            if (!collectionNameToId.containsKey(lower)) {
              final insertedId = await db
                  .into(db.collectionsTable)
                  .insert(
                    CollectionsTableCompanion.insert(
                      name: collection.name,
                      description: Value(collection.description),
                      colorValue: Value(collection.colorValue),
                    ),
                    mode: InsertMode.insertOrIgnore,
                  );
              if (insertedId > 0) {
                collectionNameToId[lower] = insertedId;
              } else {
                final found =
                    await (db.select(db.collectionsTable)
                          ..where((c) => c.name.equals(collection.name)))
                        .getSingleOrNull();
                if (found != null) {
                  collectionNameToId[lower] = found.id;
                }
              }
            }
          }
        }

        final linkCompanions = <ItemCollectionsTableCompanion>[];
        for (final entry in payload.itemCollections.entries) {
          final itemId = entry.key;
          for (final collection in entry.value) {
            final colId = collectionNameToId[collection.name.toLowerCase()];
            if (colId != null) {
              linkCompanions.add(
                ItemCollectionsTableCompanion.insert(
                  itemId: itemId,
                  collectionId: colId,
                ),
              );
            }
          }
        }

        if (linkCompanions.isNotEmpty) {
          const linkChunkSize = 200;
          for (var i = 0; i < linkCompanions.length; i += linkChunkSize) {
            final chunk = linkCompanions.sublist(
              i,
              i + linkChunkSize > linkCompanions.length
                  ? linkCompanions.length
                  : i + linkChunkSize,
            );
            await db.batch((batch) {
              batch.insertAll(
                db.itemCollectionsTable,
                chunk,
                mode: InsertMode.insertOrIgnore,
              );
            });
          }
        }
      }
    });

    onProgress?.call(1.0, 'Restore complete!');
    final totalInDb = await getTotalCount();
    stopwatch.stop();

    return ImportSummary(
      totalFound: payload.items.length,
      newItemsImported: newCount,
      updatedItems: updatedCount,
      skippedItems: skippedCount,
      duration: stopwatch.elapsed,
      sourceFile: sourceName,
      totalInDatabase: totalInDb,
    );
  }

  Future<ImportSummary> importFromZip(List<int> zipBytes) async {
    final parseResults = _csvParser.parseZipArchive(zipBytes);
    final stopwatch = Stopwatch()..start();

    int totalFound = 0;
    int newImported = 0;
    int updated = 0;
    int skipped = 0;

    for (final result in parseResults) {
      final summary = await _processAndUpsertParsedItems(
        result.items,
        totalFound: result.totalRows,
        sourceName: result.sourceName,
      );
      totalFound += summary.totalFound;
      newImported += summary.newItemsImported;
      updated += summary.updatedItems;
      skipped += summary.skippedItems;
    }

    final totalInDb = await getTotalCount();
    stopwatch.stop();
    return ImportSummary(
      totalFound: totalFound,
      newItemsImported: newImported,
      updatedItems: updated,
      skippedItems: skipped,
      duration: stopwatch.elapsed,
      sourceFile: 'Reddit Takeout ZIP',
      totalInDatabase: totalInDb,
    );
  }

  Future<ImportSummary> _processAndUpsertParsedItems(
    List<SavedItemsTableCompanion> companions, {
    required int totalFound,
    required String sourceName,
    bool reconcileOrder = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    if (companions.isEmpty) {
      stopwatch.stop();
      final totalInDb = await getTotalCount();
      return ImportSummary(
        totalFound: totalFound,
        newItemsImported: 0,
        updatedItems: 0,
        skippedItems: totalFound,
        duration: stopwatch.elapsed,
        sourceFile: sourceName,
        totalInDatabase: totalInDb,
      );
    }

    final ids = companions.map((c) => c.id.value).toList();
    final existingMap = <String, SavedItemEntry>{};
    const chunkSize = 200;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        i + chunkSize > ids.length ? ids.length : i + chunkSize,
      );
      final entries = await (db.select(
        db.savedItemsTable,
      )..where((t) => t.id.isIn(chunk))).get();
      for (final e in entries) {
        existingMap[e.id] = e;
      }
    }

    final bool batchHasUnreconciledCsv =
        reconcileOrder &&
        companions.any((c) {
          final id = c.id.present ? c.id.value : '';
          final existing = existingMap[id];
          return existing != null && existing.csvSource != 'reddit_api';
        });

    int newCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;

    final List<SavedItemsTableCompanion> toUpsert = [];

    for (final companion in companions) {
      final id = companion.id.present ? companion.id.value : '';
      if (id.isEmpty) continue;
      final existing = existingMap[id];

      if (existing == null) {
        // new item not in database > insert
        newCount++;
        toUpsert.add(companion);
      } else {
        final companionEnrichment = companion.enrichmentStatus.present
            ? companion.enrichmentStatus.value
            : null;
        final companionTitle = companion.title.present
            ? companion.title.value
            : null;
        final companionScore = companion.score.present
            ? companion.score.value
            : null;
        final companionNumComments = companion.numComments.present
            ? companion.numComments.value
            : null;
        final companionBody = companion.body.present
            ? companion.body.value
            : null;
        final companionSubredditType = companion.subredditType.present
            ? companion.subredditType.value
            : null;

        // compare
        final needsEnrichment =
            existing.enrichmentStatus != EnrichmentStatus.enriched &&
            companionEnrichment == EnrichmentStatus.enriched;
        final needsTitleFix =
            (existing.title == 'Untitled Post' || existing.title.isEmpty) &&
            companionTitle != null &&
            companionTitle.isNotEmpty &&
            companionTitle != 'Untitled Post' &&
            companionTitle != '[deleted]' &&
            companionTitle != '[removed]';
        final needsScoreUpdate =
            existing.score == 0 &&
            companionScore != null &&
            companionScore != 0;
        final needsBodyUpdate =
            (existing.body == null || existing.body!.isEmpty) &&
            companionBody != null &&
            companionBody.isNotEmpty &&
            companionBody != '[deleted]' &&
            companionBody != '[removed]';
        final needsSubredditTypeUpdate =
            (existing.subredditType.isEmpty ||
                existing.subredditType == 'public') &&
            companionSubredditType != null &&
            companionSubredditType.isNotEmpty &&
            companionSubredditType != 'public';
        final needsOrderReconciliation =
            batchHasUnreconciledCsv && companion.importOrder.present;

        if (needsEnrichment ||
            needsTitleFix ||
            needsScoreUpdate ||
            needsBodyUpdate ||
            needsSubredditTypeUpdate ||
            needsOrderReconciliation) {
          updatedCount++;
          // preserve user modifications and flags
          toUpsert.add(
            companion.copyWith(
              // user flags, notes, and ordering
              isStarred: Value(existing.isStarred),
              isArchived: Value(existing.isArchived),
              isArchiveRecovered: Value(existing.isArchiveRecovered),
              userNote: Value(existing.userNote),
              csvSource: needsOrderReconciliation
                  ? const Value('reddit_api')
                  : Value(existing.csvSource),
              importOrder: needsOrderReconciliation
                  ? companion.importOrder
                  : Value(existing.importOrder),
              savedAtUtc: Value(existing.savedAtUtc),

              title: needsTitleFix
                  ? Value(companionTitle)
                  : Value(existing.title),
              parentPostTitle: existing.parentPostTitle != null
                  ? Value(existing.parentPostTitle)
                  : (companion.parentPostTitle.present
                        ? companion.parentPostTitle
                        : const Value.absent()),
              parentPostId: existing.parentPostId != null
                  ? Value(existing.parentPostId)
                  : (companion.parentPostId.present
                        ? companion.parentPostId
                        : const Value.absent()),

              createdAtUtc: existing.createdAtUtc != null
                  ? Value(existing.createdAtUtc)
                  : (companion.createdAtUtc.present
                        ? companion.createdAtUtc
                        : const Value.absent()),
              enrichmentStatus: needsEnrichment
                  ? Value(companionEnrichment ?? existing.enrichmentStatus)
                  : Value(existing.enrichmentStatus),
              score: (companionScore != null && companionScore != 0)
                  ? Value(companionScore)
                  : Value(existing.score),
              numComments:
                  (companionNumComments != null && companionNumComments != 0)
                  ? Value(companionNumComments)
                  : Value(existing.numComments),
              isNsfw: existing.isNsfw
                  ? const Value(true)
                  : (companion.isNsfw.present
                        ? companion.isNsfw
                        : const Value(false)),
              author:
                  (existing.author != null &&
                      existing.author!.isNotEmpty &&
                      existing.author != '[deleted]')
                  ? Value(existing.author)
                  : (companion.author.present
                        ? companion.author
                        : const Value.absent()),
              body: needsBodyUpdate
                  ? Value(companionBody)
                  : Value(existing.body),
              url: existing.url != null
                  ? Value(existing.url)
                  : (companion.url.present
                        ? companion.url
                        : const Value.absent()),
              thumbnailUrl: existing.thumbnailUrl != null
                  ? Value(existing.thumbnailUrl)
                  : (companion.thumbnailUrl.present
                        ? companion.thumbnailUrl
                        : const Value.absent()),
              mediaUrl: existing.mediaUrl != null
                  ? Value(existing.mediaUrl)
                  : (companion.mediaUrl.present
                        ? companion.mediaUrl
                        : const Value.absent()),
              mediaType: existing.mediaType != MediaType.text
                  ? Value(existing.mediaType)
                  : (companion.mediaType.present
                        ? companion.mediaType
                        : Value(existing.mediaType)),
              postFlair: existing.postFlair != null
                  ? Value(existing.postFlair)
                  : (companion.postFlair.present
                        ? companion.postFlair
                        : const Value.absent()),
              subredditType:
                  (companionSubredditType != null &&
                      companionSubredditType.isNotEmpty)
                  ? Value(companionSubredditType)
                  : Value(existing.subredditType),
            ),
          );
        } else {
          // iff already in database skip write
          skippedCount++;
        }
      }
    }

    if (toUpsert.isNotEmpty) {
      await db.upsertBatch(toUpsert);
    }

    final totalInDb = await getTotalCount();
    stopwatch.stop();

    return ImportSummary(
      totalFound: totalFound,
      newItemsImported: newCount,
      updatedItems: updatedCount,
      skippedItems: skippedCount,
      duration: stopwatch.elapsed,
      sourceFile: sourceName,
      totalInDatabase: totalInDb,
    );
  }

  Future<ImportSummary> pullSavedFromReddit({
    int maxItems = 1000,
    void Function(int fetchedCount, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!_redditApi.hasUserOAuth) {
      throw Exception(
        'Reddit account is not authenticated via OAuth. Please log in in Settings first.',
      );
    }

    onProgress?.call(0, 'Connecting to Reddit...');

    var userResult = await _redditApi.fetchMyUsername();
    if (userResult.username == null) {
      await Future.delayed(const Duration(milliseconds: 600));
      userResult = await _redditApi.fetchMyUsername();
    }
    if (userResult.username == null) {
      throw Exception(
        'Failed to get Reddit user info: ${userResult.error ?? "Unknown error"}',
      );
    }
    final username = userResult.username!;
    onProgress?.call(0, 'Logged in as u/$username. Fetching saved items...');

    final maxOrderQuery = db.selectOnly(db.savedItemsTable)
      ..addColumns([db.savedItemsTable.importOrder.max()]);
    final maxOrderResult = await maxOrderQuery.getSingleOrNull();
    final currentMaxOrder =
        (maxOrderResult?.read(db.savedItemsTable.importOrder.max()) ?? 0);

    final List<SavedItemsTableCompanion> allCompanions = [];
    String? after;
    int pageNum = 0;
    const int pageLimit = 100;
    final int maxPages = (maxItems / pageLimit).ceil();

    while (pageNum < maxPages && allCompanions.length < maxItems) {
      pageNum++;
      onProgress?.call(
        allCompanions.length,
        'Fetching page $pageNum from Reddit (retrieved ${allCompanions.length})...',
      );

      final remaining = maxItems - allCompanions.length;
      final currentLimit = remaining < pageLimit ? remaining : pageLimit;

      var pageResult = await _redditApi.fetchSavedPage(
        username: username,
        after: after,
        limit: currentLimit,
      );

      if (pageResult.isRateLimited) {
        onProgress?.call(
          allCompanions.length,
          'Rate limit hit. Cooling down for 3 seconds...',
        );
        await Future.delayed(const Duration(seconds: 3));
        pageResult = await _redditApi.fetchSavedPage(
          username: username,
          after: after,
          limit: currentLimit,
        );
      }

      if (pageResult.error != null) {
        debugPrint('[RedditSync] Error on page $pageNum: ${pageResult.error}');
        if (allCompanions.isEmpty) {
          throw Exception(
            'Failed to fetch saved items from Reddit: ${pageResult.error}',
          );
        } else {
          debugPrint(
            '[RedditSync] Stopping pagination early at page $pageNum after fetching ${allCompanions.length} items due to: ${pageResult.error}',
          );
          onProgress?.call(
            allCompanions.length,
            'Sync interrupted at page $pageNum. Saving ${allCompanions.length} retrieved items...',
          );
          break;
        }
      }

      final itemsToAdd = pageResult.items.length > remaining
          ? pageResult.items.sublist(0, remaining)
          : pageResult.items;
      allCompanions.addAll(itemsToAdd);
      debugPrint(
        '[RedditSync] Page $pageNum: fetched ${itemsToAdd.length} items (total: ${allCompanions.length}), next after: ${pageResult.after}',
      );
      onProgress?.call(
        allCompanions.length,
        'Retrieved ${allCompanions.length} saved items from Reddit...',
      );

      after = pageResult.after;
      if (after == null || after.isEmpty || pageResult.items.isEmpty) {
        debugPrint(
          '[RedditSync] Reached end of saved listing (after was null/empty).',
        );
        break; // reached the end of saved items
      }

      if (allCompanions.length >= maxItems) {
        debugPrint(
          '[RedditSync] Reached max requested items limit ($maxItems).',
        );
        break;
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (allCompanions.isEmpty) {
      stopwatch.stop();
      final totalInDb = await getTotalCount();
      return ImportSummary(
        totalFound: 0,
        newItemsImported: 0,
        updatedItems: 0,
        skippedItems: 0,
        duration: stopwatch.elapsed,
        sourceFile: 'Reddit OAuth Sync (u/$username)',
        totalInDatabase: totalInDb,
      );
    }

    final finalCompanions = allCompanions.length > maxItems
        ? allCompanions.sublist(0, maxItems)
        : allCompanions;

    onProgress?.call(
      finalCompanions.length,
      'Saving ${finalCompanions.length} items to database...',
    );

    final total = finalCompanions.length;
    final baseOrder = currentMaxOrder + 1;
    final orderedCompanions = <SavedItemsTableCompanion>[];
    for (int i = 0; i < total; i++) {
      final assignedOrder = baseOrder + (total - 1 - i);
      orderedCompanions.add(
        finalCompanions[i].copyWith(importOrder: Value(assignedOrder)),
      );
    }

    final summary = await _processAndUpsertParsedItems(
      orderedCompanions,
      totalFound: total,
      sourceName: 'Reddit OAuth Sync (u/$username)',
      reconcileOrder: true,
    );

    stopwatch.stop();
    return summary;
  }

  Future<({bool success, String? error})> enrichItem(
    SavedItem item, {
    String? clientId,
    String? clientSecret,
  }) {
    final existing = _inFlightEnrichments[item.id];
    if (existing != null) {
      return existing;
    }

    final future = _executeEnrichItem(
      item,
      clientId: clientId,
      clientSecret: clientSecret,
    );
    _inFlightEnrichments[item.id] = future;
    return future.whenComplete(() {
      _inFlightEnrichments.remove(item.id);
    });
  }

  Future<({bool success, String? error})> recoverItemFromArchive(
    SavedItem item,
  ) async {
    final current = await getItemById(item.id);
    if (current == null) {
      return (success: false, error: 'Item no longer exists');
    }
    if (!current.canAttemptArchiveRecovery) {
      return (
        success: false,
        error:
            'Archive recovery is available only for failed or removed content',
      );
    }

    return _recoverItemsFromArchive([current]).then((results) {
      return results[current.id] ??
          (success: false, error: 'Archive recovery failed');
    });
  }

  void cancelArchiveRecovery() {
    _pullPushApi.cancelCurrentRequests();
    _arcticShiftApi.cancelCurrentRequests();
  }

  Future<Map<String, ({bool success, String? error})>> recoverItemsFromArchive(
    List<SavedItem> items, {
    bool Function()? isCancelled,
  }) {
    return _recoverItemsFromArchive(items, isCancelled: isCancelled);
  }

  Future<Map<String, ({bool success, String? error})>> _recoverItemsFromArchive(
    List<SavedItem> items, {
    bool Function()? isCancelled,
  }) async {
    final results = <String, ({bool success, String? error})>{};
    final currentItems = <SavedItem>[];
    for (final item in items) {
      if (isCancelled?.call() == true) return results;
      final current = await getItemById(item.id);
      if (current == null) {
        debugPrint('[ArchiveRecovery] Item ${item.id} no longer exists in DB');
        results[item.id] = (success: false, error: 'Item no longer exists');
      } else if (!current.canAttemptArchiveRecovery) {
        debugPrint(
          '[ArchiveRecovery] Item ${item.id} ("${item.title}") not eligible (status: ${current.enrichmentStatus.name}, hasRemoved: ${current.hasRemovedContent})',
        );
        results[item.id] = (
          success: false,
          error: 'Item is no longer eligible for archive recovery',
        );
      } else {
        currentItems.add(current);
      }
    }

    for (final itemType in ItemType.values) {
      if (isCancelled?.call() == true) break;
      final typedItems = currentItems
          .where((item) => item.itemType == itemType)
          .toList();
      if (typedItems.isEmpty) continue;

      final backend = _settingsRepository.settings.archiveBackend;
      final primaryIsPullPush = backend != ArchiveBackend.arcticShift;
      final primaryMetadata = primaryIsPullPush
          ? await _pullPushApi.fetchMetadataBatch(
              ids: typedItems.map((item) => item.id).toList(),
              itemType: itemType,
              isCancelled: isCancelled,
            )
          : await _arcticShiftApi.fetchMetadataBatch(
              ids: typedItems.map((item) => item.id).toList(),
              itemType: itemType,
              isCancelled: isCancelled,
            );
      if (isCancelled?.call() == true) break;

      final pendingFallback = <SavedItem>[];
      for (final item in typedItems) {
        if (isCancelled?.call() == true) break;
        final meta = primaryMetadata[item.id];
        if (meta != null && meta.isSuccess) {
          await _writeRecoveredMetadata(item, meta);
          results[item.id] = (success: true, error: null);
        } else if (backend == ArchiveBackend.automatic) {
          pendingFallback.add(item);
        } else {
          results[item.id] = (
            success: false,
            error: meta?.errorMessage ?? 'Archive lookup failed',
          );
        }
      }

      if (isCancelled?.call() == true) break;
      if (pendingFallback.isNotEmpty) {
        final fallbackIsPullPush = !primaryIsPullPush;
        debugPrint(
          '[ArchiveRecovery] [${fallbackIsPullPush ? 'PullPush' : 'ArcticShift'} Fallback] Querying ${pendingFallback.length} ${itemType.name}(s)',
        );
        final fallbackMetadata = fallbackIsPullPush
            ? await _pullPushApi.fetchMetadataBatch(
                ids: pendingFallback.map((item) => item.id).toList(),
                itemType: itemType,
                isCancelled: isCancelled,
              )
            : await _arcticShiftApi.fetchMetadataBatch(
                ids: pendingFallback.map((item) => item.id).toList(),
                itemType: itemType,
                isCancelled: isCancelled,
              );

        if (isCancelled?.call() == true) break;

        for (final item in pendingFallback) {
          if (isCancelled?.call() == true) break;
          final meta = fallbackMetadata[item.id];
          if (meta != null && meta.isSuccess) {
            await _writeRecoveredMetadata(item, meta);
            results[item.id] = (success: true, error: null);
          } else {
            final err = meta?.errorMessage ?? 'Archive lookup failed';
            debugPrint(
              '[ArchiveRecovery] Item ${item.id} failed across all archive sources: $err',
            );
            results[item.id] = (success: false, error: err);
          }
        }
      }
    }
    return results;
  }

  Future<int> _writeRecoveredMetadata(
    SavedItem current,
    EnrichedRedditData meta,
  ) {
    return (db.update(
      db.savedItemsTable,
    )..where((t) => t.id.equals(current.id))).write(
      SavedItemsTableCompanion(
        title: Value(meta.title ?? current.title),
        parentPostTitle: Value(meta.parentPostTitle ?? current.parentPostTitle),
        parentPostId: Value(meta.parentPostId ?? current.parentPostId),
        author: Value(meta.author ?? current.author),
        body: Value(meta.body ?? current.body),
        url: Value(meta.url ?? current.url),
        thumbnailUrl: Value(meta.thumbnailUrl ?? current.thumbnailUrl),
        mediaUrl: Value(meta.mediaUrl ?? current.mediaUrl),
        galleryImages: Value(
          meta.galleryImages.isEmpty
              ? current.galleryImagesJson
              : meta.galleryImagesJson,
        ),
        galleryPreviewImages: Value(
          meta.galleryPreviewImages.isEmpty
              ? current.galleryPreviewImagesJson
              : meta.galleryPreviewImagesJson,
        ),
        mediaType: Value(
          meta.mediaType != MediaType.text ? meta.mediaType : current.mediaType,
        ),
        score: Value(meta.score),
        numComments: Value(meta.numComments),
        isNsfw: Value(meta.isNsfw),
        postFlair: Value(meta.postFlair ?? current.postFlair),
        subredditType: Value(meta.subredditType),
        createdAtUtc: Value(meta.createdAtUtc ?? current.createdAtUtc),
        enrichmentStatus: const Value(EnrichmentStatus.enriched),
        isArchiveRecovered: const Value(true),
      ),
    );
  }

  Future<({bool success, String? error})> _executeEnrichItem(
    SavedItem item, {
    String? clientId,
    String? clientSecret,
  }) async {
    try {
      final meta = await _redditApi.fetchMetadata(
        id: item.id,
        permalink: item.permalink,
        itemType: item.itemType,
      );

      if (!meta.isSuccess) {
        await (db.update(
          db.savedItemsTable,
        )..where((t) => t.id.equals(item.id))).write(
          SavedItemsTableCompanion(
            enrichmentStatus: Value(EnrichmentStatus.failed),
            isArchiveRecovered: Value(
              _isDeletedOrInaccessibleError(meta.errorMessage)
                  ? false
                  : item.isArchiveRecovered,
            ),
          ),
        );
        return (success: false, error: meta.errorMessage);
      }

      final refreshedHasRemovedContent = _hasRemovedContent(
        meta.author,
        meta.body,
        meta.title,
      );
      await (db.update(
        db.savedItemsTable,
      )..where((t) => t.id.equals(item.id))).write(
        SavedItemsTableCompanion(
          title: Value(meta.title ?? item.title),
          parentPostTitle: Value(meta.parentPostTitle ?? item.parentPostTitle),
          parentPostId: Value(meta.parentPostId ?? item.parentPostId),
          author: Value(meta.author ?? item.author),
          body: Value(meta.body ?? item.body),
          url: Value(meta.url ?? item.url),
          thumbnailUrl: Value(meta.thumbnailUrl ?? item.thumbnailUrl),
          mediaUrl: Value(meta.mediaUrl ?? item.mediaUrl),
          galleryImages: Value(
            meta.galleryImages.isEmpty
                ? item.galleryImagesJson
                : meta.galleryImagesJson,
          ),
          galleryPreviewImages: Value(
            meta.galleryPreviewImages.isEmpty
                ? item.galleryPreviewImagesJson
                : meta.galleryPreviewImagesJson,
          ),
          mediaType: Value(meta.mediaType),
          score: Value(meta.score),
          numComments: Value(meta.numComments),
          isNsfw: Value(meta.isNsfw),
          postFlair: Value(meta.postFlair ?? item.postFlair),
          subredditType: Value(meta.subredditType),
          createdAtUtc: Value(meta.createdAtUtc ?? item.createdAtUtc),
          enrichmentStatus: const Value(EnrichmentStatus.enriched),
          isArchiveRecovered: Value(
            refreshedHasRemovedContent ? false : item.isArchiveRecovered,
          ),
        ),
      );
      return (success: true, error: null);
    } catch (e) {
      await (db.update(
        db.savedItemsTable,
      )..where((t) => t.id.equals(item.id))).write(
        SavedItemsTableCompanion(
          enrichmentStatus: Value(EnrichmentStatus.failed),
          isArchiveRecovered: Value(item.isArchiveRecovered),
        ),
      );
      return (success: false, error: e.toString());
    }
  }

  static bool _isDeletedOrInaccessibleError(String? error) {
    final normalized = error?.toLowerCase() ?? '';
    return normalized.contains('deleted or inaccessible') ||
        normalized.contains('item deleted') ||
        normalized.contains('inaccessible');
  }

  static bool _hasRemovedContent(String? author, String? body, String? title) {
    bool isRemovedMarker(String? value) {
      final normalized = value?.trim().toLowerCase();
      return normalized == '[deleted]' || normalized == '[removed]';
    }

    return isRemovedMarker(author) ||
        isRemovedMarker(body) ||
        isRemovedMarker(title);
  }

  Future<List<SavedItem>> getPendingEnrichmentItems({int limit = 50}) async {
    final entries = await db.getPendingEnrichmentItems(
      limit: limit,
      excludeIds: _inFlightEnrichments.keys.toList(),
    );
    return entries.map((e) => e.toDomain()).toList();
  }

  Future<int> getPendingEnrichmentCount() => db.getPendingEnrichmentCount();

  Future<List<SavedItem>> getArchiveRecoveryItems({
    int limit = 50,
    List<String> excludeIds = const [],
  }) async {
    final entries = await db.getArchiveRecoveryItems(
      limit: limit,
      excludeIds: excludeIds,
    );
    return entries.map((e) => e.toDomain()).toList();
  }

  Future<int> getArchiveRecoveryCount() => db.getArchiveRecoveryCount();

  Stream<int> watchArchiveRecoveryCount() => db.watchArchiveRecoveryCount();

  Stream<int> watchPendingEnrichmentCount() => db.watchPendingEnrichmentCount();

  Future<List<(String, int)>> getSubredditsWithCounts() =>
      db.getSubredditsWithCounts();

  Stream<List<(String, int)>> watchSubredditsWithCounts() =>
      db.watchSubredditsWithCounts();

  Future<List<(String, int)>> getAuthorsWithCounts() =>
      db.getAuthorsWithCounts();

  Future<List<(String, int)>> getFlairsWithCounts() => db.getFlairsWithCounts();

  Future<List<String>> getDistinctAuthors() => db.getDistinctAuthors();

  Future<int> getTotalCount() => db.getTotalCount();

  Future<void> clearAllData() => db.clearAllData();
}
