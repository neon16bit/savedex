import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/csv_helper.dart';
import 'package:savedex/core/utils/permalink_parser.dart';
import 'package:savedex/data/database/database.dart';

class CsvParseResult {
  final List<SavedItemsTableCompanion> items;
  final int totalRows;
  final int skippedRows;
  final String sourceName;

  const CsvParseResult({
    required this.items,
    required this.totalRows,
    required this.skippedRows,
    required this.sourceName,
  });
}

class CsvParserService {
  CsvParseResult parseCsvContent(
    String content, {
    required String sourceName,
    int startOrderIndex = 0,
  }) {
    final rows = CsvHelper.parseCsv(content);

    if (rows.isEmpty) {
      return CsvParseResult(
        items: [],
        totalRows: 0,
        skippedRows: 0,
        sourceName: sourceName,
      );
    }
    //inspect
    final headerRow = rows.first.map((e) => e.trim().toLowerCase()).toList();
    int idIndex = headerRow.indexOf('id');
    if (idIndex == -1) idIndex = headerRow.indexOf('post_id');
    if (idIndex == -1) idIndex = headerRow.indexOf('comment_id');

    int permalinkIndex = headerRow.indexOf('permalink');
    if (permalinkIndex == -1) permalinkIndex = headerRow.indexOf('link');
    if (permalinkIndex == -1) permalinkIndex = headerRow.indexOf('url');

    final bool hasHeader = idIndex != -1 || permalinkIndex != -1;

    // if header is missing
    if (idIndex == -1) idIndex = 0;
    if (permalinkIndex == -1) {
      permalinkIndex = headerRow.length > 1 ? 1 : 0;
    }

    final dataRows = hasHeader ? rows.skip(1).toList() : rows;

    final List<SavedItemsTableCompanion> parsedItems = [];
    int skippedCount = 0;
    int orderCounter = startOrderIndex;

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.isEmpty) {
        skippedCount++;
        continue;
      }

      final rawId = idIndex < row.length ? row[idIndex].trim() : '';
      final rawPermalink = permalinkIndex < row.length
          ? row[permalinkIndex].trim()
          : '';

      if (rawId.isEmpty && rawPermalink.isEmpty) {
        skippedCount++;
        continue;
      }

      // validate
      if (!PermalinkParser.isValidRedditPermalink(rawPermalink) &&
          !rawId.startsWith('t1_') &&
          !rawId.startsWith('t3_')) {
        skippedCount++;
        continue;
      }

      final parsed = PermalinkParser.parse(
        rawPermalink,
        rawId: rawId.isNotEmpty ? rawId : null,
      );
      final finalId = rawId.isNotEmpty
          ? rawId
          : (parsed.commentId ??
                parsed.postId ??
                'item_${orderCounter}_${DateTime.now().millisecondsSinceEpoch}');
      final now = DateTime.now().toUtc();

      final mediaType = parsed.itemType == ItemType.comment
          ? MediaType.comment
          : MediaType.text;

      parsedItems.add(
        SavedItemsTableCompanion(
          id: Value(finalId),
          permalink: Value(parsed.canonicalPermalink),
          itemType: Value(parsed.itemType),
          parentPostId: Value(parsed.postId),
          parentPostTitle: Value(
            parsed.isComment ? parsed.extractedTitle : null,
          ),
          title: Value(parsed.extractedTitle),
          subreddit: Value(parsed.subreddit ?? 'reddit'),
          mediaType: Value(mediaType),
          csvSource: Value(sourceName),
          importOrder: Value(orderCounter++),
          savedAtUtc: Value(now),
          enrichmentStatus: Value(EnrichmentStatus.slugOnly),
        ),
      );
    }

    return CsvParseResult(
      items: parsedItems,
      totalRows: dataRows.length,
      skippedRows: skippedCount,
      sourceName: sourceName,
    );
  }

  List<CsvParseResult> parseZipArchive(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final List<CsvParseResult> results = [];
    int orderOffset = 0;

    for (final file in archive) {
      if (!file.isFile) continue;

      final lowerName = file.name
          .split('/')
          .last
          .split('\\')
          .last
          .toLowerCase();

      if (lowerName == 'saved_posts.csv' || lowerName == 'saved_comments.csv') {
        final contentString = utf8.decode(
          file.content as List<int>,
          allowMalformed: true,
        );
        final result = parseCsvContent(
          contentString,
          sourceName: lowerName,
          startOrderIndex: orderOffset,
        );
        results.add(result);
        orderOffset += result.items.length;
      }
    }

    return results;
  }

  Future<List<CsvParseResult>> parseFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final filename = file.path.split(Platform.pathSeparator).last.toLowerCase();

    if (filename.endsWith('.zip')) {
      return parseZipArchive(bytes);
    } else {
      final content = utf8.decode(bytes, allowMalformed: true);
      return [parseCsvContent(content, sourceName: filename)];
    }
  }
}
