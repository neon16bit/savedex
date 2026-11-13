import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/csv_helper.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/saved_item_model.dart';

enum BackupFileType { savedex, json, savedexCsv, redditCsv, redditZip, unknown }

class SavedexCollectionBackup {
  final String name;
  final String? description;
  final int colorValue;

  const SavedexCollectionBackup({
    required this.name,
    this.description,
    required this.colorValue,
  });
}

class SavedexBackupPayload {
  final int version;
  final DateTime? exportedAt;
  final List<SavedItemsTableCompanion> items;
  final Map<String, List<SavedexCollectionBackup>> itemCollections;
  final List<SubredditsTableCompanion> subreddits;

  const SavedexBackupPayload({
    required this.version,
    this.exportedAt,
    required this.items,
    required this.itemCollections,
    this.subreddits = const [],
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
    if (lower.endsWith('.json')) {
      final text =
          content ??
          (bytes != null
              ? utf8.decode(bytes.take(500).toList(), allowMalformed: true)
              : null);
      if (text != null && !isSavedexJson(text)) {
        return BackupFileType.unknown;
      }
      return BackupFileType.json;
    }
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
      if (preview.startsWith('{') && isSavedexJson(preview)) {
        return BackupFileType.json;
      }
      if (isSavedexBackupCsv(preview)) {
        return BackupFileType.savedexCsv;
      }
    }

    return BackupFileType.unknown;
  }

  // check if json is a savedex backup without full decoding
  static bool isSavedexJson(String content) {
    if (content.trim().isEmpty) return false;
    final preview = content.length > 500 ? content.substring(0, 500) : content;
    final clean = preview.trimLeft();
    return clean.startsWith('{') &&
        (clean.contains('"app": "savedex"') ||
            clean.contains('"app":"savedex"'));
  }

  // check csv type, backup/reddit export
  static bool isSavedexBackupCsv(String content) {
    if (content.trim().isEmpty) return false;
    final firstLine = content.split('\n').first.toLowerCase();
    return firstLine.contains('user_note') ||
        firstLine.contains('is_starred') ||
        (firstLine.contains('collections') && firstLine.contains('permalink'));
  }

  // create compressed .savedex backup
  Uint8List createBackup(
    List<SavedItem> items, {
    List<SubredditEntry>? subreddits,
  }) {
    final payload = _buildJsonPayload(items, subreddits: subreddits);
    final utf8Bytes = json.fuse(utf8).encode(payload);
    final compressedBytes = gzip.encode(utf8Bytes);
    return compressedBytes is Uint8List
        ? compressedBytes
        : Uint8List.fromList(compressedBytes);
  }

  // exports saved items in json // still no jdaughter :(
  String exportToJson(
    List<SavedItem> items, {
    List<SubredditEntry>? subreddits,
  }) {
    return _buildJsonString(items, subreddits: subreddits, pretty: true);
  }

  Uint8List exportToJsonBytes(
    List<SavedItem> items, {
    List<SubredditEntry>? subreddits,
    bool pretty = true,
  }) {
    final payload = _buildJsonPayload(items, subreddits: subreddits);
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(payload);
      return utf8.encode(jsonString);
    } else {
      final bytes = json.fuse(utf8).encode(payload);
      return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    }
  }

  Uint8List exportToCsvBytes(List<SavedItem> items) {
    final csvString = exportToCsv(items);
    return utf8.encode(csvString);
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
        'body',
        'url',
        'thumbnail_url',
        'media_url',
        'gallery_images',
        'gallery_preview_images',
        'media_type',
        'score',
        'num_comments',
        'is_nsfw',
        'is_starred',
        'is_archived',
        'user_note',
        'collections',
        'collection_colors',
        'post_flair',
        'parent_post_id',
        'parent_post_title',
        'subreddit_type',
        'enrichment_status',
        'saved_at',
        'created_at',
        'is_archive_recovered',
        'is_archive_unavailable',
        'csv_source',
        'import_order',
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
        item.body ?? '',
        item.url ?? '',
        item.thumbnailUrl ?? '',
        item.mediaUrl ?? '',
        item.galleryImages.isEmpty ? '' : jsonEncode(item.galleryImages),
        item.galleryPreviewImages.isEmpty
            ? ''
            : jsonEncode(item.galleryPreviewImages),
        item.mediaType.name,
        item.score,
        item.numComments,
        item.isNsfw ? 'true' : 'false',
        item.isStarred ? 'true' : 'false',
        item.isArchived ? 'true' : 'false',
        item.userNote ?? '',
        item.collections.map((c) => c.name).join(';'),
        item.collections.map((c) => c.colorValue.toString()).join(';'),
        item.postFlair ?? '',
        item.parentPostId ?? '',
        item.parentPostTitle ?? '',
        item.subredditType,
        item.enrichmentStatus.name,
        item.savedAtUtc.toIso8601String(),
        item.createdAtUtc?.toIso8601String() ?? '',
        item.isArchiveRecovered ? 'true' : 'false',
        item.isArchiveUnavailable ? 'true' : 'false',
        item.csvSource,
        item.importOrder,
      ]);
    }

    return CsvHelper.encodeCsv(rows);
  }

  static List<int> _stripBom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  SavedexBackupPayload parseBackup(List<int> bytes) {
    final dynamic decoded;
    try {
      // check for gzip header bytes: 0x1f, 0x8b
      if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        final decompressed = _stripBom(gzip.decode(bytes));
        decoded = json.fuse(utf8).decode(decompressed);
      } else {
        final uncompressed = _stripBom(bytes);
        decoded = json.fuse(utf8).decode(uncompressed);
      }
    } catch (_) {
      throw const FormatException('Invalid Savedex backup format!');
    }

    if (decoded is! Map<String, dynamic> || decoded['app'] != 'savedex') {
      throw const FormatException('Invalid Savedex backup format!');
    }

    final version = (decoded['version'] as num?)?.toInt() ?? 1;
    final exportedAtStr = decoded['exportedAt'] as String?;
    final exportedAt = exportedAtStr != null
        ? DateTime.tryParse(exportedAtStr)
        : null;
    final rawItems = decoded['items'] as List<dynamic>? ?? [];

    final List<SavedItemsTableCompanion> companions = [];
    final Map<String, List<SavedexCollectionBackup>> itemCollections = {};

    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue;
      final companion = _itemFromJson(raw);
      companions.add(companion);

      final itemId = companion.id.value;
      final rawCollections = raw['collections'] as List<dynamic>? ?? [];
      final collections = <SavedexCollectionBackup>[];
      for (final c in rawCollections) {
        if (c is Map) {
          final name = (c['name'] as String?)?.trim() ?? '';
          final description = (c['description'] as String?)?.trim();
          final colorValue = (c['colorValue'] as num?)?.toInt() ?? 0xFFFF4500;
          if (name.isNotEmpty) {
            collections.add(
              SavedexCollectionBackup(
                name: name,
                description: description,
                colorValue: colorValue,
              ),
            );
          }
        }
      }
      if (collections.isNotEmpty) {
        itemCollections[itemId] = collections;
      }
    }

    final rawSubreddits = decoded['subreddits'] as List<dynamic>? ?? [];
    final List<SubredditsTableCompanion> subreddits = [];
    for (final raw in rawSubreddits) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String?)?.trim().toLowerCase();
      if (name == null || name.isEmpty) continue;
      final isNsfw = raw['isNsfw'] as bool?;
      final iconUrl = raw['iconUrl'] as String?;
      final lastCheckedStr = raw['lastChecked'] as String?;
      final lastChecked = lastCheckedStr != null
          ? DateTime.tryParse(lastCheckedStr)
          : null;
      subreddits.add(
        SubredditsTableCompanion(
          name: Value(name),
          isNsfw: Value(isNsfw),
          iconUrl: Value(iconUrl),
          lastChecked: Value(lastChecked),
        ),
      );
    }

    return SavedexBackupPayload(
      version: version,
      exportedAt: exportedAt,
      items: companions,
      itemCollections: itemCollections,
      subreddits: subreddits,
    );
  }

  // parses savedex exported csv backup
  SavedexBackupPayload parseSavedexCsv(String csvContent) {
    final rows = CsvHelper.parseCsv(csvContent);
    if (rows.isEmpty) {
      return const SavedexBackupPayload(
        version: 1,
        items: [],
        itemCollections: {},
      );
    }

    final headerRow = rows.first.map((e) => e.trim().toLowerCase()).toList();
    final idIndex = headerRow.indexOf('id');
    final permalinkIndex = headerRow.indexOf('permalink');
    final itemTypeIndex = headerRow.indexOf('item_type');
    final titleIndex = headerRow.indexOf('title');
    final subredditIndex = headerRow.indexOf('subreddit');
    final authorIndex = headerRow.indexOf('author');
    final bodyIndex = headerRow.indexOf('body');
    final urlIndex = headerRow.indexOf('url');
    final thumbnailUrlIndex = headerRow.indexOf('thumbnail_url');
    final mediaUrlIndex = headerRow.indexOf('media_url');
    final galleryImagesIndex = headerRow.indexOf('gallery_images');
    final galleryPreviewImagesIndex = headerRow.indexOf(
      'gallery_preview_images',
    );
    final mediaTypeIndex = headerRow.indexOf('media_type');
    final scoreIndex = headerRow.indexOf('score');
    final numCommentsIndex = headerRow.indexOf('num_comments');
    final isNsfwIndex = headerRow.indexOf('is_nsfw');
    final isStarredIndex = headerRow.indexOf('is_starred');
    final isArchivedIndex = headerRow.indexOf('is_archived');
    final userNoteIndex = headerRow.indexOf('user_note');
    final collectionsIndex = headerRow.indexOf('collections');
    final collectionColorsIndex = headerRow.indexOf('collection_colors');
    final postFlairIndex = headerRow.indexOf('post_flair');
    final parentPostIdIndex = headerRow.indexOf('parent_post_id');
    final parentPostTitleIndex = headerRow.indexOf('parent_post_title');
    final subredditTypeIndex = headerRow.indexOf('subreddit_type');
    final enrichmentStatusIndex = headerRow.indexOf('enrichment_status');
    final savedAtIndex = headerRow.indexOf('saved_at');
    final createdAtIndex = headerRow.indexOf('created_at');
    final isArchiveRecoveredIndex = headerRow.indexOf('is_archive_recovered');
    final isArchiveUnavailableIndex = headerRow.indexOf(
      'is_archive_unavailable',
    );
    final csvSourceIndex = headerRow.indexOf('csv_source');
    final importOrderIndex = headerRow.indexOf('import_order');

    final List<SavedItemsTableCompanion> companions = [];
    final Map<String, List<SavedexCollectionBackup>> itemCollections = {};

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
      final body = bodyIndex != -1 && bodyIndex < row.length
          ? row[bodyIndex].trim()
          : null;
      final url = urlIndex != -1 && urlIndex < row.length
          ? row[urlIndex].trim()
          : null;
      final thumbnailUrl =
          thumbnailUrlIndex != -1 && thumbnailUrlIndex < row.length
          ? row[thumbnailUrlIndex].trim()
          : null;
      final mediaUrl = mediaUrlIndex != -1 && mediaUrlIndex < row.length
          ? row[mediaUrlIndex].trim()
          : null;
      final galleryImages =
          galleryImagesIndex != -1 && galleryImagesIndex < row.length
          ? row[galleryImagesIndex].trim()
          : null;
      final galleryPreviewImages =
          galleryPreviewImagesIndex != -1 &&
              galleryPreviewImagesIndex < row.length
          ? row[galleryPreviewImagesIndex].trim()
          : null;

      final mediaTypeStr = mediaTypeIndex != -1 && mediaTypeIndex < row.length
          ? row[mediaTypeIndex].trim().toLowerCase()
          : '';
      final mediaType = MediaType.values.firstWhere(
        (m) => m.name.toLowerCase() == mediaTypeStr,
        orElse: () => itemType == ItemType.comment
            ? MediaType.comment
            : (mediaUrl != null && mediaUrl.isNotEmpty
                  ? MediaType.link
                  : MediaType.text),
      );

      final scoreStr = scoreIndex != -1 && scoreIndex < row.length
          ? row[scoreIndex].trim()
          : '';
      final score = int.tryParse(scoreStr) ?? 0;

      final numCommentsStr =
          numCommentsIndex != -1 && numCommentsIndex < row.length
          ? row[numCommentsIndex].trim()
          : '';
      final numComments = int.tryParse(numCommentsStr) ?? 0;

      final isNsfwStr = isNsfwIndex != -1 && isNsfwIndex < row.length
          ? row[isNsfwIndex].trim().toLowerCase()
          : 'false';
      final isNsfw = isNsfwStr == 'true' || isNsfwStr == '1';

      final isStarredStr = isStarredIndex != -1 && isStarredIndex < row.length
          ? row[isStarredIndex].trim().toLowerCase()
          : 'false';
      final isStarred = isStarredStr == 'true' || isStarredStr == '1';

      final isArchivedStr =
          isArchivedIndex != -1 && isArchivedIndex < row.length
          ? row[isArchivedIndex].trim().toLowerCase()
          : 'false';
      final isArchived = isArchivedStr == 'true' || isArchivedStr == '1';

      final isArchiveRecoveredStr =
          isArchiveRecoveredIndex != -1 && isArchiveRecoveredIndex < row.length
          ? row[isArchiveRecoveredIndex].trim().toLowerCase()
          : 'false';
      final isArchiveRecovered =
          isArchiveRecoveredStr == 'true' || isArchiveRecoveredStr == '1';

      final isArchiveUnavailableStr =
          isArchiveUnavailableIndex != -1 &&
              isArchiveUnavailableIndex < row.length
          ? row[isArchiveUnavailableIndex].trim().toLowerCase()
          : 'false';
      final isArchiveUnavailable =
          isArchiveUnavailableStr == 'true' || isArchiveUnavailableStr == '1';

      final userNote = userNoteIndex != -1 && userNoteIndex < row.length
          ? row[userNoteIndex].trim()
          : null;

      final postFlair = postFlairIndex != -1 && postFlairIndex < row.length
          ? row[postFlairIndex].trim()
          : null;
      final parentPostId =
          parentPostIdIndex != -1 && parentPostIdIndex < row.length
          ? row[parentPostIdIndex].trim()
          : null;
      final parentPostTitle =
          parentPostTitleIndex != -1 && parentPostTitleIndex < row.length
          ? row[parentPostTitleIndex].trim()
          : null;
      final subredditType =
          subredditTypeIndex != -1 && subredditTypeIndex < row.length
          ? row[subredditTypeIndex].trim()
          : 'public';

      final enrichmentStatusStr =
          enrichmentStatusIndex != -1 && enrichmentStatusIndex < row.length
          ? row[enrichmentStatusIndex].trim().toLowerCase()
          : '';
      final enrichmentStatus = EnrichmentStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == enrichmentStatusStr,
        orElse: () => EnrichmentStatus.enriched,
      );

      final savedAtStr = savedAtIndex != -1 && savedAtIndex < row.length
          ? row[savedAtIndex].trim()
          : '';
      final savedAtUtc =
          DateTime.tryParse(savedAtStr)?.toUtc() ?? DateTime.now().toUtc();
      final createdAtStr = createdAtIndex != -1 && createdAtIndex < row.length
          ? row[createdAtIndex].trim()
          : '';
      final createdAtUtc = DateTime.tryParse(createdAtStr)?.toUtc();

      final csvSourceStr = csvSourceIndex != -1 && csvSourceIndex < row.length
          ? row[csvSourceIndex].trim()
          : '';
      final importOrderStr =
          importOrderIndex != -1 && importOrderIndex < row.length
          ? row[importOrderIndex].trim()
          : '';
      final parsedImportOrder =
          int.tryParse(importOrderStr) ?? (rows.length - i);

      companions.add(
        SavedItemsTableCompanion(
          id: Value(id),
          permalink: Value(permalink),
          itemType: Value(itemType),
          parentPostId: Value(
            parentPostId != null && parentPostId.isNotEmpty
                ? parentPostId
                : null,
          ),
          parentPostTitle: Value(
            parentPostTitle != null && parentPostTitle.isNotEmpty
                ? parentPostTitle
                : null,
          ),
          title: Value(title.isNotEmpty ? title : 'Untitled Post'),
          subreddit: Value(SavedItem.normalizeSubredditForStorage(subreddit)),
          author: Value(SavedItem.normalizeAuthorForStorage(author)),
          body: Value(body != null && body.isNotEmpty ? body : null),
          url: Value(url != null && url.isNotEmpty ? url : null),
          thumbnailUrl: Value(
            thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? thumbnailUrl
                : null,
          ),
          mediaUrl: Value(
            mediaUrl != null && mediaUrl.isNotEmpty ? mediaUrl : null,
          ),
          galleryImages: Value(
            galleryImages != null && galleryImages.isNotEmpty
                ? _galleryJsonFromValue(galleryImages)
                : null,
          ),
          galleryPreviewImages: Value(
            galleryPreviewImages != null && galleryPreviewImages.isNotEmpty
                ? _galleryJsonFromValue(galleryPreviewImages)
                : null,
          ),
          mediaType: Value(mediaType),
          score: Value(score),
          numComments: Value(numComments),
          isNsfw: Value(isNsfw),
          isStarred: Value(isStarred),
          isArchived: Value(isArchived),
          isArchiveRecovered: Value(isArchiveRecovered),
          isArchiveUnavailable: Value(isArchiveUnavailable),
          userNote: Value(
            userNote != null && userNote.isNotEmpty ? userNote : null,
          ),
          csvSource: Value(
            csvSourceStr.isNotEmpty ? csvSourceStr : 'savedex_backup.csv',
          ),
          importOrder: Value(parsedImportOrder),
          savedAtUtc: Value(savedAtUtc),
          createdAtUtc: Value(createdAtUtc),
          postFlair: Value(
            postFlair != null && postFlair.isNotEmpty ? postFlair : null,
          ),
          subredditType: Value(
            subredditType.isNotEmpty ? subredditType : 'public',
          ),
          enrichmentStatus: Value(enrichmentStatus),
        ),
      );

      if (collectionsIndex != -1 && collectionsIndex < row.length) {
        final rawCollectionsStr = row[collectionsIndex].trim();
        if (rawCollectionsStr.isNotEmpty) {
          final collectionNames = rawCollectionsStr
              .split(';')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          final rawColorsStr =
              collectionColorsIndex != -1 && collectionColorsIndex < row.length
              ? row[collectionColorsIndex].trim()
              : '';
          final colorValues = rawColorsStr.isNotEmpty
              ? rawColorsStr
                    .split(';')
                    .map((s) => int.tryParse(s.trim()) ?? 0xFFFF4500)
                    .toList()
              : <int>[];

          final collectionsList = <SavedexCollectionBackup>[];
          for (int t = 0; t < collectionNames.length; t++) {
            final color = t < colorValues.length ? colorValues[t] : 0xFFFF4500;
            collectionsList.add(
              SavedexCollectionBackup(
                name: collectionNames[t],
                colorValue: color,
              ),
            );
          }
          itemCollections[id] = collectionsList;
        }
      }
    }

    return SavedexBackupPayload(
      version: 1,
      items: companions,
      itemCollections: itemCollections,
    );
  }

  Map<String, dynamic> _buildJsonPayload(
    List<SavedItem> items, {
    List<SubredditEntry>? subreddits,
  }) {
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
        'galleryImages': item.galleryImages,
        'galleryPreviewImages': item.galleryPreviewImages,
        'mediaType': item.mediaType.name,
        'score': item.score,
        'numComments': item.numComments,
        'isNsfw': item.isNsfw,
        'isStarred': item.isStarred,
        'isArchived': item.isArchived,
        'isArchiveRecovered': item.isArchiveRecovered,
        'isArchiveUnavailable': item.isArchiveUnavailable,
        'userNote': item.userNote,
        'csvSource': item.csvSource,
        'importOrder': item.importOrder,
        'createdAtUtc': item.createdAtUtc?.toIso8601String(),
        'savedAtUtc': item.savedAtUtc.toIso8601String(),
        'postFlair': item.postFlair,
        'subredditType': item.subredditType,
        'enrichmentStatus': item.enrichmentStatus.name,
        'collections': item.collections
            .map(
              (c) => {
                'id': c.id,
                'name': c.name,
                'description': c.description,
                'colorValue': c.colorValue,
              },
            )
            .toList(),
      };
    }).toList();

    final payload = <String, dynamic>{
      'app': 'savedex',
      'version': 1,
      'type': 'backup',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'itemCount': items.length,
      'items': list,
    };

    if (subreddits != null && subreddits.isNotEmpty) {
      payload['subreddits'] = subreddits
          .map(
            (s) => {
              'name': s.name,
              'isNsfw': s.isNsfw,
              'iconUrl': s.iconUrl,
              'lastChecked': s.lastChecked?.toUtc().toIso8601String(),
            },
          )
          .toList();
    }

    return payload;
  }

  String _buildJsonString(
    List<SavedItem> items, {
    List<SubredditEntry>? subreddits,
    required bool pretty,
  }) {
    final payload = _buildJsonPayload(items, subreddits: subreddits);
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(payload);
    } else {
      return jsonEncode(payload);
    }
  }

  String? _galleryJsonFromValue(dynamic value) {
    if (value is List) {
      final urls = value.whereType<String>().toList();
      return urls.isEmpty ? null : jsonEncode(urls);
    }
    if (value is! String || value.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        final urls = decoded.whereType<String>().toList();
        return urls.isEmpty ? null : jsonEncode(urls);
      }
    } on FormatException {
      return null;
    }
    return null;
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
      subreddit: Value(
        SavedItem.normalizeSubredditForStorage(map['subreddit'] as String?),
      ),
      author: Value(
        SavedItem.normalizeAuthorForStorage(map['author'] as String?),
      ),
      body: Value(map['body'] as String?),
      url: Value(map['url'] as String?),
      thumbnailUrl: Value(map['thumbnailUrl'] as String?),
      mediaUrl: Value(map['mediaUrl'] as String?),
      galleryImages: Value(_galleryJsonFromValue(map['galleryImages'])),
      galleryPreviewImages: Value(
        _galleryJsonFromValue(map['galleryPreviewImages']),
      ),
      mediaType: Value(mediaType),
      score: Value((map['score'] as num?)?.toInt() ?? 0),
      numComments: Value((map['numComments'] as num?)?.toInt() ?? 0),
      isNsfw: Value((map['isNsfw'] as bool?) ?? false),
      isStarred: Value((map['isStarred'] as bool?) ?? false),
      isArchived: Value((map['isArchived'] as bool?) ?? false),
      isArchiveRecovered: Value((map['isArchiveRecovered'] as bool?) ?? false),
      isArchiveUnavailable: Value(
        (map['isArchiveUnavailable'] as bool?) ?? false,
      ),
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
