import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/services/backup_export_service.dart';

void main() {
  group('BackupExportService', () {
    late BackupExportService service;
    late List<SavedItem> sampleItems;

    setUp(() {
      service = BackupExportService();
      sampleItems = [
        SavedItem(
          id: 'post_frieren_mimic',
          permalink: '/r/Frieren/comments/mimic_trap/it_might_be_a_real_grimoire_this_time/',
          itemType: ItemType.post,
          title: 'It might be a real grimoire this time (99% chance of mimic)',
          subreddit: 'Frieren',
          author: 'elven_mage_frieren',
          body:
              'Dark! It is so dark and terrifying! Fern, help me out of here!',
          url: 'https://reddit.com/r/Frieren/comments/mimic_trap/',
          thumbnailUrl: 'https://grimoires.org/mimic_preview.png',
          mediaUrl: 'https://grimoires.org/frieren_stuck_in_mimic.mp4',
          mediaType: MediaType.video,
          score: 1000,
          numComments: 80,
          isNsfw: false,
          isStarred: true,
          isArchived: false,
          userNote: 'Grimoire that sees through clothes found on floor 48',
          csvSource: 'reddit_api',
          importOrder: 1,
          createdAtUtc: DateTime.utc(2026, 1, 15, 10, 30),
          savedAtUtc: DateTime.utc(2026, 2, 1, 12, 00),
          postFlair: 'Grimoire Hunting',
          subredditType: 'public',
          enrichmentStatus: EnrichmentStatus.enriched,
          collections: const [
            Collection(id: 1, name: 'Frieren', colorValue: 0xFF87CEEB),
            Collection(id: 2, name: 'Mimic', colorValue: 0xFFFF4500),
          ],
        ),
        SavedItem(
          id: 'comment_luffy_reddit_app',
          permalink:
              '/r/OnePiece/comments/official_app/comment_so_good_i_could_die/',
          itemType: ItemType.comment,
          parentPostId: 't3_official_reddit_app',
          parentPostTitle: 'State of the Official Reddit App',
          title: 'The official Reddit app is so bad I could die!',
          subreddit: 'OnePiece',
          author: 'monkey_d_luffy',
          body: 'This official Reddit app is so bad I could die! Even poison armored giant fish skin tasted better than this video player! Sanji, bring me third-party apps!',
          score: 5656,
          numComments: 0,
          isNsfw: false,
          isStarred: false,
          isArchived: true,
          userNote: null,
          csvSource: 'reddit_api',
          importOrder: 0,
          createdAtUtc: DateTime.utc(2026, 2, 10, 8, 15),
          savedAtUtc: DateTime.utc(2026, 2, 11, 9, 30),
          subredditType: 'public',
          enrichmentStatus: EnrichmentStatus.enriched,
          collections: const [
            Collection(id: 3, name: 'StrawHat', colorValue: 0xFFDC143C),
          ],
        ),
      ];
    });

    test('createBackup produces Gzip-compressed bytes with magic header', () {
      final bytes = service.createBackup(sampleItems);

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(0x1F));
      expect(bytes[1], equals(0x8B));

      final unzipped = utf8.decode(gzip.decode(bytes));
      final json = jsonDecode(unzipped) as Map<String, dynamic>;
      expect(json['app'], equals('savedex'));
      expect(json['version'], equals(1));
      expect(json['type'], equals('backup'));
      expect(json['itemCount'], equals(2));
      expect(json['items'], hasLength(2));
    });

    test('parseBackup successfully parses compressed .savedex bytes', () {
      final compressedBytes = service.createBackup(sampleItems);
      final payload = service.parseBackup(compressedBytes);

      expect(payload.version, equals(1));
      expect(payload.items, hasLength(2));

      final post = payload.items.firstWhere(
        (i) => i.id.value == 'post_frieren_mimic',
      );
      expect(
        post.title.value,
        equals('It might be a real grimoire this time (99% chance of mimic)'),
      );
      expect(post.author.value, equals('elven_mage_frieren'));
      expect(post.score.value, equals(1000));
      expect(post.isStarred.value, isTrue);
      expect(post.isArchived.value, isFalse);
      expect(
        post.userNote.value,
        equals('Grimoire that sees through clothes found on floor 48'),
      );
      expect(post.mediaType.value, equals(MediaType.video));

      final postCollections = payload.itemCollections['post_frieren_mimic'];
      expect(postCollections, isNotNull);
      expect(postCollections, hasLength(2));
      expect(postCollections![0].name, equals('Frieren'));
      expect(postCollections[0].colorValue, equals(0xFF87CEEB));
      expect(postCollections[1].name, equals('Mimic'));

      final comment = payload.items.firstWhere(
        (i) => i.id.value == 'comment_luffy_reddit_app',
      );
      expect(
        comment.title.value,
        equals('The official Reddit app is so bad I could die!'),
      );
      expect(comment.itemType.value, equals(ItemType.comment));
      expect(comment.parentPostId.value, equals('t3_official_reddit_app'));
      expect(comment.isArchived.value, isTrue);
      expect(comment.isStarred.value, isFalse);
    });

    test('exportToJson produces valid JSON and parseBackup can read raw JSON bytes', () {
      final jsonString = service.exportToJson(sampleItems);
      expect(jsonString.contains('"app": "savedex"'), isTrue);
      expect(
        jsonString.contains('It might be a real grimoire this time'),
        isTrue,
      );

      final uncompressedBytes = utf8.encode(jsonString);
      final payload = service.parseBackup(uncompressedBytes);

      expect(payload.version, equals(1));
      expect(payload.items, hasLength(2));
      expect(payload.itemCollections['post_frieren_mimic'], hasLength(2));
    });

    test('exportToCsv produces rich CSV with all columns', () {
      final csvString = service.exportToCsv(sampleItems);
      expect(csvString.contains('id,permalink,item_type'), isTrue);
      expect(csvString.contains('user_note'), isTrue);
      expect(csvString.contains('collections'), isTrue);
      expect(csvString.contains('collection_colors'), isTrue);
      expect(
        csvString.contains(
          'Grimoire that sees through clothes found on floor 48',
        ),
        isTrue,
      );
      expect(csvString.contains('Frieren;Mimic'), isTrue);
    });

    test(
      'isSavedexBackupCsv distinguishes Savedex CSV from Reddit GDPR CSV',
      () {
        final savedexCsv = service.exportToCsv(sampleItems);
        expect(BackupExportService.isSavedexBackupCsv(savedexCsv), isTrue);

        const redditGdprCsv =
            'id,permalink\nt3_abc,/r/test/comments/abc/title/';
        expect(BackupExportService.isSavedexBackupCsv(redditGdprCsv), isFalse);
      },
    );

    test(
      'parseSavedexCsv restores full items, notes, stars, and collections',
      () {
        final csvString = service.exportToCsv(sampleItems);
        final payload = service.parseSavedexCsv(csvString);

        expect(payload.items, hasLength(2));
        final post = payload.items.firstWhere(
          (i) => i.id.value == 'post_frieren_mimic',
        );
        expect(
          post.title.value,
          equals('It might be a real grimoire this time (99% chance of mimic)'),
        );
        expect(
          post.body.value,
          equals(
            'Dark! It is so dark and terrifying! Fern, help me out of here!',
          ),
        );
        expect(post.mediaType.value, equals(MediaType.video));
        expect(
          post.thumbnailUrl.value,
          equals('https://grimoires.org/mimic_preview.png'),
        );
        expect(
          post.mediaUrl.value,
          equals('https://grimoires.org/frieren_stuck_in_mimic.mp4'),
        );
        expect(post.postFlair.value, equals('Grimoire Hunting'));
        expect(post.isStarred.value, isTrue);
        expect(
          post.userNote.value,
          equals('Grimoire that sees through clothes found on floor 48'),
        );
        expect(post.enrichmentStatus.value, equals(EnrichmentStatus.enriched));

        final comment = payload.items.firstWhere(
          (i) => i.id.value == 'comment_luffy_reddit_app',
        );
        expect(comment.parentPostId.value, equals('t3_official_reddit_app'));
        expect(
          comment.parentPostTitle.value,
          equals('State of the Official Reddit App'),
        );
        expect(comment.itemType.value, equals(ItemType.comment));
        expect(comment.isArchived.value, isTrue);

        final collections = payload.itemCollections['post_frieren_mimic'];
        expect(collections, isNotNull);
        expect(
          collections!.map((c) => c.name).toList(),
          containsAll(['Frieren', 'Mimic']),
        );
        expect(
          collections.firstWhere((c) => c.name == 'Frieren').colorValue,
          equals(0xFF87CEEB),
        );
        expect(
          collections.firstWhere((c) => c.name == 'Mimic').colorValue,
          equals(0xFFFF4500),
        );
      },
    );

    test('detectFileType accurately identifies extensions and content', () {
      expect(
        BackupExportService.detectFileType(filename: 'my_backup.savedex'),
        equals(BackupFileType.savedex),
      );
      expect(
        BackupExportService.detectFileType(filename: 'library.json'),
        equals(BackupFileType.json),
      );
      expect(
        BackupExportService.detectFileType(filename: 'reddit_takeout.zip'),
        equals(BackupFileType.redditZip),
      );

      final savedexCsv = service.exportToCsv(sampleItems);
      expect(
        BackupExportService.detectFileType(
          filename: 'export.csv',
          content: savedexCsv,
        ),
        equals(BackupFileType.savedexCsv),
      );

      expect(
        BackupExportService.detectFileType(
          filename: 'saved_posts.csv',
          content: 'id,permalink\nt3_123,/r/test/',
        ),
        equals(BackupFileType.redditCsv),
      );

      final compressedBytes = service.createBackup(sampleItems);
      expect(
        BackupExportService.detectFileType(
          filename: 'unknown_file',
          bytes: compressedBytes,
        ),
        equals(BackupFileType.savedex),
      );
    });

    test('isSavedexJson accurately detects Savedex headers and rejects random JSON', () {
      final validJson = service.exportToJson(sampleItems);
      expect(BackupExportService.isSavedexJson(validJson), isTrue);

      const randomJson = '{"name": "my-project", "version": "1.0.0"}';
      expect(BackupExportService.isSavedexJson(randomJson), isFalse);

      expect(
        BackupExportService.detectFileType(
          filename: 'random.json',
          content: randomJson,
        ),
        equals(BackupFileType.unknown),
      );

      expect(
        () => service.parseBackup(utf8.encode(randomJson)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
