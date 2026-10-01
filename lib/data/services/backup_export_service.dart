import 'dart:convert';

import 'package:savedex/core/utils/csv_helper.dart';
import 'package:savedex/data/models/saved_item_model.dart';

class BackupExportService {
  // exports saved items in json // no jdaughter :(
  String exportToJson(List<SavedItem> items) {
    final list = items.map((item) {
      return {
        'id': item.id,
        'permalink': item.permalink,
        'itemType': item.itemType.name,
        'parentPostId': item.parentPostId,
        'parentPostTitle': item.parentPostTitle,
        'title': item.title,
        'subreddit': item.subreddit,
        'author': item.author,
        'body': item.body,
        'url': item.url,
        'thumbnailUrl': item.thumbnailUrl,
        'mediaUrl': item.mediaUrl,
        'mediaType': item.mediaType.name,
        'score': item.score,
        'numComments': item.numComments,
        'isNsfw': item.isNsfw,
        'isStarred': item.isStarred,
        'isArchived': item.isArchived,
        'userNote': item.userNote,
        'csvSource': item.csvSource,
        'importOrder': item.importOrder,
        'createdAtUtc': item.createdAtUtc?.toIso8601String(),
        'savedAtUtc': item.savedAtUtc.toIso8601String(),
        'enrichmentStatus': item.enrichmentStatus.name,
        'tags': item.tags
            .map(
              (t) => {'id': t.id, 'name': t.name, 'colorValue': t.colorValue},
            )
            .toList(),
      };
    }).toList();

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'itemCount': items.length,
      'items': list,
    });
  }

  // exports saved items to csv
  String exportToCsv(List<SavedItem> items) {
    final List<List<dynamic>> rows = [
      [
        'id',
        'permalink',
        'item_type',
        'title',
        'subreddit',
        'author',
        'score',
        'is_starred',
        'tags',
        'user_note',
        'saved_at',
        'created_at',
        'media_url',
      ],
    ];

    for (final item in items) {
      rows.add([
        item.id,
        item.permalink,
        item.itemType.name,
        item.title,
        item.subreddit,
        item.author ?? '',
        item.score,
        item.isStarred ? 'true' : 'false',
        item.tags.map((t) => t.name).join(';'),
        item.userNote ?? '',
        item.savedAtUtc.toIso8601String(),
        item.createdAtUtc?.toIso8601String() ?? '',
        item.mediaUrl ?? item.url ?? '',
      ]);
    }

    return CsvHelper.encodeCsv(rows);
  }
}
