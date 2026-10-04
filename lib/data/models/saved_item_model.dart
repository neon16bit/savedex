import 'package:savedex/core/constants/constants.dart';

class SavedItem {
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
  final List<Tag> tags;

  const SavedItem({
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
    this.mediaType = MediaType.text,
    this.score = 0,
    this.numComments = 0,
    this.isNsfw = false,
    this.isStarred = false,
    this.isArchived = false,
    this.userNote,
    this.csvSource = 'saved_posts.csv',
    required this.importOrder,
    this.createdAtUtc,
    required this.savedAtUtc,
    this.postFlair,
    this.subredditType = 'public',
    this.enrichmentStatus = EnrichmentStatus.slugOnly,
    this.tags = const [],
  });

  bool get isComment => itemType == ItemType.comment;
  bool get isPost => itemType == ItemType.post;

  String get fullPermalink {
    if (permalink.startsWith('http://') || permalink.startsWith('https://')) {
      return permalink;
    }
    final clean = permalink.startsWith('/') ? permalink : '/$permalink';
    return 'https://www.reddit.com$clean';
  }

  bool get hasMedia =>
      thumbnailUrl != null ||
      mediaUrl != null ||
      mediaType == MediaType.image ||
      mediaType == MediaType.video ||
      mediaType == MediaType.gallery;

  static bool isVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.mp4') ||
        clean.endsWith('.m3u8') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.webm') ||
        clean.contains('v.redd.it') ||
        url.contains('DASH_');
  }

  static bool isImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    if (isVideoUrl(url)) return false;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    if (trimmed == 'default' ||
        trimmed == 'self' ||
        trimmed == 'nsfw' ||
        trimmed == 'spoiler') {
      return false;
    }
    return true;
  }

  bool get isVideo =>
      mediaType == MediaType.video || isVideoUrl(mediaUrl) || isVideoUrl(url);

  String? get displayImageUrl {
    if (isVideo) {
      if (thumbnailUrl != null && isImageUrl(thumbnailUrl)) {
        return thumbnailUrl;
      }
      return null;
    }

    if (mediaUrl != null && isImageUrl(mediaUrl)) {
      return mediaUrl;
    }
    if (thumbnailUrl != null && isImageUrl(thumbnailUrl)) {
      return thumbnailUrl;
    }
    return null;
  }

  bool get hasDisplayImage => displayImageUrl != null;

  SavedItem copyWith({
    String? id,
    String? permalink,
    ItemType? itemType,
    String? parentPostId,
    String? parentPostTitle,
    String? title,
    String? subreddit,
    String? author,
    String? body,
    String? url,
    String? thumbnailUrl,
    String? mediaUrl,
    MediaType? mediaType,
    int? score,
    int? numComments,
    bool? isNsfw,
    bool? isStarred,
    bool? isArchived,
    String? userNote,
    String? csvSource,
    int? importOrder,
    DateTime? createdAtUtc,
    DateTime? savedAtUtc,
    String? postFlair,
    String? subredditType,
    EnrichmentStatus? enrichmentStatus,
    List<Tag>? tags,
    bool clearParentPostId = false,
    bool clearParentPostTitle = false,
    bool clearAuthor = false,
    bool clearBody = false,
    bool clearUrl = false,
    bool clearThumbnailUrl = false,
    bool clearMediaUrl = false,
    bool clearUserNote = false,
    bool clearCreatedAtUtc = false,
    bool clearPostFlair = false,
  }) {
    return SavedItem(
      id: id ?? this.id,
      permalink: permalink ?? this.permalink,
      itemType: itemType ?? this.itemType,
      parentPostId: clearParentPostId
          ? null
          : (parentPostId ?? this.parentPostId),
      parentPostTitle: clearParentPostTitle
          ? null
          : (parentPostTitle ?? this.parentPostTitle),
      title: title ?? this.title,
      subreddit: subreddit ?? this.subreddit,
      author: clearAuthor ? null : (author ?? this.author),
      body: clearBody ? null : (body ?? this.body),
      url: clearUrl ? null : (url ?? this.url),
      thumbnailUrl: clearThumbnailUrl
          ? null
          : (thumbnailUrl ?? this.thumbnailUrl),
      mediaUrl: clearMediaUrl ? null : (mediaUrl ?? this.mediaUrl),
      mediaType: mediaType ?? this.mediaType,
      score: score ?? this.score,
      numComments: numComments ?? this.numComments,
      isNsfw: isNsfw ?? this.isNsfw,
      isStarred: isStarred ?? this.isStarred,
      isArchived: isArchived ?? this.isArchived,
      userNote: clearUserNote ? null : (userNote ?? this.userNote),
      csvSource: csvSource ?? this.csvSource,
      importOrder: importOrder ?? this.importOrder,
      createdAtUtc: clearCreatedAtUtc
          ? null
          : (createdAtUtc ?? this.createdAtUtc),
      savedAtUtc: savedAtUtc ?? this.savedAtUtc,
      postFlair: clearPostFlair ? null : (postFlair ?? this.postFlair),
      subredditType: subredditType ?? this.subredditType,
      enrichmentStatus: enrichmentStatus ?? this.enrichmentStatus,
      tags: tags ?? this.tags,
    );
  }
}

class Tag {
  final int id;
  final String name;
  final int colorValue;

  const Tag({required this.id, required this.name, required this.colorValue});
}

class FilterCriteria {
  final String? searchQuery;
  final Set<String> selectedSubreddits;
  final Set<String> selectedAuthors;
  final Set<String> selectedFlairs;
  final Set<MediaType> selectedMediaTypes;
  final ItemType? itemType; // null = all, post, comment
  final EnrichmentStatus? enrichmentStatus;
  final bool? isNsfw;
  final bool? isStarred;
  final bool? isArchived;
  final Set<int> selectedTagIds;
  final SortOption sortOption;
  final bool groupCommentsByPost;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;

  const FilterCriteria({
    this.searchQuery,
    this.selectedSubreddits = const {},
    this.selectedAuthors = const {},
    this.selectedFlairs = const {},
    this.selectedMediaTypes = const {},
    this.itemType,
    this.enrichmentStatus,
    this.isNsfw,
    this.isStarred,
    this.isArchived = false,
    this.selectedTagIds = const {},
    this.sortOption = SortOption.savedOrderDesc,
    this.groupCommentsByPost = false,
    this.dateRangeStart,
    this.dateRangeEnd,
  });

  bool get hasActiveFilters =>
      (searchQuery != null && searchQuery!.trim().isNotEmpty) ||
      selectedSubreddits.isNotEmpty ||
      selectedAuthors.isNotEmpty ||
      selectedFlairs.isNotEmpty ||
      selectedMediaTypes.isNotEmpty ||
      itemType != null ||
      enrichmentStatus != null ||
      isNsfw != null ||
      isStarred != null ||
      selectedTagIds.isNotEmpty ||
      dateRangeStart != null ||
      dateRangeEnd != null;

  FilterCriteria copyWith({
    String? searchQuery,
    Set<String>? selectedSubreddits,
    Set<String>? selectedAuthors,
    Set<String>? selectedFlairs,
    Set<MediaType>? selectedMediaTypes,
    ItemType? itemType,
    EnrichmentStatus? enrichmentStatus,
    bool? isNsfw,
    bool? isStarred,
    bool? isArchived,
    Set<int>? selectedTagIds,
    SortOption? sortOption,
    bool? groupCommentsByPost,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool clearSearchQuery = false,
    bool clearItemType = false,
    bool clearEnrichmentStatus = false,
    bool clearNsfw = false,
    bool clearStarred = false,
    bool clearArchived = false,
    bool clearDateRange = false,
    bool clearDateRangeStart = false,
    bool clearDateRangeEnd = false,
  }) {
    return FilterCriteria(
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      selectedSubreddits: selectedSubreddits ?? this.selectedSubreddits,
      selectedAuthors: selectedAuthors ?? this.selectedAuthors,
      selectedFlairs: selectedFlairs ?? this.selectedFlairs,
      selectedMediaTypes: selectedMediaTypes ?? this.selectedMediaTypes,
      itemType: clearItemType ? null : (itemType ?? this.itemType),
      enrichmentStatus: clearEnrichmentStatus
          ? null
          : (enrichmentStatus ?? this.enrichmentStatus),
      isNsfw: clearNsfw ? null : (isNsfw ?? this.isNsfw),
      isStarred: clearStarred ? null : (isStarred ?? this.isStarred),
      isArchived: clearArchived ? null : (isArchived ?? this.isArchived),
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      sortOption: sortOption ?? this.sortOption,
      groupCommentsByPost: groupCommentsByPost ?? this.groupCommentsByPost,
      dateRangeStart: (clearDateRange || clearDateRangeStart)
          ? null
          : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: (clearDateRange || clearDateRangeEnd)
          ? null
          : (dateRangeEnd ?? this.dateRangeEnd),
    );
  }
}

class ImportSummary {
  final int totalFound;
  final int newItemsImported;
  final int updatedItems;
  final int skippedItems;
  final Duration duration;
  final String? sourceFile;
  final int? totalInDatabase;

  const ImportSummary({
    required this.totalFound,
    required this.newItemsImported,
    required this.updatedItems,
    required this.skippedItems,
    required this.duration,
    this.sourceFile,
    this.totalInDatabase,
  });
}
