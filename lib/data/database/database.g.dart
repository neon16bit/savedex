// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SavedItemsTableTable extends SavedItemsTable
    with TableInfo<$SavedItemsTableTable, SavedItemEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _permalinkMeta = const VerificationMeta(
    'permalink',
  );
  @override
  late final GeneratedColumn<String> permalink = GeneratedColumn<String>(
    'permalink',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemType, int> itemType =
      GeneratedColumn<int>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ItemType>($SavedItemsTableTable.$converteritemType);
  static const VerificationMeta _parentPostIdMeta = const VerificationMeta(
    'parentPostId',
  );
  @override
  late final GeneratedColumn<String> parentPostId = GeneratedColumn<String>(
    'parent_post_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentPostTitleMeta = const VerificationMeta(
    'parentPostTitle',
  );
  @override
  late final GeneratedColumn<String> parentPostTitle = GeneratedColumn<String>(
    'parent_post_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subredditMeta = const VerificationMeta(
    'subreddit',
  );
  @override
  late final GeneratedColumn<String> subreddit = GeneratedColumn<String>(
    'subreddit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaUrlMeta = const VerificationMeta(
    'mediaUrl',
  );
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
    'media_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _galleryImagesMeta = const VerificationMeta(
    'galleryImages',
  );
  @override
  late final GeneratedColumn<String> galleryImages = GeneratedColumn<String>(
    'gallery_images',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _galleryPreviewImagesMeta =
      const VerificationMeta('galleryPreviewImages');
  @override
  late final GeneratedColumn<String> galleryPreviewImages =
      GeneratedColumn<String>(
        'gallery_preview_images',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<MediaType, int> mediaType =
      GeneratedColumn<int>(
        'media_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(MediaType.text.index),
      ).withConverter<MediaType>($SavedItemsTableTable.$convertermediaType);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _numCommentsMeta = const VerificationMeta(
    'numComments',
  );
  @override
  late final GeneratedColumn<int> numComments = GeneratedColumn<int>(
    'num_comments',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isNsfwMeta = const VerificationMeta('isNsfw');
  @override
  late final GeneratedColumn<bool> isNsfw = GeneratedColumn<bool>(
    'is_nsfw',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_nsfw" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isStarredMeta = const VerificationMeta(
    'isStarred',
  );
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
    'is_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userNoteMeta = const VerificationMeta(
    'userNote',
  );
  @override
  late final GeneratedColumn<String> userNote = GeneratedColumn<String>(
    'user_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _csvSourceMeta = const VerificationMeta(
    'csvSource',
  );
  @override
  late final GeneratedColumn<String> csvSource = GeneratedColumn<String>(
    'csv_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('saved_posts.csv'),
  );
  static const VerificationMeta _importOrderMeta = const VerificationMeta(
    'importOrder',
  );
  @override
  late final GeneratedColumn<int> importOrder = GeneratedColumn<int>(
    'import_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAtUtcMeta = const VerificationMeta(
    'savedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> savedAtUtc = GeneratedColumn<DateTime>(
    'saved_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postFlairMeta = const VerificationMeta(
    'postFlair',
  );
  @override
  late final GeneratedColumn<String> postFlair = GeneratedColumn<String>(
    'post_flair',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subredditTypeMeta = const VerificationMeta(
    'subredditType',
  );
  @override
  late final GeneratedColumn<String> subredditType = GeneratedColumn<String>(
    'subreddit_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('public'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<EnrichmentStatus, int>
  enrichmentStatus =
      GeneratedColumn<int>(
        'enrichment_status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(EnrichmentStatus.slugOnly.index),
      ).withConverter<EnrichmentStatus>(
        $SavedItemsTableTable.$converterenrichmentStatus,
      );
  static const VerificationMeta _isArchiveRecoveredMeta =
      const VerificationMeta('isArchiveRecovered');
  @override
  late final GeneratedColumn<bool> isArchiveRecovered = GeneratedColumn<bool>(
    'is_archive_recovered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archive_recovered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchiveUnavailableMeta =
      const VerificationMeta('isArchiveUnavailable');
  @override
  late final GeneratedColumn<bool> isArchiveUnavailable = GeneratedColumn<bool>(
    'is_archive_unavailable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archive_unavailable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    permalink,
    itemType,
    parentPostId,
    parentPostTitle,
    title,
    subreddit,
    author,
    body,
    url,
    thumbnailUrl,
    mediaUrl,
    galleryImages,
    galleryPreviewImages,
    mediaType,
    score,
    numComments,
    isNsfw,
    isStarred,
    isArchived,
    userNote,
    csvSource,
    importOrder,
    createdAtUtc,
    savedAtUtc,
    postFlair,
    subredditType,
    enrichmentStatus,
    isArchiveRecovered,
    isArchiveUnavailable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_items_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedItemEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('permalink')) {
      context.handle(
        _permalinkMeta,
        permalink.isAcceptableOrUnknown(data['permalink']!, _permalinkMeta),
      );
    } else if (isInserting) {
      context.missing(_permalinkMeta);
    }
    if (data.containsKey('parent_post_id')) {
      context.handle(
        _parentPostIdMeta,
        parentPostId.isAcceptableOrUnknown(
          data['parent_post_id']!,
          _parentPostIdMeta,
        ),
      );
    }
    if (data.containsKey('parent_post_title')) {
      context.handle(
        _parentPostTitleMeta,
        parentPostTitle.isAcceptableOrUnknown(
          data['parent_post_title']!,
          _parentPostTitleMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subreddit')) {
      context.handle(
        _subredditMeta,
        subreddit.isAcceptableOrUnknown(data['subreddit']!, _subredditMeta),
      );
    } else if (isInserting) {
      context.missing(_subredditMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('media_url')) {
      context.handle(
        _mediaUrlMeta,
        mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta),
      );
    }
    if (data.containsKey('gallery_images')) {
      context.handle(
        _galleryImagesMeta,
        galleryImages.isAcceptableOrUnknown(
          data['gallery_images']!,
          _galleryImagesMeta,
        ),
      );
    }
    if (data.containsKey('gallery_preview_images')) {
      context.handle(
        _galleryPreviewImagesMeta,
        galleryPreviewImages.isAcceptableOrUnknown(
          data['gallery_preview_images']!,
          _galleryPreviewImagesMeta,
        ),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('num_comments')) {
      context.handle(
        _numCommentsMeta,
        numComments.isAcceptableOrUnknown(
          data['num_comments']!,
          _numCommentsMeta,
        ),
      );
    }
    if (data.containsKey('is_nsfw')) {
      context.handle(
        _isNsfwMeta,
        isNsfw.isAcceptableOrUnknown(data['is_nsfw']!, _isNsfwMeta),
      );
    }
    if (data.containsKey('is_starred')) {
      context.handle(
        _isStarredMeta,
        isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('user_note')) {
      context.handle(
        _userNoteMeta,
        userNote.isAcceptableOrUnknown(data['user_note']!, _userNoteMeta),
      );
    }
    if (data.containsKey('csv_source')) {
      context.handle(
        _csvSourceMeta,
        csvSource.isAcceptableOrUnknown(data['csv_source']!, _csvSourceMeta),
      );
    }
    if (data.containsKey('import_order')) {
      context.handle(
        _importOrderMeta,
        importOrder.isAcceptableOrUnknown(
          data['import_order']!,
          _importOrderMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('saved_at_utc')) {
      context.handle(
        _savedAtUtcMeta,
        savedAtUtc.isAcceptableOrUnknown(
          data['saved_at_utc']!,
          _savedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_savedAtUtcMeta);
    }
    if (data.containsKey('post_flair')) {
      context.handle(
        _postFlairMeta,
        postFlair.isAcceptableOrUnknown(data['post_flair']!, _postFlairMeta),
      );
    }
    if (data.containsKey('subreddit_type')) {
      context.handle(
        _subredditTypeMeta,
        subredditType.isAcceptableOrUnknown(
          data['subreddit_type']!,
          _subredditTypeMeta,
        ),
      );
    }
    if (data.containsKey('is_archive_recovered')) {
      context.handle(
        _isArchiveRecoveredMeta,
        isArchiveRecovered.isAcceptableOrUnknown(
          data['is_archive_recovered']!,
          _isArchiveRecoveredMeta,
        ),
      );
    }
    if (data.containsKey('is_archive_unavailable')) {
      context.handle(
        _isArchiveUnavailableMeta,
        isArchiveUnavailable.isAcceptableOrUnknown(
          data['is_archive_unavailable']!,
          _isArchiveUnavailableMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedItemEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      permalink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permalink'],
      )!,
      itemType: $SavedItemsTableTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      parentPostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_post_id'],
      ),
      parentPostTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_post_title'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subreddit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subreddit'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      mediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_url'],
      ),
      galleryImages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gallery_images'],
      ),
      galleryPreviewImages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gallery_preview_images'],
      ),
      mediaType: $SavedItemsTableTable.$convertermediaType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}media_type'],
        )!,
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      numComments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}num_comments'],
      )!,
      isNsfw: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_nsfw'],
      )!,
      isStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_starred'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      userNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_note'],
      ),
      csvSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}csv_source'],
      )!,
      importOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_order'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      ),
      savedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at_utc'],
      )!,
      postFlair: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_flair'],
      ),
      subredditType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subreddit_type'],
      )!,
      enrichmentStatus: $SavedItemsTableTable.$converterenrichmentStatus
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}enrichment_status'],
            )!,
          ),
      isArchiveRecovered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archive_recovered'],
      )!,
      isArchiveUnavailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archive_unavailable'],
      )!,
    );
  }

  @override
  $SavedItemsTableTable createAlias(String alias) {
    return $SavedItemsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemType, int, int> $converteritemType =
      const EnumIndexConverter<ItemType>(ItemType.values);
  static JsonTypeConverter2<MediaType, int, int> $convertermediaType =
      const EnumIndexConverter<MediaType>(MediaType.values);
  static JsonTypeConverter2<EnrichmentStatus, int, int>
  $converterenrichmentStatus = const EnumIndexConverter<EnrichmentStatus>(
    EnrichmentStatus.values,
  );
}

class SavedItemEntry extends DataClass implements Insertable<SavedItemEntry> {
  final String id;
  final String permalink;
  final ItemType itemType;
  final String? parentPostId;
  final String? parentPostTitle;
  final String title;
  final String subreddit;
  final String? author;
  final String? body;
  final String? url;
  final String? thumbnailUrl;
  final String? mediaUrl;
  final String? galleryImages;
  final String? galleryPreviewImages;
  final MediaType mediaType;
  final int score;
  final int numComments;
  final bool isNsfw;
  final bool isStarred;
  final bool isArchived;
  final String? userNote;
  final String csvSource;
  final int importOrder;
  final DateTime? createdAtUtc;
  final DateTime savedAtUtc;
  final String? postFlair;
  final String subredditType;
  final EnrichmentStatus enrichmentStatus;
  final bool isArchiveRecovered;
  final bool isArchiveUnavailable;
  const SavedItemEntry({
    required this.id,
    required this.permalink,
    required this.itemType,
    this.parentPostId,
    this.parentPostTitle,
    required this.title,
    required this.subreddit,
    this.author,
    this.body,
    this.url,
    this.thumbnailUrl,
    this.mediaUrl,
    this.galleryImages,
    this.galleryPreviewImages,
    required this.mediaType,
    required this.score,
    required this.numComments,
    required this.isNsfw,
    required this.isStarred,
    required this.isArchived,
    this.userNote,
    required this.csvSource,
    required this.importOrder,
    this.createdAtUtc,
    required this.savedAtUtc,
    this.postFlair,
    required this.subredditType,
    required this.enrichmentStatus,
    required this.isArchiveRecovered,
    required this.isArchiveUnavailable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['permalink'] = Variable<String>(permalink);
    {
      map['item_type'] = Variable<int>(
        $SavedItemsTableTable.$converteritemType.toSql(itemType),
      );
    }
    if (!nullToAbsent || parentPostId != null) {
      map['parent_post_id'] = Variable<String>(parentPostId);
    }
    if (!nullToAbsent || parentPostTitle != null) {
      map['parent_post_title'] = Variable<String>(parentPostTitle);
    }
    map['title'] = Variable<String>(title);
    map['subreddit'] = Variable<String>(subreddit);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || galleryImages != null) {
      map['gallery_images'] = Variable<String>(galleryImages);
    }
    if (!nullToAbsent || galleryPreviewImages != null) {
      map['gallery_preview_images'] = Variable<String>(galleryPreviewImages);
    }
    {
      map['media_type'] = Variable<int>(
        $SavedItemsTableTable.$convertermediaType.toSql(mediaType),
      );
    }
    map['score'] = Variable<int>(score);
    map['num_comments'] = Variable<int>(numComments);
    map['is_nsfw'] = Variable<bool>(isNsfw);
    map['is_starred'] = Variable<bool>(isStarred);
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || userNote != null) {
      map['user_note'] = Variable<String>(userNote);
    }
    map['csv_source'] = Variable<String>(csvSource);
    map['import_order'] = Variable<int>(importOrder);
    if (!nullToAbsent || createdAtUtc != null) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    }
    map['saved_at_utc'] = Variable<DateTime>(savedAtUtc);
    if (!nullToAbsent || postFlair != null) {
      map['post_flair'] = Variable<String>(postFlair);
    }
    map['subreddit_type'] = Variable<String>(subredditType);
    {
      map['enrichment_status'] = Variable<int>(
        $SavedItemsTableTable.$converterenrichmentStatus.toSql(
          enrichmentStatus,
        ),
      );
    }
    map['is_archive_recovered'] = Variable<bool>(isArchiveRecovered);
    map['is_archive_unavailable'] = Variable<bool>(isArchiveUnavailable);
    return map;
  }

  SavedItemsTableCompanion toCompanion(bool nullToAbsent) {
    return SavedItemsTableCompanion(
      id: Value(id),
      permalink: Value(permalink),
      itemType: Value(itemType),
      parentPostId: parentPostId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentPostId),
      parentPostTitle: parentPostTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(parentPostTitle),
      title: Value(title),
      subreddit: Value(subreddit),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      galleryImages: galleryImages == null && nullToAbsent
          ? const Value.absent()
          : Value(galleryImages),
      galleryPreviewImages: galleryPreviewImages == null && nullToAbsent
          ? const Value.absent()
          : Value(galleryPreviewImages),
      mediaType: Value(mediaType),
      score: Value(score),
      numComments: Value(numComments),
      isNsfw: Value(isNsfw),
      isStarred: Value(isStarred),
      isArchived: Value(isArchived),
      userNote: userNote == null && nullToAbsent
          ? const Value.absent()
          : Value(userNote),
      csvSource: Value(csvSource),
      importOrder: Value(importOrder),
      createdAtUtc: createdAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAtUtc),
      savedAtUtc: Value(savedAtUtc),
      postFlair: postFlair == null && nullToAbsent
          ? const Value.absent()
          : Value(postFlair),
      subredditType: Value(subredditType),
      enrichmentStatus: Value(enrichmentStatus),
      isArchiveRecovered: Value(isArchiveRecovered),
      isArchiveUnavailable: Value(isArchiveUnavailable),
    );
  }

  factory SavedItemEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedItemEntry(
      id: serializer.fromJson<String>(json['id']),
      permalink: serializer.fromJson<String>(json['permalink']),
      itemType: $SavedItemsTableTable.$converteritemType.fromJson(
        serializer.fromJson<int>(json['itemType']),
      ),
      parentPostId: serializer.fromJson<String?>(json['parentPostId']),
      parentPostTitle: serializer.fromJson<String?>(json['parentPostTitle']),
      title: serializer.fromJson<String>(json['title']),
      subreddit: serializer.fromJson<String>(json['subreddit']),
      author: serializer.fromJson<String?>(json['author']),
      body: serializer.fromJson<String?>(json['body']),
      url: serializer.fromJson<String?>(json['url']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      galleryImages: serializer.fromJson<String?>(json['galleryImages']),
      galleryPreviewImages: serializer.fromJson<String?>(
        json['galleryPreviewImages'],
      ),
      mediaType: $SavedItemsTableTable.$convertermediaType.fromJson(
        serializer.fromJson<int>(json['mediaType']),
      ),
      score: serializer.fromJson<int>(json['score']),
      numComments: serializer.fromJson<int>(json['numComments']),
      isNsfw: serializer.fromJson<bool>(json['isNsfw']),
      isStarred: serializer.fromJson<bool>(json['isStarred']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      userNote: serializer.fromJson<String?>(json['userNote']),
      csvSource: serializer.fromJson<String>(json['csvSource']),
      importOrder: serializer.fromJson<int>(json['importOrder']),
      createdAtUtc: serializer.fromJson<DateTime?>(json['createdAtUtc']),
      savedAtUtc: serializer.fromJson<DateTime>(json['savedAtUtc']),
      postFlair: serializer.fromJson<String?>(json['postFlair']),
      subredditType: serializer.fromJson<String>(json['subredditType']),
      enrichmentStatus: $SavedItemsTableTable.$converterenrichmentStatus
          .fromJson(serializer.fromJson<int>(json['enrichmentStatus'])),
      isArchiveRecovered: serializer.fromJson<bool>(json['isArchiveRecovered']),
      isArchiveUnavailable: serializer.fromJson<bool>(
        json['isArchiveUnavailable'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'permalink': serializer.toJson<String>(permalink),
      'itemType': serializer.toJson<int>(
        $SavedItemsTableTable.$converteritemType.toJson(itemType),
      ),
      'parentPostId': serializer.toJson<String?>(parentPostId),
      'parentPostTitle': serializer.toJson<String?>(parentPostTitle),
      'title': serializer.toJson<String>(title),
      'subreddit': serializer.toJson<String>(subreddit),
      'author': serializer.toJson<String?>(author),
      'body': serializer.toJson<String?>(body),
      'url': serializer.toJson<String?>(url),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'galleryImages': serializer.toJson<String?>(galleryImages),
      'galleryPreviewImages': serializer.toJson<String?>(galleryPreviewImages),
      'mediaType': serializer.toJson<int>(
        $SavedItemsTableTable.$convertermediaType.toJson(mediaType),
      ),
      'score': serializer.toJson<int>(score),
      'numComments': serializer.toJson<int>(numComments),
      'isNsfw': serializer.toJson<bool>(isNsfw),
      'isStarred': serializer.toJson<bool>(isStarred),
      'isArchived': serializer.toJson<bool>(isArchived),
      'userNote': serializer.toJson<String?>(userNote),
      'csvSource': serializer.toJson<String>(csvSource),
      'importOrder': serializer.toJson<int>(importOrder),
      'createdAtUtc': serializer.toJson<DateTime?>(createdAtUtc),
      'savedAtUtc': serializer.toJson<DateTime>(savedAtUtc),
      'postFlair': serializer.toJson<String?>(postFlair),
      'subredditType': serializer.toJson<String>(subredditType),
      'enrichmentStatus': serializer.toJson<int>(
        $SavedItemsTableTable.$converterenrichmentStatus.toJson(
          enrichmentStatus,
        ),
      ),
      'isArchiveRecovered': serializer.toJson<bool>(isArchiveRecovered),
      'isArchiveUnavailable': serializer.toJson<bool>(isArchiveUnavailable),
    };
  }

  SavedItemEntry copyWith({
    String? id,
    String? permalink,
    ItemType? itemType,
    Value<String?> parentPostId = const Value.absent(),
    Value<String?> parentPostTitle = const Value.absent(),
    String? title,
    String? subreddit,
    Value<String?> author = const Value.absent(),
    Value<String?> body = const Value.absent(),
    Value<String?> url = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> mediaUrl = const Value.absent(),
    Value<String?> galleryImages = const Value.absent(),
    Value<String?> galleryPreviewImages = const Value.absent(),
    MediaType? mediaType,
    int? score,
    int? numComments,
    bool? isNsfw,
    bool? isStarred,
    bool? isArchived,
    Value<String?> userNote = const Value.absent(),
    String? csvSource,
    int? importOrder,
    Value<DateTime?> createdAtUtc = const Value.absent(),
    DateTime? savedAtUtc,
    Value<String?> postFlair = const Value.absent(),
    String? subredditType,
    EnrichmentStatus? enrichmentStatus,
    bool? isArchiveRecovered,
    bool? isArchiveUnavailable,
  }) => SavedItemEntry(
    id: id ?? this.id,
    permalink: permalink ?? this.permalink,
    itemType: itemType ?? this.itemType,
    parentPostId: parentPostId.present ? parentPostId.value : this.parentPostId,
    parentPostTitle: parentPostTitle.present
        ? parentPostTitle.value
        : this.parentPostTitle,
    title: title ?? this.title,
    subreddit: subreddit ?? this.subreddit,
    author: author.present ? author.value : this.author,
    body: body.present ? body.value : this.body,
    url: url.present ? url.value : this.url,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
    galleryImages: galleryImages.present
        ? galleryImages.value
        : this.galleryImages,
    galleryPreviewImages: galleryPreviewImages.present
        ? galleryPreviewImages.value
        : this.galleryPreviewImages,
    mediaType: mediaType ?? this.mediaType,
    score: score ?? this.score,
    numComments: numComments ?? this.numComments,
    isNsfw: isNsfw ?? this.isNsfw,
    isStarred: isStarred ?? this.isStarred,
    isArchived: isArchived ?? this.isArchived,
    userNote: userNote.present ? userNote.value : this.userNote,
    csvSource: csvSource ?? this.csvSource,
    importOrder: importOrder ?? this.importOrder,
    createdAtUtc: createdAtUtc.present ? createdAtUtc.value : this.createdAtUtc,
    savedAtUtc: savedAtUtc ?? this.savedAtUtc,
    postFlair: postFlair.present ? postFlair.value : this.postFlair,
    subredditType: subredditType ?? this.subredditType,
    enrichmentStatus: enrichmentStatus ?? this.enrichmentStatus,
    isArchiveRecovered: isArchiveRecovered ?? this.isArchiveRecovered,
    isArchiveUnavailable: isArchiveUnavailable ?? this.isArchiveUnavailable,
  );
  SavedItemEntry copyWithCompanion(SavedItemsTableCompanion data) {
    return SavedItemEntry(
      id: data.id.present ? data.id.value : this.id,
      permalink: data.permalink.present ? data.permalink.value : this.permalink,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      parentPostId: data.parentPostId.present
          ? data.parentPostId.value
          : this.parentPostId,
      parentPostTitle: data.parentPostTitle.present
          ? data.parentPostTitle.value
          : this.parentPostTitle,
      title: data.title.present ? data.title.value : this.title,
      subreddit: data.subreddit.present ? data.subreddit.value : this.subreddit,
      author: data.author.present ? data.author.value : this.author,
      body: data.body.present ? data.body.value : this.body,
      url: data.url.present ? data.url.value : this.url,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      galleryImages: data.galleryImages.present
          ? data.galleryImages.value
          : this.galleryImages,
      galleryPreviewImages: data.galleryPreviewImages.present
          ? data.galleryPreviewImages.value
          : this.galleryPreviewImages,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      score: data.score.present ? data.score.value : this.score,
      numComments: data.numComments.present
          ? data.numComments.value
          : this.numComments,
      isNsfw: data.isNsfw.present ? data.isNsfw.value : this.isNsfw,
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      userNote: data.userNote.present ? data.userNote.value : this.userNote,
      csvSource: data.csvSource.present ? data.csvSource.value : this.csvSource,
      importOrder: data.importOrder.present
          ? data.importOrder.value
          : this.importOrder,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      savedAtUtc: data.savedAtUtc.present
          ? data.savedAtUtc.value
          : this.savedAtUtc,
      postFlair: data.postFlair.present ? data.postFlair.value : this.postFlair,
      subredditType: data.subredditType.present
          ? data.subredditType.value
          : this.subredditType,
      enrichmentStatus: data.enrichmentStatus.present
          ? data.enrichmentStatus.value
          : this.enrichmentStatus,
      isArchiveRecovered: data.isArchiveRecovered.present
          ? data.isArchiveRecovered.value
          : this.isArchiveRecovered,
      isArchiveUnavailable: data.isArchiveUnavailable.present
          ? data.isArchiveUnavailable.value
          : this.isArchiveUnavailable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedItemEntry(')
          ..write('id: $id, ')
          ..write('permalink: $permalink, ')
          ..write('itemType: $itemType, ')
          ..write('parentPostId: $parentPostId, ')
          ..write('parentPostTitle: $parentPostTitle, ')
          ..write('title: $title, ')
          ..write('subreddit: $subreddit, ')
          ..write('author: $author, ')
          ..write('body: $body, ')
          ..write('url: $url, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('galleryImages: $galleryImages, ')
          ..write('galleryPreviewImages: $galleryPreviewImages, ')
          ..write('mediaType: $mediaType, ')
          ..write('score: $score, ')
          ..write('numComments: $numComments, ')
          ..write('isNsfw: $isNsfw, ')
          ..write('isStarred: $isStarred, ')
          ..write('isArchived: $isArchived, ')
          ..write('userNote: $userNote, ')
          ..write('csvSource: $csvSource, ')
          ..write('importOrder: $importOrder, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('savedAtUtc: $savedAtUtc, ')
          ..write('postFlair: $postFlair, ')
          ..write('subredditType: $subredditType, ')
          ..write('enrichmentStatus: $enrichmentStatus, ')
          ..write('isArchiveRecovered: $isArchiveRecovered, ')
          ..write('isArchiveUnavailable: $isArchiveUnavailable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    permalink,
    itemType,
    parentPostId,
    parentPostTitle,
    title,
    subreddit,
    author,
    body,
    url,
    thumbnailUrl,
    mediaUrl,
    galleryImages,
    galleryPreviewImages,
    mediaType,
    score,
    numComments,
    isNsfw,
    isStarred,
    isArchived,
    userNote,
    csvSource,
    importOrder,
    createdAtUtc,
    savedAtUtc,
    postFlair,
    subredditType,
    enrichmentStatus,
    isArchiveRecovered,
    isArchiveUnavailable,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedItemEntry &&
          other.id == this.id &&
          other.permalink == this.permalink &&
          other.itemType == this.itemType &&
          other.parentPostId == this.parentPostId &&
          other.parentPostTitle == this.parentPostTitle &&
          other.title == this.title &&
          other.subreddit == this.subreddit &&
          other.author == this.author &&
          other.body == this.body &&
          other.url == this.url &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.mediaUrl == this.mediaUrl &&
          other.galleryImages == this.galleryImages &&
          other.galleryPreviewImages == this.galleryPreviewImages &&
          other.mediaType == this.mediaType &&
          other.score == this.score &&
          other.numComments == this.numComments &&
          other.isNsfw == this.isNsfw &&
          other.isStarred == this.isStarred &&
          other.isArchived == this.isArchived &&
          other.userNote == this.userNote &&
          other.csvSource == this.csvSource &&
          other.importOrder == this.importOrder &&
          other.createdAtUtc == this.createdAtUtc &&
          other.savedAtUtc == this.savedAtUtc &&
          other.postFlair == this.postFlair &&
          other.subredditType == this.subredditType &&
          other.enrichmentStatus == this.enrichmentStatus &&
          other.isArchiveRecovered == this.isArchiveRecovered &&
          other.isArchiveUnavailable == this.isArchiveUnavailable);
}

class SavedItemsTableCompanion extends UpdateCompanion<SavedItemEntry> {
  final Value<String> id;
  final Value<String> permalink;
  final Value<ItemType> itemType;
  final Value<String?> parentPostId;
  final Value<String?> parentPostTitle;
  final Value<String> title;
  final Value<String> subreddit;
  final Value<String?> author;
  final Value<String?> body;
  final Value<String?> url;
  final Value<String?> thumbnailUrl;
  final Value<String?> mediaUrl;
  final Value<String?> galleryImages;
  final Value<String?> galleryPreviewImages;
  final Value<MediaType> mediaType;
  final Value<int> score;
  final Value<int> numComments;
  final Value<bool> isNsfw;
  final Value<bool> isStarred;
  final Value<bool> isArchived;
  final Value<String?> userNote;
  final Value<String> csvSource;
  final Value<int> importOrder;
  final Value<DateTime?> createdAtUtc;
  final Value<DateTime> savedAtUtc;
  final Value<String?> postFlair;
  final Value<String> subredditType;
  final Value<EnrichmentStatus> enrichmentStatus;
  final Value<bool> isArchiveRecovered;
  final Value<bool> isArchiveUnavailable;
  final Value<int> rowid;
  const SavedItemsTableCompanion({
    this.id = const Value.absent(),
    this.permalink = const Value.absent(),
    this.itemType = const Value.absent(),
    this.parentPostId = const Value.absent(),
    this.parentPostTitle = const Value.absent(),
    this.title = const Value.absent(),
    this.subreddit = const Value.absent(),
    this.author = const Value.absent(),
    this.body = const Value.absent(),
    this.url = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.galleryImages = const Value.absent(),
    this.galleryPreviewImages = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.score = const Value.absent(),
    this.numComments = const Value.absent(),
    this.isNsfw = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.userNote = const Value.absent(),
    this.csvSource = const Value.absent(),
    this.importOrder = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.savedAtUtc = const Value.absent(),
    this.postFlair = const Value.absent(),
    this.subredditType = const Value.absent(),
    this.enrichmentStatus = const Value.absent(),
    this.isArchiveRecovered = const Value.absent(),
    this.isArchiveUnavailable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedItemsTableCompanion.insert({
    required String id,
    required String permalink,
    required ItemType itemType,
    this.parentPostId = const Value.absent(),
    this.parentPostTitle = const Value.absent(),
    required String title,
    required String subreddit,
    this.author = const Value.absent(),
    this.body = const Value.absent(),
    this.url = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.galleryImages = const Value.absent(),
    this.galleryPreviewImages = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.score = const Value.absent(),
    this.numComments = const Value.absent(),
    this.isNsfw = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.userNote = const Value.absent(),
    this.csvSource = const Value.absent(),
    this.importOrder = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    required DateTime savedAtUtc,
    this.postFlair = const Value.absent(),
    this.subredditType = const Value.absent(),
    this.enrichmentStatus = const Value.absent(),
    this.isArchiveRecovered = const Value.absent(),
    this.isArchiveUnavailable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       permalink = Value(permalink),
       itemType = Value(itemType),
       title = Value(title),
       subreddit = Value(subreddit),
       savedAtUtc = Value(savedAtUtc);
  static Insertable<SavedItemEntry> custom({
    Expression<String>? id,
    Expression<String>? permalink,
    Expression<int>? itemType,
    Expression<String>? parentPostId,
    Expression<String>? parentPostTitle,
    Expression<String>? title,
    Expression<String>? subreddit,
    Expression<String>? author,
    Expression<String>? body,
    Expression<String>? url,
    Expression<String>? thumbnailUrl,
    Expression<String>? mediaUrl,
    Expression<String>? galleryImages,
    Expression<String>? galleryPreviewImages,
    Expression<int>? mediaType,
    Expression<int>? score,
    Expression<int>? numComments,
    Expression<bool>? isNsfw,
    Expression<bool>? isStarred,
    Expression<bool>? isArchived,
    Expression<String>? userNote,
    Expression<String>? csvSource,
    Expression<int>? importOrder,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? savedAtUtc,
    Expression<String>? postFlair,
    Expression<String>? subredditType,
    Expression<int>? enrichmentStatus,
    Expression<bool>? isArchiveRecovered,
    Expression<bool>? isArchiveUnavailable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (permalink != null) 'permalink': permalink,
      if (itemType != null) 'item_type': itemType,
      if (parentPostId != null) 'parent_post_id': parentPostId,
      if (parentPostTitle != null) 'parent_post_title': parentPostTitle,
      if (title != null) 'title': title,
      if (subreddit != null) 'subreddit': subreddit,
      if (author != null) 'author': author,
      if (body != null) 'body': body,
      if (url != null) 'url': url,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (galleryImages != null) 'gallery_images': galleryImages,
      if (galleryPreviewImages != null)
        'gallery_preview_images': galleryPreviewImages,
      if (mediaType != null) 'media_type': mediaType,
      if (score != null) 'score': score,
      if (numComments != null) 'num_comments': numComments,
      if (isNsfw != null) 'is_nsfw': isNsfw,
      if (isStarred != null) 'is_starred': isStarred,
      if (isArchived != null) 'is_archived': isArchived,
      if (userNote != null) 'user_note': userNote,
      if (csvSource != null) 'csv_source': csvSource,
      if (importOrder != null) 'import_order': importOrder,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (savedAtUtc != null) 'saved_at_utc': savedAtUtc,
      if (postFlair != null) 'post_flair': postFlair,
      if (subredditType != null) 'subreddit_type': subredditType,
      if (enrichmentStatus != null) 'enrichment_status': enrichmentStatus,
      if (isArchiveRecovered != null)
        'is_archive_recovered': isArchiveRecovered,
      if (isArchiveUnavailable != null)
        'is_archive_unavailable': isArchiveUnavailable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedItemsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? permalink,
    Value<ItemType>? itemType,
    Value<String?>? parentPostId,
    Value<String?>? parentPostTitle,
    Value<String>? title,
    Value<String>? subreddit,
    Value<String?>? author,
    Value<String?>? body,
    Value<String?>? url,
    Value<String?>? thumbnailUrl,
    Value<String?>? mediaUrl,
    Value<String?>? galleryImages,
    Value<String?>? galleryPreviewImages,
    Value<MediaType>? mediaType,
    Value<int>? score,
    Value<int>? numComments,
    Value<bool>? isNsfw,
    Value<bool>? isStarred,
    Value<bool>? isArchived,
    Value<String?>? userNote,
    Value<String>? csvSource,
    Value<int>? importOrder,
    Value<DateTime?>? createdAtUtc,
    Value<DateTime>? savedAtUtc,
    Value<String?>? postFlair,
    Value<String>? subredditType,
    Value<EnrichmentStatus>? enrichmentStatus,
    Value<bool>? isArchiveRecovered,
    Value<bool>? isArchiveUnavailable,
    Value<int>? rowid,
  }) {
    return SavedItemsTableCompanion(
      id: id ?? this.id,
      permalink: permalink ?? this.permalink,
      itemType: itemType ?? this.itemType,
      parentPostId: parentPostId ?? this.parentPostId,
      parentPostTitle: parentPostTitle ?? this.parentPostTitle,
      title: title ?? this.title,
      subreddit: subreddit ?? this.subreddit,
      author: author ?? this.author,
      body: body ?? this.body,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      galleryPreviewImages: galleryPreviewImages ?? this.galleryPreviewImages,
      mediaType: mediaType ?? this.mediaType,
      score: score ?? this.score,
      numComments: numComments ?? this.numComments,
      isNsfw: isNsfw ?? this.isNsfw,
      isStarred: isStarred ?? this.isStarred,
      isArchived: isArchived ?? this.isArchived,
      userNote: userNote ?? this.userNote,
      csvSource: csvSource ?? this.csvSource,
      importOrder: importOrder ?? this.importOrder,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      savedAtUtc: savedAtUtc ?? this.savedAtUtc,
      postFlair: postFlair ?? this.postFlair,
      subredditType: subredditType ?? this.subredditType,
      enrichmentStatus: enrichmentStatus ?? this.enrichmentStatus,
      isArchiveRecovered: isArchiveRecovered ?? this.isArchiveRecovered,
      isArchiveUnavailable: isArchiveUnavailable ?? this.isArchiveUnavailable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (permalink.present) {
      map['permalink'] = Variable<String>(permalink.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<int>(
        $SavedItemsTableTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (parentPostId.present) {
      map['parent_post_id'] = Variable<String>(parentPostId.value);
    }
    if (parentPostTitle.present) {
      map['parent_post_title'] = Variable<String>(parentPostTitle.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subreddit.present) {
      map['subreddit'] = Variable<String>(subreddit.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (galleryImages.present) {
      map['gallery_images'] = Variable<String>(galleryImages.value);
    }
    if (galleryPreviewImages.present) {
      map['gallery_preview_images'] = Variable<String>(
        galleryPreviewImages.value,
      );
    }
    if (mediaType.present) {
      map['media_type'] = Variable<int>(
        $SavedItemsTableTable.$convertermediaType.toSql(mediaType.value),
      );
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (numComments.present) {
      map['num_comments'] = Variable<int>(numComments.value);
    }
    if (isNsfw.present) {
      map['is_nsfw'] = Variable<bool>(isNsfw.value);
    }
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (userNote.present) {
      map['user_note'] = Variable<String>(userNote.value);
    }
    if (csvSource.present) {
      map['csv_source'] = Variable<String>(csvSource.value);
    }
    if (importOrder.present) {
      map['import_order'] = Variable<int>(importOrder.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (savedAtUtc.present) {
      map['saved_at_utc'] = Variable<DateTime>(savedAtUtc.value);
    }
    if (postFlair.present) {
      map['post_flair'] = Variable<String>(postFlair.value);
    }
    if (subredditType.present) {
      map['subreddit_type'] = Variable<String>(subredditType.value);
    }
    if (enrichmentStatus.present) {
      map['enrichment_status'] = Variable<int>(
        $SavedItemsTableTable.$converterenrichmentStatus.toSql(
          enrichmentStatus.value,
        ),
      );
    }
    if (isArchiveRecovered.present) {
      map['is_archive_recovered'] = Variable<bool>(isArchiveRecovered.value);
    }
    if (isArchiveUnavailable.present) {
      map['is_archive_unavailable'] = Variable<bool>(
        isArchiveUnavailable.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('permalink: $permalink, ')
          ..write('itemType: $itemType, ')
          ..write('parentPostId: $parentPostId, ')
          ..write('parentPostTitle: $parentPostTitle, ')
          ..write('title: $title, ')
          ..write('subreddit: $subreddit, ')
          ..write('author: $author, ')
          ..write('body: $body, ')
          ..write('url: $url, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('galleryImages: $galleryImages, ')
          ..write('galleryPreviewImages: $galleryPreviewImages, ')
          ..write('mediaType: $mediaType, ')
          ..write('score: $score, ')
          ..write('numComments: $numComments, ')
          ..write('isNsfw: $isNsfw, ')
          ..write('isStarred: $isStarred, ')
          ..write('isArchived: $isArchived, ')
          ..write('userNote: $userNote, ')
          ..write('csvSource: $csvSource, ')
          ..write('importOrder: $importOrder, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('savedAtUtc: $savedAtUtc, ')
          ..write('postFlair: $postFlair, ')
          ..write('subredditType: $subredditType, ')
          ..write('enrichmentStatus: $enrichmentStatus, ')
          ..write('isArchiveRecovered: $isArchiveRecovered, ')
          ..write('isArchiveUnavailable: $isArchiveUnavailable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionsTableTable extends CollectionsTable
    with TableInfo<$CollectionsTableTable, CollectionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFFFF4500),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    colorValue,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      ),
    );
  }

  @override
  $CollectionsTableTable createAlias(String alias) {
    return $CollectionsTableTable(attachedDatabase, alias);
  }
}

class CollectionEntry extends DataClass implements Insertable<CollectionEntry> {
  final int id;
  final String name;
  final String? description;
  final int colorValue;
  final DateTime? createdAtUtc;
  const CollectionEntry({
    required this.id,
    required this.name,
    this.description,
    required this.colorValue,
    this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || createdAtUtc != null) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    }
    return map;
  }

  CollectionsTableCompanion toCompanion(bool nullToAbsent) {
    return CollectionsTableCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      colorValue: Value(colorValue),
      createdAtUtc: createdAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAtUtc),
    );
  }

  factory CollectionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionEntry(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      createdAtUtc: serializer.fromJson<DateTime?>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'colorValue': serializer.toJson<int>(colorValue),
      'createdAtUtc': serializer.toJson<DateTime?>(createdAtUtc),
    };
  }

  CollectionEntry copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    int? colorValue,
    Value<DateTime?> createdAtUtc = const Value.absent(),
  }) => CollectionEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    colorValue: colorValue ?? this.colorValue,
    createdAtUtc: createdAtUtc.present ? createdAtUtc.value : this.createdAtUtc,
  );
  CollectionEntry copyWithCompanion(CollectionsTableCompanion data) {
    return CollectionEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, colorValue, createdAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.colorValue == this.colorValue &&
          other.createdAtUtc == this.createdAtUtc);
}

class CollectionsTableCompanion extends UpdateCompanion<CollectionEntry> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> colorValue;
  final Value<DateTime?> createdAtUtc;
  const CollectionsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
  });
  CollectionsTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
  }) : name = Value(name);
  static Insertable<CollectionEntry> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
    });
  }

  CollectionsTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? colorValue,
    Value<DateTime?>? createdAtUtc,
  }) {
    return CollectionsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }
}

class $ItemCollectionsTableTable extends ItemCollectionsTable
    with TableInfo<$ItemCollectionsTableTable, ItemCollectionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemCollectionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_items_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collections_table (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, collectionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_collections_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemCollectionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, collectionId};
  @override
  ItemCollectionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemCollectionEntry(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
    );
  }

  @override
  $ItemCollectionsTableTable createAlias(String alias) {
    return $ItemCollectionsTableTable(attachedDatabase, alias);
  }
}

class ItemCollectionEntry extends DataClass
    implements Insertable<ItemCollectionEntry> {
  final String itemId;
  final int collectionId;
  const ItemCollectionEntry({required this.itemId, required this.collectionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['collection_id'] = Variable<int>(collectionId);
    return map;
  }

  ItemCollectionsTableCompanion toCompanion(bool nullToAbsent) {
    return ItemCollectionsTableCompanion(
      itemId: Value(itemId),
      collectionId: Value(collectionId),
    );
  }

  factory ItemCollectionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemCollectionEntry(
      itemId: serializer.fromJson<String>(json['itemId']),
      collectionId: serializer.fromJson<int>(json['collectionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'collectionId': serializer.toJson<int>(collectionId),
    };
  }

  ItemCollectionEntry copyWith({String? itemId, int? collectionId}) =>
      ItemCollectionEntry(
        itemId: itemId ?? this.itemId,
        collectionId: collectionId ?? this.collectionId,
      );
  ItemCollectionEntry copyWithCompanion(ItemCollectionsTableCompanion data) {
    return ItemCollectionEntry(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemCollectionEntry(')
          ..write('itemId: $itemId, ')
          ..write('collectionId: $collectionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, collectionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemCollectionEntry &&
          other.itemId == this.itemId &&
          other.collectionId == this.collectionId);
}

class ItemCollectionsTableCompanion
    extends UpdateCompanion<ItemCollectionEntry> {
  final Value<String> itemId;
  final Value<int> collectionId;
  final Value<int> rowid;
  const ItemCollectionsTableCompanion({
    this.itemId = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemCollectionsTableCompanion.insert({
    required String itemId,
    required int collectionId,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       collectionId = Value(collectionId);
  static Insertable<ItemCollectionEntry> custom({
    Expression<String>? itemId,
    Expression<int>? collectionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (collectionId != null) 'collection_id': collectionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemCollectionsTableCompanion copyWith({
    Value<String>? itemId,
    Value<int>? collectionId,
    Value<int>? rowid,
  }) {
    return ItemCollectionsTableCompanion(
      itemId: itemId ?? this.itemId,
      collectionId: collectionId ?? this.collectionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemCollectionsTableCompanion(')
          ..write('itemId: $itemId, ')
          ..write('collectionId: $collectionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubredditsTableTable extends SubredditsTable
    with TableInfo<$SubredditsTableTable, SubredditEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubredditsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isNsfwMeta = const VerificationMeta('isNsfw');
  @override
  late final GeneratedColumn<bool> isNsfw = GeneratedColumn<bool>(
    'is_nsfw',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_nsfw" IN (0, 1))',
    ),
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckedMeta = const VerificationMeta(
    'lastChecked',
  );
  @override
  late final GeneratedColumn<DateTime> lastChecked = GeneratedColumn<DateTime>(
    'last_checked',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [name, isNsfw, iconUrl, lastChecked];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subreddits_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubredditEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_nsfw')) {
      context.handle(
        _isNsfwMeta,
        isNsfw.isAcceptableOrUnknown(data['is_nsfw']!, _isNsfwMeta),
      );
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    if (data.containsKey('last_checked')) {
      context.handle(
        _lastCheckedMeta,
        lastChecked.isAcceptableOrUnknown(
          data['last_checked']!,
          _lastCheckedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  SubredditEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubredditEntry(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isNsfw: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_nsfw'],
      ),
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
      lastChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_checked'],
      ),
    );
  }

  @override
  $SubredditsTableTable createAlias(String alias) {
    return $SubredditsTableTable(attachedDatabase, alias);
  }
}

class SubredditEntry extends DataClass implements Insertable<SubredditEntry> {
  final String name;
  final bool? isNsfw;
  final String? iconUrl;
  final DateTime? lastChecked;
  const SubredditEntry({
    required this.name,
    this.isNsfw,
    this.iconUrl,
    this.lastChecked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || isNsfw != null) {
      map['is_nsfw'] = Variable<bool>(isNsfw);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || lastChecked != null) {
      map['last_checked'] = Variable<DateTime>(lastChecked);
    }
    return map;
  }

  SubredditsTableCompanion toCompanion(bool nullToAbsent) {
    return SubredditsTableCompanion(
      name: Value(name),
      isNsfw: isNsfw == null && nullToAbsent
          ? const Value.absent()
          : Value(isNsfw),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      lastChecked: lastChecked == null && nullToAbsent
          ? const Value.absent()
          : Value(lastChecked),
    );
  }

  factory SubredditEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubredditEntry(
      name: serializer.fromJson<String>(json['name']),
      isNsfw: serializer.fromJson<bool?>(json['isNsfw']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      lastChecked: serializer.fromJson<DateTime?>(json['lastChecked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'isNsfw': serializer.toJson<bool?>(isNsfw),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'lastChecked': serializer.toJson<DateTime?>(lastChecked),
    };
  }

  SubredditEntry copyWith({
    String? name,
    Value<bool?> isNsfw = const Value.absent(),
    Value<String?> iconUrl = const Value.absent(),
    Value<DateTime?> lastChecked = const Value.absent(),
  }) => SubredditEntry(
    name: name ?? this.name,
    isNsfw: isNsfw.present ? isNsfw.value : this.isNsfw,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
    lastChecked: lastChecked.present ? lastChecked.value : this.lastChecked,
  );
  SubredditEntry copyWithCompanion(SubredditsTableCompanion data) {
    return SubredditEntry(
      name: data.name.present ? data.name.value : this.name,
      isNsfw: data.isNsfw.present ? data.isNsfw.value : this.isNsfw,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      lastChecked: data.lastChecked.present
          ? data.lastChecked.value
          : this.lastChecked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubredditEntry(')
          ..write('name: $name, ')
          ..write('isNsfw: $isNsfw, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('lastChecked: $lastChecked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, isNsfw, iconUrl, lastChecked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubredditEntry &&
          other.name == this.name &&
          other.isNsfw == this.isNsfw &&
          other.iconUrl == this.iconUrl &&
          other.lastChecked == this.lastChecked);
}

class SubredditsTableCompanion extends UpdateCompanion<SubredditEntry> {
  final Value<String> name;
  final Value<bool?> isNsfw;
  final Value<String?> iconUrl;
  final Value<DateTime?> lastChecked;
  final Value<int> rowid;
  const SubredditsTableCompanion({
    this.name = const Value.absent(),
    this.isNsfw = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.lastChecked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubredditsTableCompanion.insert({
    required String name,
    this.isNsfw = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.lastChecked = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SubredditEntry> custom({
    Expression<String>? name,
    Expression<bool>? isNsfw,
    Expression<String>? iconUrl,
    Expression<DateTime>? lastChecked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (isNsfw != null) 'is_nsfw': isNsfw,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (lastChecked != null) 'last_checked': lastChecked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubredditsTableCompanion copyWith({
    Value<String>? name,
    Value<bool?>? isNsfw,
    Value<String?>? iconUrl,
    Value<DateTime?>? lastChecked,
    Value<int>? rowid,
  }) {
    return SubredditsTableCompanion(
      name: name ?? this.name,
      isNsfw: isNsfw ?? this.isNsfw,
      iconUrl: iconUrl ?? this.iconUrl,
      lastChecked: lastChecked ?? this.lastChecked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isNsfw.present) {
      map['is_nsfw'] = Variable<bool>(isNsfw.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (lastChecked.present) {
      map['last_checked'] = Variable<DateTime>(lastChecked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubredditsTableCompanion(')
          ..write('name: $name, ')
          ..write('isNsfw: $isNsfw, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('lastChecked: $lastChecked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SavedItemsTableTable savedItemsTable = $SavedItemsTableTable(
    this,
  );
  late final $CollectionsTableTable collectionsTable = $CollectionsTableTable(
    this,
  );
  late final $ItemCollectionsTableTable itemCollectionsTable =
      $ItemCollectionsTableTable(this);
  late final $SubredditsTableTable subredditsTable = $SubredditsTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    savedItemsTable,
    collectionsTable,
    itemCollectionsTable,
    subredditsTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_items_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_collections_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collections_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_collections_table', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SavedItemsTableTableCreateCompanionBuilder =
    SavedItemsTableCompanion Function({
      required String id,
      required String permalink,
      required ItemType itemType,
      Value<String?> parentPostId,
      Value<String?> parentPostTitle,
      required String title,
      required String subreddit,
      Value<String?> author,
      Value<String?> body,
      Value<String?> url,
      Value<String?> thumbnailUrl,
      Value<String?> mediaUrl,
      Value<String?> galleryImages,
      Value<String?> galleryPreviewImages,
      Value<MediaType> mediaType,
      Value<int> score,
      Value<int> numComments,
      Value<bool> isNsfw,
      Value<bool> isStarred,
      Value<bool> isArchived,
      Value<String?> userNote,
      Value<String> csvSource,
      Value<int> importOrder,
      Value<DateTime?> createdAtUtc,
      required DateTime savedAtUtc,
      Value<String?> postFlair,
      Value<String> subredditType,
      Value<EnrichmentStatus> enrichmentStatus,
      Value<bool> isArchiveRecovered,
      Value<bool> isArchiveUnavailable,
      Value<int> rowid,
    });
typedef $$SavedItemsTableTableUpdateCompanionBuilder =
    SavedItemsTableCompanion Function({
      Value<String> id,
      Value<String> permalink,
      Value<ItemType> itemType,
      Value<String?> parentPostId,
      Value<String?> parentPostTitle,
      Value<String> title,
      Value<String> subreddit,
      Value<String?> author,
      Value<String?> body,
      Value<String?> url,
      Value<String?> thumbnailUrl,
      Value<String?> mediaUrl,
      Value<String?> galleryImages,
      Value<String?> galleryPreviewImages,
      Value<MediaType> mediaType,
      Value<int> score,
      Value<int> numComments,
      Value<bool> isNsfw,
      Value<bool> isStarred,
      Value<bool> isArchived,
      Value<String?> userNote,
      Value<String> csvSource,
      Value<int> importOrder,
      Value<DateTime?> createdAtUtc,
      Value<DateTime> savedAtUtc,
      Value<String?> postFlair,
      Value<String> subredditType,
      Value<EnrichmentStatus> enrichmentStatus,
      Value<bool> isArchiveRecovered,
      Value<bool> isArchiveUnavailable,
      Value<int> rowid,
    });

final class $$SavedItemsTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $SavedItemsTableTable, SavedItemEntry> {
  $$SavedItemsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $ItemCollectionsTableTable,
    List<ItemCollectionEntry>
  >
  _itemCollectionsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.itemCollectionsTable,
        aliasName: 'saved_items_table__id__item_collections_table__item_id',
      );

  $$ItemCollectionsTableTableProcessedTableManager
  get itemCollectionsTableRefs {
    final manager = $$ItemCollectionsTableTableTableManager(
      $_db,
      $_db.itemCollectionsTable,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _itemCollectionsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SavedItemsTableTable> {
  $$SavedItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permalink => $composableBuilder(
    column: $table.permalink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemType, ItemType, int> get itemType =>
      $composableBuilder(
        column: $table.itemType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get parentPostId => $composableBuilder(
    column: $table.parentPostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentPostTitle => $composableBuilder(
    column: $table.parentPostTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subreddit => $composableBuilder(
    column: $table.subreddit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get galleryImages => $composableBuilder(
    column: $table.galleryImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get galleryPreviewImages => $composableBuilder(
    column: $table.galleryPreviewImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MediaType, MediaType, int> get mediaType =>
      $composableBuilder(
        column: $table.mediaType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numComments => $composableBuilder(
    column: $table.numComments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNsfw => $composableBuilder(
    column: $table.isNsfw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userNote => $composableBuilder(
    column: $table.userNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get csvSource => $composableBuilder(
    column: $table.csvSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importOrder => $composableBuilder(
    column: $table.importOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAtUtc => $composableBuilder(
    column: $table.savedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postFlair => $composableBuilder(
    column: $table.postFlair,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subredditType => $composableBuilder(
    column: $table.subredditType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EnrichmentStatus, EnrichmentStatus, int>
  get enrichmentStatus => $composableBuilder(
    column: $table.enrichmentStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isArchiveRecovered => $composableBuilder(
    column: $table.isArchiveRecovered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchiveUnavailable => $composableBuilder(
    column: $table.isArchiveUnavailable,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemCollectionsTableRefs(
    Expression<bool> Function($$ItemCollectionsTableTableFilterComposer f) f,
  ) {
    final $$ItemCollectionsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemCollectionsTable,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemCollectionsTableTableFilterComposer(
            $db: $db,
            $table: $db.itemCollectionsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedItemsTableTable> {
  $$SavedItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permalink => $composableBuilder(
    column: $table.permalink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentPostId => $composableBuilder(
    column: $table.parentPostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentPostTitle => $composableBuilder(
    column: $table.parentPostTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subreddit => $composableBuilder(
    column: $table.subreddit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get galleryImages => $composableBuilder(
    column: $table.galleryImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get galleryPreviewImages => $composableBuilder(
    column: $table.galleryPreviewImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numComments => $composableBuilder(
    column: $table.numComments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNsfw => $composableBuilder(
    column: $table.isNsfw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userNote => $composableBuilder(
    column: $table.userNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get csvSource => $composableBuilder(
    column: $table.csvSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importOrder => $composableBuilder(
    column: $table.importOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAtUtc => $composableBuilder(
    column: $table.savedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postFlair => $composableBuilder(
    column: $table.postFlair,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subredditType => $composableBuilder(
    column: $table.subredditType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enrichmentStatus => $composableBuilder(
    column: $table.enrichmentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchiveRecovered => $composableBuilder(
    column: $table.isArchiveRecovered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchiveUnavailable => $composableBuilder(
    column: $table.isArchiveUnavailable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedItemsTableTable> {
  $$SavedItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get permalink =>
      $composableBuilder(column: $table.permalink, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemType, int> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get parentPostId => $composableBuilder(
    column: $table.parentPostId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentPostTitle => $composableBuilder(
    column: $table.parentPostTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subreddit =>
      $composableBuilder(column: $table.subreddit, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get galleryImages => $composableBuilder(
    column: $table.galleryImages,
    builder: (column) => column,
  );

  GeneratedColumn<String> get galleryPreviewImages => $composableBuilder(
    column: $table.galleryPreviewImages,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MediaType, int> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get numComments => $composableBuilder(
    column: $table.numComments,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isNsfw =>
      $composableBuilder(column: $table.isNsfw, builder: (column) => column);

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userNote =>
      $composableBuilder(column: $table.userNote, builder: (column) => column);

  GeneratedColumn<String> get csvSource =>
      $composableBuilder(column: $table.csvSource, builder: (column) => column);

  GeneratedColumn<int> get importOrder => $composableBuilder(
    column: $table.importOrder,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get savedAtUtc => $composableBuilder(
    column: $table.savedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postFlair =>
      $composableBuilder(column: $table.postFlair, builder: (column) => column);

  GeneratedColumn<String> get subredditType => $composableBuilder(
    column: $table.subredditType,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<EnrichmentStatus, int>
  get enrichmentStatus => $composableBuilder(
    column: $table.enrichmentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchiveRecovered => $composableBuilder(
    column: $table.isArchiveRecovered,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchiveUnavailable => $composableBuilder(
    column: $table.isArchiveUnavailable,
    builder: (column) => column,
  );

  Expression<T> itemCollectionsTableRefs<T extends Object>(
    Expression<T> Function($$ItemCollectionsTableTableAnnotationComposer a) f,
  ) {
    final $$ItemCollectionsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.itemCollectionsTable,
          getReferencedColumn: (t) => t.itemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ItemCollectionsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.itemCollectionsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedItemsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedItemsTableTable,
          SavedItemEntry,
          $$SavedItemsTableTableFilterComposer,
          $$SavedItemsTableTableOrderingComposer,
          $$SavedItemsTableTableAnnotationComposer,
          $$SavedItemsTableTableCreateCompanionBuilder,
          $$SavedItemsTableTableUpdateCompanionBuilder,
          (SavedItemEntry, $$SavedItemsTableTableReferences),
          SavedItemEntry,
          PrefetchHooks Function({bool itemCollectionsTableRefs})
        > {
  $$SavedItemsTableTableTableManager(
    _$AppDatabase db,
    $SavedItemsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedItemsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> permalink = const Value.absent(),
                Value<ItemType> itemType = const Value.absent(),
                Value<String?> parentPostId = const Value.absent(),
                Value<String?> parentPostTitle = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subreddit = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> galleryImages = const Value.absent(),
                Value<String?> galleryPreviewImages = const Value.absent(),
                Value<MediaType> mediaType = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> numComments = const Value.absent(),
                Value<bool> isNsfw = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String?> userNote = const Value.absent(),
                Value<String> csvSource = const Value.absent(),
                Value<int> importOrder = const Value.absent(),
                Value<DateTime?> createdAtUtc = const Value.absent(),
                Value<DateTime> savedAtUtc = const Value.absent(),
                Value<String?> postFlair = const Value.absent(),
                Value<String> subredditType = const Value.absent(),
                Value<EnrichmentStatus> enrichmentStatus = const Value.absent(),
                Value<bool> isArchiveRecovered = const Value.absent(),
                Value<bool> isArchiveUnavailable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedItemsTableCompanion(
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
                galleryImages: galleryImages,
                galleryPreviewImages: galleryPreviewImages,
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
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String permalink,
                required ItemType itemType,
                Value<String?> parentPostId = const Value.absent(),
                Value<String?> parentPostTitle = const Value.absent(),
                required String title,
                required String subreddit,
                Value<String?> author = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> galleryImages = const Value.absent(),
                Value<String?> galleryPreviewImages = const Value.absent(),
                Value<MediaType> mediaType = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> numComments = const Value.absent(),
                Value<bool> isNsfw = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String?> userNote = const Value.absent(),
                Value<String> csvSource = const Value.absent(),
                Value<int> importOrder = const Value.absent(),
                Value<DateTime?> createdAtUtc = const Value.absent(),
                required DateTime savedAtUtc,
                Value<String?> postFlair = const Value.absent(),
                Value<String> subredditType = const Value.absent(),
                Value<EnrichmentStatus> enrichmentStatus = const Value.absent(),
                Value<bool> isArchiveRecovered = const Value.absent(),
                Value<bool> isArchiveUnavailable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedItemsTableCompanion.insert(
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
                galleryImages: galleryImages,
                galleryPreviewImages: galleryPreviewImages,
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
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedItemsTableTable, SavedItemEntry>(table),
                  $$SavedItemsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemCollectionsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (itemCollectionsTableRefs) db.itemCollectionsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemCollectionsTableRefs)
                    await $_getPrefetchedDataByColumns<
                      SavedItemEntry,
                      $SavedItemsTableTable,
                      ItemCollectionEntry,
                      $ItemCollectionsTableTable
                    >(
                      currentTable: table,
                      referencedTable: $$SavedItemsTableTableReferences
                          ._itemCollectionsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedItemsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).itemCollectionsTableRefs,
                      currentColumn: 'id',
                      referencedColumn: 'item_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedItemsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedItemsTableTable,
      SavedItemEntry,
      $$SavedItemsTableTableFilterComposer,
      $$SavedItemsTableTableOrderingComposer,
      $$SavedItemsTableTableAnnotationComposer,
      $$SavedItemsTableTableCreateCompanionBuilder,
      $$SavedItemsTableTableUpdateCompanionBuilder,
      (SavedItemEntry, $$SavedItemsTableTableReferences),
      SavedItemEntry,
      PrefetchHooks Function({bool itemCollectionsTableRefs})
    >;
typedef $$CollectionsTableTableCreateCompanionBuilder =
    CollectionsTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      Value<int> colorValue,
      Value<DateTime?> createdAtUtc,
    });
typedef $$CollectionsTableTableUpdateCompanionBuilder =
    CollectionsTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<int> colorValue,
      Value<DateTime?> createdAtUtc,
    });

final class $$CollectionsTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $CollectionsTableTable, CollectionEntry> {
  $$CollectionsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $ItemCollectionsTableTable,
    List<ItemCollectionEntry>
  >
  _itemCollectionsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.itemCollectionsTable,
        aliasName:
            'collections_table__id__item_collections_table__collection_id',
      );

  $$ItemCollectionsTableTableProcessedTableManager
  get itemCollectionsTableRefs {
    final manager = $$ItemCollectionsTableTableTableManager(
      $_db,
      $_db.itemCollectionsTable,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _itemCollectionsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CollectionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionsTableTable> {
  $$CollectionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemCollectionsTableRefs(
    Expression<bool> Function($$ItemCollectionsTableTableFilterComposer f) f,
  ) {
    final $$ItemCollectionsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemCollectionsTable,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemCollectionsTableTableFilterComposer(
            $db: $db,
            $table: $db.itemCollectionsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionsTableTable> {
  $$CollectionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionsTableTable> {
  $$CollectionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  Expression<T> itemCollectionsTableRefs<T extends Object>(
    Expression<T> Function($$ItemCollectionsTableTableAnnotationComposer a) f,
  ) {
    final $$ItemCollectionsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.itemCollectionsTable,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ItemCollectionsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.itemCollectionsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CollectionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTableTable,
          CollectionEntry,
          $$CollectionsTableTableFilterComposer,
          $$CollectionsTableTableOrderingComposer,
          $$CollectionsTableTableAnnotationComposer,
          $$CollectionsTableTableCreateCompanionBuilder,
          $$CollectionsTableTableUpdateCompanionBuilder,
          (CollectionEntry, $$CollectionsTableTableReferences),
          CollectionEntry,
          PrefetchHooks Function({bool itemCollectionsTableRefs})
        > {
  $$CollectionsTableTableTableManager(
    _$AppDatabase db,
    $CollectionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime?> createdAtUtc = const Value.absent(),
              }) => CollectionsTableCompanion(
                id: id,
                name: name,
                description: description,
                colorValue: colorValue,
                createdAtUtc: createdAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime?> createdAtUtc = const Value.absent(),
              }) => CollectionsTableCompanion.insert(
                id: id,
                name: name,
                description: description,
                colorValue: colorValue,
                createdAtUtc: createdAtUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionsTableTable, CollectionEntry>(table),
                  $$CollectionsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemCollectionsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (itemCollectionsTableRefs) db.itemCollectionsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemCollectionsTableRefs)
                    await $_getPrefetchedDataByColumns<
                      CollectionEntry,
                      $CollectionsTableTable,
                      ItemCollectionEntry,
                      $ItemCollectionsTableTable
                    >(
                      currentTable: table,
                      referencedTable: $$CollectionsTableTableReferences
                          ._itemCollectionsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CollectionsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).itemCollectionsTableRefs,
                      currentColumn: 'id',
                      referencedColumn: 'collection_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CollectionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTableTable,
      CollectionEntry,
      $$CollectionsTableTableFilterComposer,
      $$CollectionsTableTableOrderingComposer,
      $$CollectionsTableTableAnnotationComposer,
      $$CollectionsTableTableCreateCompanionBuilder,
      $$CollectionsTableTableUpdateCompanionBuilder,
      (CollectionEntry, $$CollectionsTableTableReferences),
      CollectionEntry,
      PrefetchHooks Function({bool itemCollectionsTableRefs})
    >;
typedef $$ItemCollectionsTableTableCreateCompanionBuilder =
    ItemCollectionsTableCompanion Function({
      required String itemId,
      required int collectionId,
      Value<int> rowid,
    });
typedef $$ItemCollectionsTableTableUpdateCompanionBuilder =
    ItemCollectionsTableCompanion Function({
      Value<String> itemId,
      Value<int> collectionId,
      Value<int> rowid,
    });

final class $$ItemCollectionsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ItemCollectionsTableTable,
          ItemCollectionEntry
        > {
  $$ItemCollectionsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedItemsTableTable _itemIdTable(_$AppDatabase db) => db
      .savedItemsTable
      .createAlias('item_collections_table__item_id__saved_items_table__id');

  $$SavedItemsTableTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$SavedItemsTableTableTableManager(
      $_db,
      $_db.savedItemsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CollectionsTableTable _collectionIdTable(_$AppDatabase db) =>
      db.collectionsTable.createAlias(
        'item_collections_table__collection_id__collections_table__id',
      );

  $$CollectionsTableTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<int>('collection_id')!;

    final manager = $$CollectionsTableTableTableManager(
      $_db,
      $_db.collectionsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemCollectionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ItemCollectionsTableTable> {
  $$ItemCollectionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedItemsTableTableFilterComposer get itemId {
    final $$SavedItemsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.savedItemsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedItemsTableTableFilterComposer(
            $db: $db,
            $table: $db.savedItemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CollectionsTableTableFilterComposer get collectionId {
    final $$CollectionsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collectionsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableTableFilterComposer(
            $db: $db,
            $table: $db.collectionsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemCollectionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemCollectionsTableTable> {
  $$ItemCollectionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedItemsTableTableOrderingComposer get itemId {
    final $$SavedItemsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.savedItemsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedItemsTableTableOrderingComposer(
            $db: $db,
            $table: $db.savedItemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CollectionsTableTableOrderingComposer get collectionId {
    final $$CollectionsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collectionsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableTableOrderingComposer(
            $db: $db,
            $table: $db.collectionsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemCollectionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemCollectionsTableTable> {
  $$ItemCollectionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SavedItemsTableTableAnnotationComposer get itemId {
    final $$SavedItemsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.savedItemsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedItemsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.savedItemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CollectionsTableTableAnnotationComposer get collectionId {
    final $$CollectionsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collectionsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.collectionsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemCollectionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemCollectionsTableTable,
          ItemCollectionEntry,
          $$ItemCollectionsTableTableFilterComposer,
          $$ItemCollectionsTableTableOrderingComposer,
          $$ItemCollectionsTableTableAnnotationComposer,
          $$ItemCollectionsTableTableCreateCompanionBuilder,
          $$ItemCollectionsTableTableUpdateCompanionBuilder,
          (ItemCollectionEntry, $$ItemCollectionsTableTableReferences),
          ItemCollectionEntry,
          PrefetchHooks Function({bool itemId, bool collectionId})
        > {
  $$ItemCollectionsTableTableTableManager(
    _$AppDatabase db,
    $ItemCollectionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemCollectionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemCollectionsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ItemCollectionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<int> collectionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemCollectionsTableCompanion(
                itemId: itemId,
                collectionId: collectionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required int collectionId,
                Value<int> rowid = const Value.absent(),
              }) => ItemCollectionsTableCompanion.insert(
                itemId: itemId,
                collectionId: collectionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemCollectionsTableTable, ItemCollectionEntry>(
                    table,
                  ),
                  $$ItemCollectionsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false, collectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.itemId,
                        referencedTable: $$ItemCollectionsTableTableReferences
                            ._itemIdTable(db),
                        referencedColumn: $$ItemCollectionsTableTableReferences
                            ._itemIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (collectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.collectionId,
                        referencedTable: $$ItemCollectionsTableTableReferences
                            ._collectionIdTable(db),
                        referencedColumn: $$ItemCollectionsTableTableReferences
                            ._collectionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemCollectionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemCollectionsTableTable,
      ItemCollectionEntry,
      $$ItemCollectionsTableTableFilterComposer,
      $$ItemCollectionsTableTableOrderingComposer,
      $$ItemCollectionsTableTableAnnotationComposer,
      $$ItemCollectionsTableTableCreateCompanionBuilder,
      $$ItemCollectionsTableTableUpdateCompanionBuilder,
      (ItemCollectionEntry, $$ItemCollectionsTableTableReferences),
      ItemCollectionEntry,
      PrefetchHooks Function({bool itemId, bool collectionId})
    >;
typedef $$SubredditsTableTableCreateCompanionBuilder =
    SubredditsTableCompanion Function({
      required String name,
      Value<bool?> isNsfw,
      Value<String?> iconUrl,
      Value<DateTime?> lastChecked,
      Value<int> rowid,
    });
typedef $$SubredditsTableTableUpdateCompanionBuilder =
    SubredditsTableCompanion Function({
      Value<String> name,
      Value<bool?> isNsfw,
      Value<String?> iconUrl,
      Value<DateTime?> lastChecked,
      Value<int> rowid,
    });

class $$SubredditsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SubredditsTableTable> {
  $$SubredditsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNsfw => $composableBuilder(
    column: $table.isNsfw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastChecked => $composableBuilder(
    column: $table.lastChecked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubredditsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SubredditsTableTable> {
  $$SubredditsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNsfw => $composableBuilder(
    column: $table.isNsfw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastChecked => $composableBuilder(
    column: $table.lastChecked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubredditsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubredditsTableTable> {
  $$SubredditsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isNsfw =>
      $composableBuilder(column: $table.isNsfw, builder: (column) => column);

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get lastChecked => $composableBuilder(
    column: $table.lastChecked,
    builder: (column) => column,
  );
}

class $$SubredditsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubredditsTableTable,
          SubredditEntry,
          $$SubredditsTableTableFilterComposer,
          $$SubredditsTableTableOrderingComposer,
          $$SubredditsTableTableAnnotationComposer,
          $$SubredditsTableTableCreateCompanionBuilder,
          $$SubredditsTableTableUpdateCompanionBuilder,
          (
            SubredditEntry,
            BaseReferences<
              _$AppDatabase,
              $SubredditsTableTable,
              SubredditEntry
            >,
          ),
          SubredditEntry,
          PrefetchHooks Function()
        > {
  $$SubredditsTableTableTableManager(
    _$AppDatabase db,
    $SubredditsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubredditsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubredditsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubredditsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<bool?> isNsfw = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<DateTime?> lastChecked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubredditsTableCompanion(
                name: name,
                isNsfw: isNsfw,
                iconUrl: iconUrl,
                lastChecked: lastChecked,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                Value<bool?> isNsfw = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<DateTime?> lastChecked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubredditsTableCompanion.insert(
                name: name,
                isNsfw: isNsfw,
                iconUrl: iconUrl,
                lastChecked: lastChecked,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubredditsTableTable, SubredditEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SubredditsTableTable,
                    SubredditEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubredditsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubredditsTableTable,
      SubredditEntry,
      $$SubredditsTableTableFilterComposer,
      $$SubredditsTableTableOrderingComposer,
      $$SubredditsTableTableAnnotationComposer,
      $$SubredditsTableTableCreateCompanionBuilder,
      $$SubredditsTableTableUpdateCompanionBuilder,
      (
        SubredditEntry,
        BaseReferences<_$AppDatabase, $SubredditsTableTable, SubredditEntry>,
      ),
      SubredditEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SavedItemsTableTableTableManager get savedItemsTable =>
      $$SavedItemsTableTableTableManager(_db, _db.savedItemsTable);
  $$CollectionsTableTableTableManager get collectionsTable =>
      $$CollectionsTableTableTableManager(_db, _db.collectionsTable);
  $$ItemCollectionsTableTableTableManager get itemCollectionsTable =>
      $$ItemCollectionsTableTableTableManager(_db, _db.itemCollectionsTable);
  $$SubredditsTableTableTableManager get subredditsTable =>
      $$SubredditsTableTableTableManager(_db, _db.subredditsTable);
}
