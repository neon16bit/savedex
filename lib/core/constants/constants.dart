import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Savedex';
  static const String defaultOauthScopes =
      'account creddits edit flair history identity livemanage modconfig modcontributors modflair modlog modmail modothers modposts modwiki modself mysubreddits privatemessages read report save submit subscribe vote wikiedit wikiread';

  static const String redditBaseUrl = 'https://www.reddit.com';
  static const String redditOauthUrl = 'https://oauth.reddit.com';
  static const String redditAppScheme = 'reddit://';

  static const Duration anonymousRequestDelay = Duration(milliseconds: 1200);
  static const Duration oauthRequestDelay = Duration(milliseconds: 250);
}

enum ItemType { post, comment }

enum MediaType { text, image, video, gallery, link, comment, gif }

enum EnrichmentStatus { slugOnly, pending, enriched, failed }

enum SortOption {
  savedOrderDesc('Saved (Newest first)'),
  savedOrderAsc('Saved (Oldest first)'),
  createdDateDesc('Post Date (Newest)'),
  createdDateAsc('Post Date (Oldest)'),
  scoreDesc('Score (Highest)'),
  scoreAsc('Score (Lowest)'),
  subredditAsc('Subreddit (A-Z)'),
  subredditDesc('Subreddit (Z-A)'),
  authorAsc('Author (A-Z)'),
  authorDesc('Author (Z-A)'),
  titleAsc('Title (A-Z)'),
  commentsDesc('Comments (Most)');

  final String label;
  const SortOption(this.label);
}

enum FeedLayoutMode {
  card('Cards', Icons.view_agenda_outlined),
  compact('Compact', Icons.view_headline_rounded),
  gallery('Gallery', Icons.grid_view_rounded);

  final String label;
  final IconData icon;
  const FeedLayoutMode(this.label, this.icon);
}
