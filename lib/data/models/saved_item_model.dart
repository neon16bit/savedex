import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  final List<String> galleryImages;
  final List<String> galleryPreviewImages;
  final MediaType mediaType;
  final int score;
  final int numComments;
  final bool isNsfw;
  final bool isStarred;
  final bool isArchived;
  final bool isArchiveRecovered;
  final bool isArchiveUnavailable;
  final String? userNote;
  final String csvSource;
  final int importOrder;
  final DateTime? createdAtUtc;
  final DateTime savedAtUtc;
  final String? postFlair;
  final String subredditType;
  final EnrichmentStatus enrichmentStatus;
  final List<Collection> collections;

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
    this.galleryImages = const [],
    this.galleryPreviewImages = const [],
    this.mediaType = MediaType.text,
    this.score = 0,
    this.numComments = 0,
    this.isNsfw = false,
    this.isStarred = false,
    this.isArchived = false,
    this.isArchiveRecovered = false,
    this.isArchiveUnavailable = false,
    this.userNote,
    this.csvSource = 'saved_posts.csv',
    required this.importOrder,
    this.createdAtUtc,
    required this.savedAtUtc,
    this.postFlair,
    this.subredditType = 'public',
    this.enrichmentStatus = EnrichmentStatus.slugOnly,
    this.collections = const [],
  });

  bool get isComment => itemType == ItemType.comment;
  bool get isPost => itemType == ItemType.post;

  bool get isCrosspost =>
      isPost && parentPostTitle != null && parentPostTitle!.trim().isNotEmpty;

  static const String crosspostDelimiter = AppConstants.crosspostDelimiter;

  String? get crosspostSubreddit {
    if (!isCrosspost) return null;
    final title = parentPostTitle!;
    final sep = title.indexOf(crosspostDelimiter);
    if (sep != -1) {
      return title.substring(0, sep).trim();
    }
    return null;
  }

  String? get originalPostTitle {
    if (!isCrosspost) return null;
    final title = parentPostTitle!;
    final sep = title.indexOf(crosspostDelimiter);
    if (sep != -1) {
      return title.substring(sep + 1).trim();
    }
    return title.trim();
  }

  bool get hasDifferentOriginalTitle {
    if (!isCrosspost) return false;
    final orig = originalPostTitle;
    if (orig == null) return false;
    return title.trim().toLowerCase() != orig.toLowerCase();
  }

  String? get originalPostPermalink {
    if (!isCrosspost) return null;
    if (parentPostId == null || parentPostId!.trim().isEmpty) return null;
    final cleanId = parentPostId!.trim().replaceFirst('t3_', '');
    if (crosspostSubreddit != null) {
      return 'https://www.reddit.com/$crosspostSubreddit/comments/$cleanId';
    }
    return 'https://www.reddit.com/comments/$cleanId';
  }

  bool get canAttemptArchiveRecovery =>
      !isArchiveRecovered &&
      !isArchiveUnavailable &&
      (enrichmentStatus == EnrichmentStatus.failed || hasRemovedContent);

  bool get hasRemovedContent =>
      isRemovedMarker(author) ||
      isRemovedMarker(body) ||
      isRemovedMarker(title);

  static bool isRemovedMarker(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized == '[deleted]' ||
        normalized == '[removed]' ||
        normalized == 'deleted' ||
        normalized == 'removed' ||
        normalized == 'removed by reddit' ||
        normalized == 'removed by moderator') {
      return true;
    }
    if (normalized.startsWith('removed by reddit') ||
        normalized.startsWith('removed by moderator')) {
      return true;
    }
    if (normalized.startsWith('[') && normalized.endsWith(']')) {
      final inner = normalized.substring(1, normalized.length - 1).trim();
      return inner.startsWith('removed by') ||
          inner.startsWith('deleted by') ||
          inner == 'removed' ||
          inner == 'deleted';
    }
    return false;
  }

  bool get isUserPost =>
      subredditType == 'user' ||
      subreddit.startsWith('u_') ||
      subreddit.startsWith('u/');

  static String formatSubreddit(String subreddit, {String? subredditType}) {
    if (subredditType == 'user' ||
        subreddit.startsWith('u_') ||
        subreddit.startsWith('u/')) {
      final clean = (subreddit.startsWith('u_') || subreddit.startsWith('u/'))
          ? subreddit.substring(2)
          : subreddit;
      return 'u/$clean';
    }
    return 'r/$subreddit';
  }

  static bool isUserSubreddit(String subreddit, {String? subredditType}) {
    return subredditType == 'user' ||
        subreddit.startsWith('u_') ||
        subreddit.startsWith('u/');
  }

  String get displaySubreddit =>
      formatSubreddit(subreddit, subredditType: subredditType);

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
      mediaType == MediaType.gif ||
      mediaType == MediaType.gallery;

  static bool isRedGifs(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.split('?').first.toLowerCase();
    return clean.contains('redgifs.com');
  }

  static bool isGifUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    if (isRedGifs(url) || url.toLowerCase().contains('v.redd.it')) {
      return false;
    }
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.gif') || clean.endsWith('.gifv');
  }

  static bool isVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    if (isRedGifs(url)) return true;
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
    if (isGifUrl(url)) return false;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    if (trimmed == 'default' ||
        trimmed == 'self' ||
        trimmed == 'nsfw' ||
        trimmed == 'spoiler' ||
        Uri.tryParse(trimmed)?.path.contains('/gallery/') == true) {
      return false;
    }
    return true;
  }

  bool get isGif {
    final lower = (mediaUrl ?? url ?? '').toLowerCase();
    if (lower.contains('redgifs.com') || lower.contains('v.redd.it')) {
      return false;
    }
    return mediaType == MediaType.gif || isGifUrl(mediaUrl) || isGifUrl(url);
  }

  bool get isVideo {
    final lower = (mediaUrl ?? url ?? '').toLowerCase();
    if (lower.contains('redgifs.com')) {
      return true;
    }
    return mediaType == MediaType.video ||
        (!isGif && (isVideoUrl(mediaUrl) || isVideoUrl(url)));
  }

  bool get isPlayableMedia => isVideo || isGif;

  String? get playMediaUrl {
    if (isPlayableMedia) {
      if (isRedGifs(url)) {
        return url;
      }
      if (mediaUrl != null && (isVideoUrl(mediaUrl) || isGifUrl(mediaUrl))) {
        return mediaUrl;
      }
      return url ?? mediaUrl;
    }
    return null;
  }

  String? get fallbackPlayMediaUrl {
    if (isRedGifs(url) &&
        mediaUrl != null &&
        mediaUrl != url &&
        (isVideoUrl(mediaUrl) || isGifUrl(mediaUrl))) {
      return mediaUrl;
    }
    return null;
  }

  List<String> get galleryPreviewUrls {
    if (galleryPreviewImages.isNotEmpty) return galleryPreviewImages;
    return galleryImages;
  }

  String? get displayImageUrl {
    if (isVideo || isGif) {
      if (thumbnailUrl != null && !isVideoUrl(thumbnailUrl)) {
        return thumbnailUrl;
      }
      if (mediaUrl != null && !isVideoUrl(mediaUrl)) {
        return mediaUrl;
      }
      return null;
    }

    if (galleryPreviewUrls.isNotEmpty && isImageUrl(galleryPreviewUrls.first)) {
      return galleryPreviewUrls.first;
    }

    if (mediaType == MediaType.gallery) {
      if (galleryImages.isNotEmpty && isImageUrl(galleryImages.first)) {
        return galleryImages.first;
      }
      if (thumbnailUrl != null && isImageUrl(thumbnailUrl)) {
        return thumbnailUrl;
      }
      return null;
    }

    // prefer medium preview thumbnails for feed but avoid stretching thumbs if full media exists
    if (thumbnailUrl != null &&
        isImageUrl(thumbnailUrl) &&
        !thumbnailUrl!.contains('thumbs.redditmedia.com')) {
      return thumbnailUrl;
    }
    if (mediaUrl != null && isImageUrl(mediaUrl)) {
      return mediaUrl;
    }
    if (thumbnailUrl != null && isImageUrl(thumbnailUrl)) {
      return thumbnailUrl;
    }
    return null;
  }

  String? get fullImageUrl {
    if (isVideo) return null;
    if (galleryImages.isNotEmpty && isImageUrl(galleryImages.first)) {
      return galleryImages.first;
    }
    if (mediaUrl != null && (isImageUrl(mediaUrl) || isGifUrl(mediaUrl))) {
      return mediaUrl;
    }
    if (url != null && (isImageUrl(url) || isGifUrl(url))) {
      return url;
    }
    return displayImageUrl;
  }

  bool get hasDisplayImage => displayImageUrl != null;

  String? get galleryImagesJson =>
      galleryImages.isEmpty ? null : jsonEncode(galleryImages);

  String? get galleryPreviewImagesJson =>
      galleryPreviewImages.isEmpty ? null : jsonEncode(galleryPreviewImages);

  static List<String> parseGalleryImagesJson(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

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
    List<String>? galleryImages,
    List<String>? galleryPreviewImages,
    MediaType? mediaType,
    int? score,
    int? numComments,
    bool? isNsfw,
    bool? isStarred,
    bool? isArchived,
    bool? isArchiveRecovered,
    bool? isArchiveUnavailable,
    String? userNote,
    String? csvSource,
    int? importOrder,
    DateTime? createdAtUtc,
    DateTime? savedAtUtc,
    String? postFlair,
    String? subredditType,
    EnrichmentStatus? enrichmentStatus,
    List<Collection>? collections,
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
      galleryImages: galleryImages ?? this.galleryImages,
      galleryPreviewImages: galleryPreviewImages ?? this.galleryPreviewImages,
      mediaType: mediaType ?? this.mediaType,
      score: score ?? this.score,
      numComments: numComments ?? this.numComments,
      isNsfw: isNsfw ?? this.isNsfw,
      isStarred: isStarred ?? this.isStarred,
      isArchived: isArchived ?? this.isArchived,
      isArchiveRecovered: isArchiveRecovered ?? this.isArchiveRecovered,
      isArchiveUnavailable: isArchiveUnavailable ?? this.isArchiveUnavailable,
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
      collections: collections ?? this.collections,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedItem &&
        other.id == id &&
        other.permalink == permalink &&
        other.itemType == itemType &&
        other.parentPostId == parentPostId &&
        other.parentPostTitle == parentPostTitle &&
        other.title == title &&
        other.subreddit == subreddit &&
        other.author == author &&
        other.body == body &&
        other.url == url &&
        other.thumbnailUrl == thumbnailUrl &&
        other.mediaUrl == mediaUrl &&
        listEquals(other.galleryImages, galleryImages) &&
        listEquals(other.galleryPreviewImages, galleryPreviewImages) &&
        other.mediaType == mediaType &&
        other.score == score &&
        other.numComments == numComments &&
        other.isNsfw == isNsfw &&
        other.isStarred == isStarred &&
        other.isArchived == isArchived &&
        other.isArchiveRecovered == isArchiveRecovered &&
        other.isArchiveUnavailable == isArchiveUnavailable &&
        other.userNote == userNote &&
        other.csvSource == csvSource &&
        other.importOrder == importOrder &&
        other.createdAtUtc == createdAtUtc &&
        other.savedAtUtc == savedAtUtc &&
        other.postFlair == postFlair &&
        other.subredditType == subredditType &&
        other.enrichmentStatus == enrichmentStatus &&
        listEquals(other.collections, collections);
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
    Object.hashAll(galleryImages),
    Object.hashAll(galleryPreviewImages),
    mediaType,
    score,
    numComments,
    isNsfw,
    isStarred,
    isArchived,
    isArchiveRecovered,
    isArchiveUnavailable,
    userNote,
    csvSource,
    importOrder,
    createdAtUtc,
    savedAtUtc,
    postFlair,
    subredditType,
    enrichmentStatus,
    Object.hashAll(collections),
  ]);
}

class Collection {
  final int id;
  final String name;
  final String? description;
  final int colorValue;
  final DateTime? createdAtUtc;
  final int itemCount;

  const Collection({
    required this.id,
    required this.name,
    this.description,
    required this.colorValue,
    this.createdAtUtc,
    this.itemCount = 0,
  });

  Collection copyWith({
    int? id,
    String? name,
    String? description,
    int? colorValue,
    DateTime? createdAtUtc,
    int? itemCount,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Collection &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.colorValue == colorValue &&
          other.createdAtUtc == createdAtUtc &&
          other.itemCount == itemCount;

  @override
  int get hashCode =>
      Object.hash(id, name, description, colorValue, createdAtUtc, itemCount);
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
  final Set<int> selectedCollectionIds;
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
    this.selectedCollectionIds = const {},
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
      selectedCollectionIds.isNotEmpty ||
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
    Set<int>? selectedCollectionIds,
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
      selectedCollectionIds:
          selectedCollectionIds ?? this.selectedCollectionIds,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterCriteria &&
        other.searchQuery == searchQuery &&
        setEquals(other.selectedSubreddits, selectedSubreddits) &&
        setEquals(other.selectedAuthors, selectedAuthors) &&
        setEquals(other.selectedFlairs, selectedFlairs) &&
        setEquals(other.selectedMediaTypes, selectedMediaTypes) &&
        other.itemType == itemType &&
        other.enrichmentStatus == enrichmentStatus &&
        other.isNsfw == isNsfw &&
        other.isStarred == isStarred &&
        other.isArchived == isArchived &&
        setEquals(other.selectedCollectionIds, selectedCollectionIds) &&
        other.sortOption == sortOption &&
        other.groupCommentsByPost == groupCommentsByPost &&
        other.dateRangeStart == dateRangeStart &&
        other.dateRangeEnd == dateRangeEnd;
  }

  @override
  int get hashCode => Object.hash(
    searchQuery,
    Object.hashAllUnordered(selectedSubreddits),
    Object.hashAllUnordered(selectedAuthors),
    Object.hashAllUnordered(selectedFlairs),
    Object.hashAllUnordered(selectedMediaTypes),
    itemType,
    enrichmentStatus,
    isNsfw,
    isStarred,
    isArchived,
    Object.hashAllUnordered(selectedCollectionIds),
    sortOption,
    groupCommentsByPost,
    dateRangeStart,
    dateRangeEnd,
  );
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

class FeedCursor {
  final Object sortValue;
  final String id;

  const FeedCursor({required this.sortValue, required this.id});

  @override
  String toString() => 'FeedCursor(sortValue: $sortValue, id: $id)';
}

class PagedRows<T> {
  final List<T> items;
  final FeedCursor? nextCursor;
  final bool hasMore;

  const PagedRows({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}
