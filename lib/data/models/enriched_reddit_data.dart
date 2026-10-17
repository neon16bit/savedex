import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/database.dart';

typedef GalleryMedia = ({List<String> images, List<String> previews});

class EnrichedRedditData {
  final String id;
  final String? title;
  final String? parentPostTitle;
  final String? parentPostId;
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
  final DateTime? createdAtUtc;
  final String? postFlair;
  final String subredditType;
  final bool isSuccess;
  final bool isRateLimited;
  final String? errorMessage;

  const EnrichedRedditData({
    required this.id,
    this.title,
    this.parentPostTitle,
    this.parentPostId,
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
    this.createdAtUtc,
    this.postFlair,
    this.subredditType = 'public',
    this.isSuccess = true,
    this.isRateLimited = false,
    this.errorMessage,
  });

  String? get galleryImagesJson =>
      galleryImages.isEmpty ? null : jsonEncode(galleryImages);
  String? get galleryPreviewImagesJson =>
      galleryPreviewImages.isEmpty ? null : jsonEncode(galleryPreviewImages);

  factory EnrichedRedditData.failure(
    String id,
    String errorMessage, {
    bool isRateLimited = false,
  }) {
    return EnrichedRedditData(
      id: id,
      isSuccess: false,
      isRateLimited: isRateLimited,
      errorMessage: errorMessage,
    );
  }

  SavedItemsTableCompanion toCompanion({
    required String permalink,
    required ItemType itemType,
    required String subreddit,
    required int importOrder,
    required DateTime savedAtUtc,
    String csvSource = 'reddit_api',
    EnrichmentStatus status = EnrichmentStatus.enriched,
  }) {
    return SavedItemsTableCompanion(
      id: Value(id),
      permalink: Value(permalink),
      itemType: Value(itemType),
      parentPostId: Value(parentPostId),
      parentPostTitle: Value(parentPostTitle),
      title: Value(
        title ?? (itemType == ItemType.comment ? 'Comment' : 'Untitled Post'),
      ),
      subreddit: Value(subreddit),
      author: Value(author),
      body: Value(body),
      url: Value(url),
      thumbnailUrl: Value(thumbnailUrl),
      mediaUrl: Value(mediaUrl),
      galleryImages: Value(galleryImagesJson),
      galleryPreviewImages: Value(galleryPreviewImagesJson),
      mediaType: Value(mediaType),
      score: Value(score),
      numComments: Value(numComments),
      isNsfw: Value(isNsfw),
      csvSource: Value(csvSource),
      importOrder: Value(importOrder),
      createdAtUtc: Value(createdAtUtc),
      savedAtUtc: Value(savedAtUtc),
      postFlair: Value(postFlair),
      subredditType: Value(subredditType),
      enrichmentStatus: Value(status),
    );
  }
}

GalleryMedia extractGalleryMedia(Map<String, dynamic> data) {
  final metadata = data['media_metadata'];
  if (metadata is! Map) {
    return (images: const [], previews: const []);
  }

  final orderedIds = <String>[];
  final galleryData = data['gallery_data'];
  if (galleryData is Map && galleryData['items'] is List) {
    for (final item in galleryData['items'] as List) {
      if (item is Map && item['media_id'] is String) {
        orderedIds.add(item['media_id'] as String);
      }
    }
  }
  if (orderedIds.isEmpty) {
    orderedIds.addAll(metadata.keys.whereType<String>());
  }
  final images = <String>[];
  final previews = <String>[];

  for (final id in orderedIds) {
    final entry = metadata[id];
    if (entry is! Map) continue;

    final source = entry['s'];
    final rawUrl = source is Map
        ? ((source['mp4'] ?? source['gif'] ?? source['u']) as String?)
        : null;
    if (rawUrl is! String || !rawUrl.startsWith('http')) {
      continue;
    }
    final normalizedImageUrl = rawUrl.replaceAll('&amp;', '&');
    images.add(normalizedImageUrl);

    final resolutions = entry['p'];
    String? previewUrl;
    if (resolutions is List) {
      Map? selectedPreview;
      for (final resolution in resolutions) {
        if (resolution is! Map) continue;
        final resUrl =
            (resolution['u'] ?? resolution['gif'] ?? resolution['mp4'])
                as String?;
        if (resUrl is! String) continue;

        selectedPreview = resolution;
        final width = resolution['x'];
        if (width is num && width >= 800) break;
      }
      final rawPreviewUrl =
          (selectedPreview?['u'] ??
                  selectedPreview?['gif'] ??
                  selectedPreview?['mp4'])
              as String?;
      if (rawPreviewUrl != null && rawPreviewUrl.startsWith('http')) {
        previewUrl = rawPreviewUrl.replaceAll('&amp;', '&');
      }
    }

    previews.add(previewUrl ?? normalizedImageUrl);
  }

  return (images: images, previews: previews);
}
