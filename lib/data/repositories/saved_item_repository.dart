import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/services/csv_parser_service.dart';
import 'package:savedex/data/services/reddit_api_service.dart';

class SavedItemRepository {
  final AppDatabase db;
  final CsvParserService _csvParser;
  final RedditApiService _redditApi;

  SavedItemRepository({
    required this.db,
    CsvParserService? csvParser,
    RedditApiService? redditApi,
  }) : _csvParser = csvParser ?? CsvParserService(),
       _redditApi = redditApi ?? RedditApiService();

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
          tagIds: filter.selectedTagIds,
          sortOption: filter.sortOption,
          dateRangeStart: filter.dateRangeStart,
          dateRangeEnd: filter.dateRangeEnd,
        )
        .map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  Future<SavedItem?> getItemById(String id) async {
    final query = db.select(db.savedItemsTable)..where((t) => t.id.equals(id));
    final entry = await query.getSingleOrNull();
    if (entry == null) return null;

    final tags =
        await (db.select(db.tagsTable).join([
          innerJoin(
            db.itemTagsTable,
            db.itemTagsTable.tagId.equalsExp(db.tagsTable.id),
          ),
        ])..where(db.itemTagsTable.itemId.equals(id))).map((row) {
          final t = row.readTable(db.tagsTable);
          return Tag(id: t.id, name: t.name, colorValue: t.colorValue);
        }).get();

    return entry.toDomain(tags: tags);
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
    await db.transaction(() async {
      await (db.delete(
        db.itemTagsTable,
      )..where((t) => t.itemId.equals(id))).go();
      await (db.delete(db.savedItemsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<ImportSummary> importFromCsvContent(
    String csvContent,
    String sourceName, {
    int startOrderIndex = 0,
  }) async {
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

    stopwatch.stop();
    return ImportSummary(
      totalFound: totalFound,
      newItemsImported: newImported,
      updatedItems: updated,
      skippedItems: skipped,
      duration: stopwatch.elapsed,
      sourceFile: 'Reddit Takeout ZIP',
    );
  }

  Future<ImportSummary> _processAndUpsertParsedItems(
    List<SavedItemsTableCompanion> companions, {
    required int totalFound,
    required String sourceName,
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

    int newCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;

    final List<SavedItemsTableCompanion> toUpsert = [];

    for (final companion in companions) {
      final id = companion.id.value;
      final existing = existingMap[id];

      if (existing == null) {
        // new item not in database > insert
        newCount++;
        toUpsert.add(companion);
      } else {
        // compare
        final needsEnrichment =
            existing.enrichmentStatus != EnrichmentStatus.enriched &&
            companion.enrichmentStatus.value == EnrichmentStatus.enriched;
        final needsTitleFix =
            (existing.title == 'Untitled Post' || existing.title.isEmpty) &&
            companion.title.value != 'Untitled Post' &&
            companion.title.value.isNotEmpty;
        final needsScoreUpdate =
            existing.score == 0 && (companion.score.value) != 0;
        final needsBodyUpdate =
            (existing.body == null || existing.body!.isEmpty) &&
            companion.body.value != null &&
            companion.body.value!.isNotEmpty;

        if (needsEnrichment ||
            needsTitleFix ||
            needsScoreUpdate ||
            needsBodyUpdate) {
          updatedCount++;
          // preserve user modifications and flags
          toUpsert.add(
            companion.copyWith(
              // user flags, notes, and ordering
              isStarred: Value(existing.isStarred),
              isArchived: Value(existing.isArchived),
              userNote: Value(existing.userNote),
              importOrder: Value(existing.importOrder),
              savedAtUtc: Value(existing.savedAtUtc),

              title: needsTitleFix ? companion.title : Value(existing.title),
              parentPostTitle: existing.parentPostTitle != null
                  ? Value(existing.parentPostTitle)
                  : companion.parentPostTitle,
              parentPostId: existing.parentPostId != null
                  ? Value(existing.parentPostId)
                  : companion.parentPostId,

              createdAtUtc: existing.createdAtUtc != null
                  ? Value(existing.createdAtUtc)
                  : companion.createdAtUtc,
              enrichmentStatus: needsEnrichment
                  ? companion.enrichmentStatus
                  : Value(existing.enrichmentStatus),
              score: (companion.score.value) != 0
                  ? companion.score
                  : Value(existing.score),
              numComments: (companion.numComments.value) != 0
                  ? companion.numComments
                  : Value(existing.numComments),
              isNsfw: existing.isNsfw ? const Value(true) : companion.isNsfw,
              author: existing.author != null
                  ? Value(existing.author)
                  : companion.author,
              body: needsBodyUpdate ? companion.body : Value(existing.body),
              url: existing.url != null ? Value(existing.url) : companion.url,
              thumbnailUrl: existing.thumbnailUrl != null
                  ? Value(existing.thumbnailUrl)
                  : companion.thumbnailUrl,
              mediaUrl: existing.mediaUrl != null
                  ? Value(existing.mediaUrl)
                  : companion.mediaUrl,
              mediaType: existing.mediaType != MediaType.text
                  ? Value(existing.mediaType)
                  : companion.mediaType,
              postFlair: existing.postFlair != null
                  ? Value(existing.postFlair)
                  : companion.postFlair,
              subredditType: Value(existing.subredditType),
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

    final userResult = await _redditApi.fetchMyUsername();
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

    while (pageNum < maxPages) {
      pageNum++;
      onProgress?.call(
        allCompanions.length,
        'Fetching page $pageNum from Reddit (retrieved ${allCompanions.length})...',
      );

      var pageResult = await _redditApi.fetchSavedPage(
        username: username,
        after: after,
        limit: pageLimit,
        startImportOrder: 0,
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
          limit: pageLimit,
          startImportOrder: 0,
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

      allCompanions.addAll(pageResult.items);
      debugPrint(
        '[RedditSync] Page $pageNum: fetched ${pageResult.items.length} items (total: ${allCompanions.length}), next after: ${pageResult.after}',
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

    onProgress?.call(
      allCompanions.length,
      'Saving ${allCompanions.length} items to database...',
    );

    final total = allCompanions.length;
    final baseOrder = currentMaxOrder + 1;
    final orderedCompanions = <SavedItemsTableCompanion>[];
    for (int i = 0; i < total; i++) {
      final assignedOrder = baseOrder + (total - 1 - i);
      orderedCompanions.add(
        allCompanions[i].copyWith(importOrder: Value(assignedOrder)),
      );
    }

    final summary = await _processAndUpsertParsedItems(
      orderedCompanions,
      totalFound: total,
      sourceName: 'Reddit OAuth Sync (u/$username)',
    );

    stopwatch.stop();
    return summary;
  }

  Future<({bool success, String? error})> enrichItem(
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
          const SavedItemsTableCompanion(
            enrichmentStatus: Value(EnrichmentStatus.failed),
          ),
        );
        return (success: false, error: meta.errorMessage);
      }

      await (db.update(
        db.savedItemsTable,
      )..where((t) => t.id.equals(item.id))).write(
        SavedItemsTableCompanion(
          title: Value(meta.title ?? item.title),
          parentPostTitle: Value(meta.parentPostTitle ?? item.parentPostTitle),
          author: Value(meta.author ?? item.author),
          body: Value(meta.body ?? item.body),
          url: Value(meta.url ?? item.url),
          thumbnailUrl: Value(meta.thumbnailUrl ?? item.thumbnailUrl),
          mediaUrl: Value(meta.mediaUrl ?? item.mediaUrl),
          mediaType: Value(meta.mediaType),
          score: Value(meta.score),
          numComments: Value(meta.numComments),
          isNsfw: Value(meta.isNsfw),
          postFlair: Value(meta.postFlair ?? item.postFlair),
          subredditType: Value(meta.subredditType),
          createdAtUtc: Value(meta.createdAtUtc ?? item.createdAtUtc),
          enrichmentStatus: const Value(EnrichmentStatus.enriched),
        ),
      );
      return (success: true, error: null);
    } catch (e) {
      await (db.update(
        db.savedItemsTable,
      )..where((t) => t.id.equals(item.id))).write(
        const SavedItemsTableCompanion(
          enrichmentStatus: Value(EnrichmentStatus.failed),
        ),
      );
      return (success: false, error: e.toString());
    }
  }

  Future<List<SavedItem>> getPendingEnrichmentItems({int limit = 50}) async {
    final entries = await db.getPendingEnrichmentItems(limit: limit);
    return entries.map((e) => e.toDomain()).toList();
  }

  Future<int> getPendingEnrichmentCount() => db.getPendingEnrichmentCount();

  Future<List<(String, int)>> getSubredditsWithCounts() =>
      db.getSubredditsWithCounts();

  Future<List<(String, int)>> getAuthorsWithCounts() =>
      db.getAuthorsWithCounts();

  Future<List<(String, int)>> getFlairsWithCounts() => db.getFlairsWithCounts();

  Future<List<String>> getDistinctAuthors() => db.getDistinctAuthors();

  Future<int> getTotalCount() => db.getTotalCount();

  Future<void> clearAllData() => db.clearAllData();
}
