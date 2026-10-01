import 'package:savedex/core/constants/constants.dart';

class ParsedRedditUrl {
  final String? subreddit;
  final String? postId;
  final String? commentId;
  final String? slug;
  final String extractedTitle;
  final ItemType itemType;
  final String canonicalPermalink;

  const ParsedRedditUrl({
    required this.subreddit,
    required this.postId,
    required this.commentId,
    required this.slug,
    required this.extractedTitle,
    required this.itemType,
    required this.canonicalPermalink,
  });

  bool get isComment => itemType == ItemType.comment;
}

class PermalinkParser {
  static bool isValidRedditPermalink(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    return trimmed.contains('/comments/') ||
        trimmed.startsWith('/r/') ||
        trimmed.startsWith('r/') ||
        trimmed.startsWith('/u/') ||
        trimmed.startsWith('u/') ||
        trimmed.startsWith('/user/') ||
        trimmed.startsWith('user/') ||
        trimmed.contains('reddit.com') ||
        trimmed.contains('redd.it');
  }

  static ParsedRedditUrl parse(String rawUrl, {String? rawId}) {
    final trimmed = rawUrl.trim();

    Uri? uri;
    try {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        uri = Uri.parse(trimmed);
      } else {
        uri = Uri.parse(
          'https://www.reddit.com${trimmed.startsWith('/') ? '' : '/'}$trimmed',
        );
      }
    } catch (_) {}

    final segments =
        uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];

    String? subreddit;
    String? postId;
    String? slug;
    String? commentId;
    ItemType itemType = ItemType.post;

    // /r/{sub}/comments/{postId}/{slug}/{commentId}?
    // /user/{user}/comments/{postId}/{slug}/{commentId}?
    if (segments.length >= 2 &&
        (segments[0].toLowerCase() == 'r' ||
            segments[0].toLowerCase() == 'u' ||
            segments[0].toLowerCase() == 'user')) {
      final isUserProfile = segments[0].toLowerCase() != 'r';
      subreddit = isUserProfile ? 'u/${segments[1]}' : segments[1];

      if (segments.length >= 4 && segments[2].toLowerCase() == 'comments') {
        postId = segments[3];
        if (segments.length >= 5) {
          slug = segments[4];
        }
        if (segments.length >= 6) {
          commentId = segments[5];
          itemType = ItemType.comment;
        }
      }
    } else if (segments.length >= 2 &&
        segments[0].toLowerCase() == 'comments') {
      // /comments/{postId}/{slug}/{commentId}?
      postId = segments[1];
      if (segments.length >= 3) {
        slug = segments[2];
      }
      if (segments.length >= 4) {
        commentId = segments[3];
        itemType = ItemType.comment;
      }
    } else if (segments.length == 1) {
      // /redd.it/{postId}
      postId = segments[0];
    }

    if (rawId != null) {
      if (rawId.startsWith('t1_')) {
        itemType = ItemType.comment;
        commentId ??= rawId.substring(3);
      } else if (rawId.startsWith('t3_')) {
        itemType = ItemType.post;
        postId ??= rawId.substring(3);
      }
    }

    if (commentId != null && commentId.isNotEmpty) {
      itemType = ItemType.comment;
    }

    final extractedTitle = _slugToTitle(
      slug,
      subreddit: subreddit,
      postId: postId ?? commentId,
      isComment: itemType == ItemType.comment,
    );

    final String canonical;
    if (subreddit != null && postId != null) {
      final safeSlug = slug != null && slug.isNotEmpty ? slug : '_';
      final cleanSub = subreddit.startsWith('u/')
          ? 'user/${subreddit.substring(2)}'
          : 'r/$subreddit';
      if (itemType == ItemType.comment && commentId != null) {
        canonical =
            'https://www.reddit.com/$cleanSub/comments/$postId/$safeSlug/$commentId/';
      } else {
        canonical =
            'https://www.reddit.com/$cleanSub/comments/$postId/$safeSlug/';
      }
    } else {
      canonical = trimmed.startsWith('http')
          ? trimmed
          : 'https://www.reddit.com$trimmed';
    }

    return ParsedRedditUrl(
      subreddit: subreddit,
      postId: postId,
      commentId: commentId,
      slug: slug,
      extractedTitle: extractedTitle,
      itemType: itemType,
      canonicalPermalink: canonical,
    );
  }

  static String _slugToTitle(
    String? slug, {
    String? subreddit,
    String? postId,
    required bool isComment,
  }) {
    if (slug != null && slug.isNotEmpty && slug != '_' && slug != '-') {
      try {
        final decoded = Uri.decodeComponent(slug);
        final words = decoded
            .replaceAll(RegExp(r'[_-]+'), ' ')
            .trim()
            .split(RegExp(r'\s+'));

        if (words.isNotEmpty && words.any((w) => w.isNotEmpty)) {
          final capitalized = words
              .where((w) => w.isNotEmpty)
              .map((w) {
                if (w.length == 1) return w.toUpperCase();
                return '${w[0].toUpperCase()}${w.substring(1)}';
              })
              .join(' ');

          if (capitalized.trim().isNotEmpty) {
            return capitalized;
          }
        }
      } catch (_) {
        return slug;
      }
    }

    final idSuffix = postId != null && postId.isNotEmpty ? ' #$postId' : '';
    if (isComment) {
      return subreddit != null
          ? 'Comment in r/$subreddit$idSuffix'
          : 'Saved Comment$idSuffix';
    }
    return subreddit != null
        ? 'Post in r/$subreddit$idSuffix'
        : 'Saved Post$idSuffix';
  }
}
