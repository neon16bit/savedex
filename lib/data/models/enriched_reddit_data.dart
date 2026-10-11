import 'package:drift/drift.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/database.dart';

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
