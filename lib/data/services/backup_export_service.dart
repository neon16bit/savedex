import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/csv_helper.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/saved_item_model.dart';

enum BackupFileType { savedex, json, savedexCsv, redditCsv, redditZip, unknown }

class SavedexTagBackup {
  final String name;
  final int colorValue;

  const SavedexTagBackup({required this.name, required this.colorValue});
}

class SavedexBackupPayload {
  final int version;
  final DateTime? exportedAt;
  final List<SavedItemsTableCompanion> items;
  final Map<String, List<SavedexTagBackup>> itemTags;

  const SavedexBackupPayload({
    required this.version,
    this.exportedAt,
    required this.items,
    required this.itemTags,
  });
}

class BackupExportService {
  // check backup file type by file extension/content
  static BackupFileType detectFileType({
    required String filename,
    List<int>? bytes,
    String? content,
  }) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.savedex')) return BackupFileType.savedex;
    if (lower.endsWith('.json')) return BackupFileType.json;
    if (lower.endsWith('.zip')) return BackupFileType.redditZip;
    if (lower.endsWith('.csv')) {
      final text =
          content ??
          (bytes != null ? utf8.decode(bytes, allowMalformed: true) : '');
      if (isSavedexBackupCsv(text)) {
        return BackupFileType.savedexCsv;
      }
      return BackupFileType.redditCsv;
    }

    // peek at content if extension is missing or unknown
    if (bytes != null && bytes.length >= 2) {
      if (bytes[0] == 0x1f && bytes[1] == 0x8b) {
        return BackupFileType.savedex;
      }
      final preview = utf8
          .decode(bytes.take(500).toList(), allowMalformed: true)
          .trimLeft();
      if (preview.startsWith('{') || preview.startsWith('[')) {
        return BackupFileType.json;
      }
      if (isSavedexBackupCsv(preview)) {
        return BackupFileType.savedexCsv;
      }
    }

    return BackupFileType.unknown;
  }

  // check csv type, backup/reddit export
  static bool isSavedexBackupCsv(String content) {
    if (content.trim().isEmpty) return false;
    final firstLine = content.split('\n').first.toLowerCase();
    return firstLine.contains('user_note') ||
        firstLine.contains('is_starred') ||
        (firstLine.contains('tags') && firstLine.contains('permalink'));
  }

  // create compressed .savedex backup
  Uint8List createBackup(List<SavedItem> items) {
    final jsonString = _buildJsonString(items, pretty: false);
    final utf8Bytes = utf8.encode(jsonString);
    final compressedBytes = gzip.encode(utf8Bytes);
    return Uint8List.fromList(compressedBytes);
  }

  // exports saved items in json // still no jdaughter :(
  String exportToJson(List<SavedItem> items) {
    return _buildJsonString(items, pretty: true);
  }

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

  SavedexBackupPayload parseBackup(List<int> bytes) {
    String jsonString;
    // check for gzip header bytes: 0x1f, 0x8b
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      final decompressed = gzip.decode(bytes);
      jsonString = utf8.decode(decompressed);
    } else {
      jsonString = utf8.decode(bytes);
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Savedex backup format');
    }

    final version = (decoded['version'] as num?)?.toInt() ?? 1;
    final exportedAtStr = decoded['exportedAt'] as String?;
    final exportedAt = exportedAtStr != null
        ? DateTime.tryParse(exportedAtStr)
        : null;
    final rawItems = decoded['items'] as List<dynamic>? ?? [];

    final List<SavedItemsTableCompanion> companions = [];
    final Map<String, List<SavedexTagBackup>> itemTags = {};

    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue;
      final companion = _itemFromJson(raw);
      companions.add(companion);

      final itemId = companion.id.value;
      final rawTags = raw['tags'] as List<dynamic>? ?? [];
      final tags = <SavedexTagBackup>[];
      for (final t in rawTags) {
        if (t is Map) {
          final name = (t['name'] as String?)?.trim() ?? '';
          final colorValue = (t['colorValue'] as num?)?.toInt() ?? 0xFFFF4500;
          if (name.isNotEmpty) {
            tags.add(SavedexTagBackup(name: name, colorValue: colorValue));
          }
        }
      }
      if (tags.isNotEmpty) {
        itemTags[itemId] = tags;
      }
    }

    return SavedexBackupPayload(
      version: version,
      exportedAt: exportedAt,
      items: companions,
      itemTags: itemTags,
    );
  }

  // parses savedex exported csv backup
  SavedexBackupPayload parseSavedexCsv(String csvContent) {
    final rows = CsvHelper.parseCsv(csvContent);
    if (rows.isEmpty) {
      return const SavedexBackupPayload(version: 1, items: [], itemTags: {});
    }

    final headerRow = rows.first.map((e) => e.trim().toLowerCase()).toList();
    final idIndex = headerRow.indexOf('id');
    final permalinkIndex = headerRow.indexOf('permalink');
    final itemTypeIndex = headerRow.indexOf('item_type');
    final titleIndex = headerRow.indexOf('title');
    final subredditIndex = headerRow.indexOf('subreddit');
    final authorIndex = headerRow.indexOf('author');
    final scoreIndex = headerRow.indexOf('score');
    final isStarredIndex = headerRow.indexOf('is_starred');
    final tagsIndex = headerRow.indexOf('tags');
    final userNoteIndex = headerRow.indexOf('user_note');
    final savedAtIndex = headerRow.indexOf('saved_at');
    final createdAtIndex = headerRow.indexOf('created_at');
    final mediaUrlIndex = headerRow.indexOf('media_url');

    final List<SavedItemsTableCompanion> companions = [];
    final Map<String, List<SavedexTagBackup>> itemTags = {};
    int orderCounter = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id = idIndex != -1 && idIndex < row.length
          ? row[idIndex].trim()
          : '';
      if (id.isEmpty) continue;

      final permalink = permalinkIndex != -1 && permalinkIndex < row.length
          ? row[permalinkIndex].trim()
          : '';
      final itemTypeStr = itemTypeIndex != -1 && itemTypeIndex < row.length
          ? row[itemTypeIndex].trim().toLowerCase()
          : '';
      final itemType = itemTypeStr == 'comment'
          ? ItemType.comment
          : ItemType.post;

      final title = titleIndex != -1 && titleIndex < row.length
          ? row[titleIndex].trim()
          : '';
      final subreddit = subredditIndex != -1 && subredditIndex < row.length
          ? row[subredditIndex].trim()
          : 'reddit';
      final author = authorIndex != -1 && authorIndex < row.length
          ? row[authorIndex].trim()
          : null;
      final scoreStr = scoreIndex != -1 && scoreIndex < row.length
          ? row[scoreIndex].trim()
          : '';
      final score = int.tryParse(scoreStr) ?? 0;
      final isStarredStr = isStarredIndex != -1 && isStarredIndex < row.length
          ? row[isStarredIndex].trim().toLowerCase()
          : 'false';
      final isStarred = isStarredStr == 'true' || isStarredStr == '1';
      final userNote = userNoteIndex != -1 && userNoteIndex < row.length
          ? row[userNoteIndex].trim()
          : null;
      final savedAtStr = savedAtIndex != -1 && savedAtIndex < row.length
          ? row[savedAtIndex].trim()
          : '';
      final savedAtUtc =
          DateTime.tryParse(savedAtStr)?.toUtc() ?? DateTime.now().toUtc();
      final createdAtStr = createdAtIndex != -1 && createdAtIndex < row.length
          ? row[createdAtIndex].trim()
          : '';
      final createdAtUtc = DateTime.tryParse(createdAtStr)?.toUtc();
      final mediaUrl = mediaUrlIndex != -1 && mediaUrlIndex < row.length
          ? row[mediaUrlIndex].trim()
          : null;

      final mediaType = itemType == ItemType.comment
          ? MediaType.comment
          : (mediaUrl != null && mediaUrl.isNotEmpty
                ? MediaType.link
                : MediaType.text);

      companions.add(
        SavedItemsTableCompanion(
          id: Value(id),
          permalink: Value(permalink),
          itemType: Value(itemType),
          title: Value(title.isNotEmpty ? title : 'Untitled Post'),
          subreddit: Value(subreddit.isNotEmpty ? subreddit : 'reddit'),
          author: Value(author != null && author.isNotEmpty ? author : null),
          mediaUrl: Value(
            mediaUrl != null && mediaUrl.isNotEmpty ? mediaUrl : null,
          ),
          mediaType: Value(mediaType),
          score: Value(score),
          isStarred: Value(isStarred),
          userNote: Value(
            userNote != null && userNote.isNotEmpty ? userNote : null,
          ),
          csvSource: const Value('savedex_backup.csv'),
          importOrder: Value(orderCounter++),
          savedAtUtc: Value(savedAtUtc),
          createdAtUtc: Value(createdAtUtc),
          enrichmentStatus: const Value(EnrichmentStatus.enriched),
        ),
      );

      if (tagsIndex != -1 && tagsIndex < row.length) {
        final rawTagsStr = row[tagsIndex].trim();
        if (rawTagsStr.isNotEmpty) {
          final tagNames = rawTagsStr
              .split(';')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          itemTags[id] = tagNames
              .map(
                (name) => SavedexTagBackup(name: name, colorValue: 0xFFFF4500),
              )
              .toList();
        }
      }
    }

    return SavedexBackupPayload(
      version: 1,
      items: companions,
      itemTags: itemTags,
    );
  }

  String _buildJsonString(List<SavedItem> items, {required bool pretty}) {
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
        'postFlair': item.postFlair,
        'subredditType': item.subredditType,
        'enrichmentStatus': item.enrichmentStatus.name,
        'tags': item.tags
            .map(
              (t) => {'id': t.id, 'name': t.name, 'colorValue': t.colorValue},
            )
            .toList(),
      };
    }).toList();

    final payload = {
      'app': 'savedex',
      'version': 1,
      'type': 'backup',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'itemCount': items.length,
      'items': list,
    };

    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(payload);
    } else {
      return jsonEncode(payload);
    }
  }

  SavedItemsTableCompanion _itemFromJson(Map<String, dynamic> map) {
    final itemTypeStr = map['itemType'] as String?;
    final itemType = itemTypeStr == 'comment'
        ? ItemType.comment
        : ItemType.post;

    final mediaTypeStr = map['mediaType'] as String?;
    final mediaType = MediaType.values.firstWhere(
      (m) => m.name == mediaTypeStr,
      orElse: () =>
          itemType == ItemType.comment ? MediaType.comment : MediaType.text,
    );

    final statusStr = map['enrichmentStatus'] as String?;
    final status = EnrichmentStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => EnrichmentStatus.enriched,
    );

    final savedAtUtc = map['savedAtUtc'] != null
        ? DateTime.tryParse(map['savedAtUtc'] as String)?.toUtc() ??
              DateTime.now().toUtc()
        : DateTime.now().toUtc();
    final createdAtUtc = map['createdAtUtc'] != null
        ? DateTime.tryParse(map['createdAtUtc'] as String)?.toUtc()
        : null;

    return SavedItemsTableCompanion(
      id: Value(map['id'] as String),
      permalink: Value((map['permalink'] as String?) ?? ''),
      itemType: Value(itemType),
      parentPostId: Value(map['parentPostId'] as String?),
      parentPostTitle: Value(map['parentPostTitle'] as String?),
      title: Value((map['title'] as String?) ?? 'Untitled Post'),
      subreddit: Value((map['subreddit'] as String?) ?? 'reddit'),
      author: Value(map['author'] as String?),
      body: Value(map['body'] as String?),
      url: Value(map['url'] as String?),
      thumbnailUrl: Value(map['thumbnailUrl'] as String?),
      mediaUrl: Value(map['mediaUrl'] as String?),
      mediaType: Value(mediaType),
      score: Value((map['score'] as num?)?.toInt() ?? 0),
      numComments: Value((map['numComments'] as num?)?.toInt() ?? 0),
      isNsfw: Value((map['isNsfw'] as bool?) ?? false),
      isStarred: Value((map['isStarred'] as bool?) ?? false),
      isArchived: Value((map['isArchived'] as bool?) ?? false),
      userNote: Value(map['userNote'] as String?),
      csvSource: Value((map['csvSource'] as String?) ?? 'backup'),
      importOrder: Value((map['importOrder'] as num?)?.toInt() ?? 0),
      createdAtUtc: Value(createdAtUtc),
      savedAtUtc: Value(savedAtUtc),
      postFlair: Value(map['postFlair'] as String?),
      subredditType: Value((map['subredditType'] as String?) ?? 'public'),
      enrichmentStatus: Value(status),
    );
  }
}
