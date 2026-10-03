import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/repositories/saved_item_repository.dart';
import 'package:savedex/data/services/backup_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BackupExportService backupService;
  late SavedItemRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupExportService();
    repository = SavedItemRepository(db: db, backupExport: backupService);
  });

  tearDown(() async {
    await db.close();
  });

  group('SavedItemRepository - Database Restoration Engine', () {
    test(
      'restores full .savedex (compressed gzip) backup into empty database',
      () async {
        final sampleItem = SavedItem(
          id: 'post_pistachio_gelato',
          permalink:
              '/r/icecream/comments/gelato_recipe/homemade_pistachio_gelato/',
          itemType: ItemType.post,
          title: 'Homemade roasted pistachio gelato with custard base',
          subreddit: 'icecream',
          author: 'cone_connoisseur_99',
          body: 'Double churned with Sicilian pistachios and sea salt. Texture came out super silky.',
          url: 'https://reddit.com/r/icecream/comments/gelato_recipe/',
          thumbnailUrl: 'https://icecream.org/pistachio_thumb.png',
          mediaUrl: 'https://icecream.org/pistachio_churn.mp4',
          mediaType: MediaType.video,
          score: 4200,
          numComments: 120,
          isNsfw: false,
          isStarred: true,
          isArchived: false,
          userNote:
              'Chill the custard base for at least 12 hours before churning',
          csvSource: 'savedex_backup',
          importOrder: 1,
          createdAtUtc: DateTime.utc(2026, 1, 15, 10, 30),
          savedAtUtc: DateTime.utc(2026, 2, 1, 12, 00),
          postFlair: 'Recipe / Homemade',
          subredditType: 'public',
          enrichmentStatus: EnrichmentStatus.enriched,
          tags: const [
            Tag(id: 1, name: 'Ice Cream', colorValue: 0xFF98FB98),
            Tag(id: 2, name: 'Desserts', colorValue: 0xFFFFB6C1),
          ],
        );

        final backupBytes = backupService.createBackup([sampleItem]);

        final summary = await repository.restoreFromBackup(
          backupBytes,
          sourceName: 'icecream_favorites.savedex',
        );

        expect(summary.totalFound, 1);
        expect(summary.newItemsImported, 1);
        expect(summary.updatedItems, 0);
        expect(summary.skippedItems, 0);
        expect(summary.totalInDatabase, 1);

        final restored = await repository.getItemById('post_pistachio_gelato');
        expect(restored, isNotNull);
        expect(
          restored!.title,
          'Homemade roasted pistachio gelato with custard base',
        );
        expect(restored.author, 'cone_connoisseur_99');
        expect(restored.isStarred, isTrue);
        expect(
          restored.userNote,
          'Chill the custard base for at least 12 hours before churning',
        );
        expect(restored.tags.length, 2);
        final tagNames = restored.tags.map((t) => t.name).toSet();
        expect(tagNames, containsAll(['Ice Cream', 'Desserts']));
      },
    );

    test('restores uncompressed JSON backup', () async {
      final sampleItem = SavedItem(
        id: 'post_dev_guide',
        permalink: '/r/programming/comments/123/architecture_guide/',
        itemType: ItemType.post,
        title: 'Clean Architecture and State Management Guide',
        subreddit: 'programming',
        author: 'code_architect',
        body: 'Comprehensive breakdown of repository patterns and offline caching.',
        score: 1250,
        numComments: 45,
        isStarred: true,
        userNote: 'Architecture reference for offline sync',
        importOrder: 1,
        savedAtUtc: DateTime.utc(2026, 3, 10),
        tags: const [Tag(id: 1, name: 'Programming', colorValue: 0xFF1E90FF)],
      );

      final jsonString = backupService.exportToJson([sampleItem]);
      final jsonBytes = utf8.encode(jsonString);

      final summary = await repository.restoreFromBackup(
        jsonBytes,
        sourceName: 'library_backup.json',
      );

      expect(summary.totalFound, 1);
      expect(summary.newItemsImported, 1);
      expect(summary.totalInDatabase, 1);

      final restored = await repository.getItemById('post_dev_guide');
      expect(restored, isNotNull);
      expect(restored!.title, 'Clean Architecture and State Management Guide');
      expect(restored.isStarred, isTrue);
      expect(restored.tags.first.name, 'Programming');
    });

    test('restores rich Savedex CSV backup with tags and notes', () async {
      final items = [
        SavedItem(
          id: 'comment_spaceballs_coffee',
          permalink: '/r/recipes/comments/french_press/morning_coffee_setup/',
          itemType: ItemType.comment,
          title: 'Finally dialed in my French press ratio',
          subreddit: 'recipes',
          author: 'spaceballs420',
          body: 'This is some serious gourmet shit!',
          score: 420,
          isStarred: true,
          userNote:
              '1:15 ratio with medium coarse grind, steep exactly 4 minutes.',
          importOrder: 1,
          savedAtUtc: DateTime.utc(2026, 4, 1),
          tags: const [
            Tag(id: 1, name: 'Gourmet Recipes', colorValue: 0xFF8B4513),
          ],
        ),
      ];

      final csvContent = backupService.exportToCsv(items);
      final csvBytes = utf8.encode(csvContent);

      final summary = await repository.restoreFromBackup(
        csvBytes,
        sourceName: 'gourmet_recipes.csv',
      );

      expect(summary.totalFound, 1);
      expect(summary.newItemsImported, 1);

      final restored = await repository.getItemById(
        'comment_spaceballs_coffee',
      );
      expect(restored, isNotNull);
      expect(
        restored!.userNote,
        '1:15 ratio with medium coarse grind, steep exactly 4 minutes.',
      );
      expect(restored.isStarred, isTrue);
      expect(restored.tags.length, 1);
      expect(restored.tags.first.name, 'Gourmet Recipes');
    });

    test(
      'merges backup data into existing items without overwriting',
      () async {
        await db
            .into(db.savedItemsTable)
            .insert(
              SavedItemsTableCompanion.insert(
                id: 'post_frieren_mimic',
                permalink: '/r/Frieren/comments/mimic/',
                itemType: ItemType.post,
                title: 'Untitled Post',
                subreddit: 'Frieren',
                savedAtUtc: DateTime.utc(2026, 1, 1),
                isStarred: const Value(false),
                enrichmentStatus: const Value(EnrichmentStatus.slugOnly),
              ),
            );

        final richItem = SavedItem(
          id: 'post_frieren_mimic',
          permalink: '/r/Frieren/comments/mimic/',
          itemType: ItemType.post,
          title: 'It might be a real grimoire this time (99% chance of mimic)',
          subreddit: 'Frieren',
          author: 'frieren_mage',
          body: 'Dark! It is so dark and terrifying!',
          score: 1000,
          isStarred: true,
          userNote: 'Grimoire that sees through clothes found on floor 48',
          importOrder: 1,
          savedAtUtc: DateTime.utc(2026, 1, 1),
          enrichmentStatus: EnrichmentStatus.enriched,
          tags: const [Tag(id: 10, name: 'Mimic Trap', colorValue: 0xFFFF4500)],
        );

        final backupBytes = backupService.createBackup([richItem]);
        final summary = await repository.restoreFromBackup(backupBytes);

        expect(summary.totalFound, 1);
        expect(summary.newItemsImported, 0);
        expect(summary.updatedItems, 1);
        expect(summary.skippedItems, 0);

        final merged = await repository.getItemById('post_frieren_mimic');
        expect(merged, isNotNull);
        expect(
          merged!.title,
          'It might be a real grimoire this time (99% chance of mimic)',
        );
        expect(merged.isStarred, isTrue);
        expect(
          merged.userNote,
          'Grimoire that sees through clothes found on floor 48',
        );
        expect(merged.tags.length, 1);
        expect(merged.tags.first.name, 'Mimic Trap');
      },
    );

    test('reuses existing tags without violating unique constraint', () async {
      final existingTagId = await db
          .into(db.tagsTable)
          .insert(
            TagsTableCompanion.insert(
              name: 'Orange Cat Energy',
              colorValue: const Value(0xFFFF8C00),
            ),
          );

      final item = SavedItem(
        id: 'post_orange_cat_loaf',
        permalink:
            '/r/OneOrangeBraincell/comments/loaf/searching_for_the_braincell/',
        itemType: ItemType.post,
        title: 'Waiting for the single brain cell to connect while loafing',
        subreddit: 'OneOrangeBraincell',
        author: 'purrfect_whiskers',
        importOrder: 1,
        savedAtUtc: DateTime.utc(2026, 2, 1),
        tags: const [
          Tag(id: 99, name: 'Orange Cat Energy', colorValue: 0xFFFFA500),
        ],
      );

      final backupBytes = backupService.createBackup([item]);
      final summary = await repository.restoreFromBackup(backupBytes);

      expect(summary.newItemsImported, 1);

      final allTags = await db.select(db.tagsTable).get();
      expect(allTags.length, 1);
      expect(allTags.first.id, existingTagId);
      expect(allTags.first.name, 'Orange Cat Energy');

      final restored = await repository.getItemById('post_orange_cat_loaf');
      expect(restored!.tags.length, 1);
      expect(restored.tags.first.id, existingTagId);
    });

    test('handles empty backup', () async {
      const emptyPayload = SavedexBackupPayload(
        version: 1,
        items: [],
        itemTags: {},
      );

      final summary = await repository.restoreFromPayload(emptyPayload);
      expect(summary.totalFound, 0);
      expect(summary.newItemsImported, 0);
      expect(summary.updatedItems, 0);
      expect(summary.skippedItems, 0);
    });

    test(
      'importFromZip peeks and rejects zip missing saved_posts/comments',
      () async {
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string('photos/sample_image.png', 'binary data'),
        );
        archive.addFile(
          ArchiveFile.string('reddit/chat_history.csv', 'chat1,hello'),
        );
        final zipBytes = ZipEncoder().encode(archive);

        expect(
          () => repository.importFromZip(zipBytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Expected "saved_posts.csv" or "saved_comments.csv"'),
            ),
          ),
        );
      },
    );

    test(
      'importFromZip successfully imports valid Reddit takeout zip',
      () async {
        final archive = Archive();
        archive.addFile(
          ArchiveFile.string(
            'user_data/saved_posts.csv',
            'id,permalink\nt3_post_1,/r/technology/comments/abc123/future_of_computing/',
          ),
        );
        final zipBytes = ZipEncoder().encode(archive);

        final summary = await repository.importFromZip(zipBytes);
        expect(summary.totalFound, 1);
        expect(summary.newItemsImported, 1);
        expect(summary.totalInDatabase, 1);

        final item = await repository.getItemById('t3_post_1');
        expect(item, isNotNull);
        expect(item!.permalink, contains('future_of_computing'));
      },
    );

    test('restoreFromBackup rejects non-Savedex JSON without decompressing or parsing', () async {
      const randomJson = '{"package": "my_app", "version": 1}';
      final bytes = utf8.encode(randomJson);

      expect(
        () => repository.restoreFromBackup(bytes, sourceName: 'random.json'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
