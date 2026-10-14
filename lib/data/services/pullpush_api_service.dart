import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/models/enriched_reddit_data.dart';

class PullPushApiService {
  static const _baseUrl = 'https://api.pullpush.io';
  static const _maxIdsPerRequest = 10;
  static const _maxAttempts = 3;
  static const _defaultRetryDelay = Duration(seconds: 1);

  http.Client _client;
  final http.Client Function()? _clientFactory;
  final String _userAgent;

  PullPushApiService({
    http.Client? client,
    http.Client Function()? clientFactory,
    String? userAgent,
  }) : _clientFactory = clientFactory,
       _client = client ?? clientFactory?.call() ?? http.Client(),
       _userAgent = userAgent ?? 'Savedex/1.0';

  void dispose() => _client.close();

  void cancelCurrentRequests() {
    try {
      _client.close();
    } catch (_) {}
    _client = _clientFactory?.call() ?? http.Client();
  }

  static String _cleanId(String id) => id.replaceFirst(RegExp(r'^t[13]_'), '');

  Future<EnrichedRedditData> fetchMetadata({
    required String id,
    required ItemType itemType,
  }) async {
    final records = await fetchMetadataBatch(ids: [id], itemType: itemType);
    return records[id] ??
        EnrichedRedditData.failure(
          id,
          'Item was not found in PullPush archive',
        );
  }

  Future<Map<String, EnrichedRedditData>> fetchMetadataBatch({
    required List<String> ids,
    required ItemType itemType,
    bool Function()? isCancelled,
  }) async {
    final results = <String, EnrichedRedditData>{};
    final rawIdsByClean = <String, List<String>>{};
    for (final rawId in ids) {
      final clean = _cleanId(rawId);
      rawIdsByClean.putIfAbsent(clean, () => []).add(rawId);
    }

    final cleanIds = rawIdsByClean.keys.toList();
    debugPrint(
      '[PullPushApi] Fetching metadata for ${cleanIds.length} ${itemType.name}(s): ${cleanIds.join(', ')}',
    );

    for (var start = 0; start < cleanIds.length; start += _maxIdsPerRequest) {
      if (isCancelled?.call() == true) {
        debugPrint('[PullPushApi] Cancelled before batch start');
        break;
      }
      if (start > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (isCancelled?.call() == true) {
        debugPrint('[PullPushApi] Cancelled during delay');
        break;
      }

      final end = (start + _maxIdsPerRequest).clamp(0, cleanIds.length);
      final batchClean = cleanIds.sublist(start, end);

      void markBatchFailure(String message) {
        for (final clean in batchClean) {
          final rawList = rawIdsByClean[clean] ?? [clean];
          for (final rawId in rawList) {
            results[rawId] = EnrichedRedditData.failure(rawId, message);
          }
        }
      }

      final endpoint = itemType == ItemType.post ? 'submission' : 'comment';
      final uri = Uri.parse('$_baseUrl/reddit/search/$endpoint/')
          .replace(queryParameters: {'ids': batchClean.join(',')});

      debugPrint('[PullPushApi] Requesting URL: $uri');

      final response = await _getWithRetry(uri, isCancelled: isCancelled);

      if (isCancelled?.call() == true) {
        debugPrint('[PullPushApi] Cancelled after HTTP response');
        break;
      }

      if (response == null) {
        debugPrint(
          '[PullPushApi] ERROR: No response (timeout or connection error) for batch: ${batchClean.join(', ')}',
        );
        markBatchFailure('PullPush lookup failed');
        continue;
      }

      debugPrint(
        '[PullPushApi] HTTP ${response.statusCode} (length: ${response.body.length} bytes)',
      );

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          final errorMsg = decoded['error'].toString();
          debugPrint('[PullPushApi] API returned error: $errorMsg');
          markBatchFailure(errorMsg);
          continue;
        }

        final data = decoded is Map ? decoded['data'] : null;
        if (data is! List) {
          debugPrint('[PullPushApi] ERROR: Unexpected JSON format: $decoded');
          markBatchFailure('Invalid PullPush response format');
          continue;
        }

        debugPrint(
          '[PullPushApi] Received ${data.length} record(s) from PullPush',
        );

        final foundCleans = <String>{};
        for (final record in data) {
          if (record is! Map || record['id'] is! String) continue;
          final clean = record['id'] as String;
          foundCleans.add(clean);
          final map = Map<String, dynamic>.from(record);
          final parsed = itemType == ItemType.post
              ? _parsePost(map, clean)
              : _parseComment(map, clean);

          debugPrint(
            '[PullPushApi]   -> [OK] ID: $clean | title: "${parsed.title}" | author: "${parsed.author}" | mediaType: ${parsed.mediaType.name} | media: "${parsed.mediaUrl}"',
          );

          results[clean] = parsed;
          final rawList = rawIdsByClean[clean];
          if (rawList != null) {
            for (final rawId in rawList) {
              results[rawId] = parsed;
            }
          }
        }

        for (final clean in batchClean) {
          if (!foundCleans.contains(clean)) {
            debugPrint(
              '[PullPushApi]   -> [NOT FOUND] ID: $clean was not returned by archive',
            );
            final rawList = rawIdsByClean[clean] ?? [clean];
            for (final rawId in rawList) {
              results.putIfAbsent(
                rawId,
                () => EnrichedRedditData.failure(
                  rawId,
                  'Item was not found in PullPush archive',
                ),
              );
            }
          }
        }
      } catch (error) {
        debugPrint('[PullPushApi] ERROR: JSON parsing exception: $error');
        markBatchFailure('Invalid archive response: $error');
      }
    }

    return results;
  }

  Future<http.Response?> _getWithRetry(
    Uri uri, {
    bool Function()? isCancelled,
  }) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (isCancelled?.call() == true) return null;
      try {
        final stopwatch = Stopwatch()..start();
        final response = await _client
            .get(uri, headers: {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 15));
        stopwatch.stop();
        debugPrint(
          '[PullPushApi] Attempt $attempt finished in ${stopwatch.elapsedMilliseconds}ms -> HTTP ${response.statusCode}',
        );
        if (isCancelled?.call() == true) return null;
        if (!_isRetryable(response.statusCode) || attempt == _maxAttempts) {
          return response.statusCode == 200 ? response : null;
        }
        await Future.delayed(_retryDelay(response, attempt));
      } catch (e) {
        debugPrint('[PullPushApi] Attempt $attempt failed with exception: $e');
        if (isCancelled?.call() == true || attempt == _maxAttempts) return null;
        await Future.delayed(_defaultRetryDelay * attempt);
      }
    }
    return null;
  }

  bool _isRetryable(int statusCode) =>
      statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      statusCode >= 500;

  Duration _retryDelay(http.Response response, int attempt) {
    final retryAfter =
        int.tryParse(response.headers['retry-after'] ?? '') ??
        int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
    return retryAfter == null
        ? _defaultRetryDelay * attempt
        : Duration(seconds: retryAfter.clamp(1, 30));
  }

  EnrichedRedditData _parsePost(Map<String, dynamic> data, String id) {
    final createdUtc = data['created_utc'] as num?;
    final createdAt = createdUtc == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (createdUtc * 1000).toInt(),
            isUtc: true,
          );

    final rawTitle = data['title'] as String?;
    final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : null;
    final author = data['author'] as String?;
    final selftext = data['selftext'] as String?;
    final url = data['url'] as String?;
    final isVideo = data['is_video'] == true;
    final score = data['score'] as int? ?? 0;
    final numComments = data['num_comments'] as int? ?? 0;
    final isNsfw = data['over_18'] as bool? ?? false;

    final rawFlair = data['link_flair_text'] as String?;
    final postFlair = (rawFlair != null && rawFlair.trim().isNotEmpty)
        ? rawFlair.trim()
        : null;
    final subredditType = (data['subreddit_type'] as String?) ?? 'public';

    String? thumbnailUrl;
    String? mediaUrl;
    MediaType mediaType = MediaType.text;

    final rawThumbnail = data['thumbnail'] as String?;
    if (rawThumbnail != null && rawThumbnail.startsWith('http')) {
      thumbnailUrl = rawThumbnail;
    }

    final preview = data['preview'];
    if (preview != null &&
        preview['images'] is List &&
        (preview['images'] as List).isNotEmpty) {
      final image = preview['images'][0];
      final source = image['source'];
      if (source != null && source['url'] is String) {
        mediaUrl = (source['url'] as String).replaceAll('&amp;', '&');
        final resolutions = image['resolutions'];
        if (resolutions is List && resolutions.isNotEmpty) {
          Map<String, dynamic>? selected;
          for (final resolution in resolutions) {
            if (resolution is! Map || resolution['url'] is! String) continue;
            selected = Map<String, dynamic>.from(resolution);
            final width = resolution['width'];
            if (width is num && width >= 640) break;
          }
          thumbnailUrl = selected?['url'] is String
              ? (selected!['url'] as String).replaceAll('&amp;', '&')
              : mediaUrl;
        } else {
          thumbnailUrl = mediaUrl;
        }
        mediaType = MediaType.image;
      }
    }
    final galleryMedia = extractGalleryMedia(data);
    final galleryImages = galleryMedia.images;
    final galleryPreviewImages = galleryMedia.previews;
    if (galleryImages.isNotEmpty) {
      mediaType = MediaType.gallery;
      mediaUrl ??= galleryImages.first;
      thumbnailUrl ??= galleryPreviewImages.isNotEmpty
          ? galleryPreviewImages.first
          : galleryImages.first;
    }

    if (isVideo) {
      mediaType = MediaType.video;
      final media = data['media'] ?? data['secure_media'];
      if (media != null && media['reddit_video'] != null) {
        mediaUrl =
            (media['reddit_video']['hls_url'] ??
                    media['reddit_video']['fallback_url'])
                as String?;
      }
    } else if (url != null) {
      final lowerUrl = url.toLowerCase();
      if (lowerUrl.endsWith('.jpg') ||
          lowerUrl.endsWith('.jpeg') ||
          lowerUrl.endsWith('.png') ||
          lowerUrl.endsWith('.webp') ||
          lowerUrl.endsWith('.gif')) {
        mediaType = MediaType.image;
        mediaUrl ??= url;
        thumbnailUrl ??= url;
      } else if (lowerUrl.endsWith('.mp4') ||
          lowerUrl.contains('v.redd.it') ||
          lowerUrl.contains('gfycat.com') ||
          lowerUrl.contains('redgifs.com')) {
        mediaType = MediaType.video;
        mediaUrl ??= url;
      } else if (url.contains('reddit.com/gallery')) {
        mediaType = MediaType.gallery;
      } else if (!url.contains('reddit.com/r/')) {
        mediaType = MediaType.link;
      }
    }

    return EnrichedRedditData(
      id: id,
      title: title,
      author: author,
      body: selftext,
      url: url,
      thumbnailUrl: thumbnailUrl,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      galleryImages: galleryImages,
      galleryPreviewImages: galleryPreviewImages,
      score: score,
      numComments: numComments,
      isNsfw: isNsfw,
      createdAtUtc: createdAt,
      postFlair: postFlair,
      subredditType: subredditType,
      isSuccess: true,
    );
  }

  EnrichedRedditData _parseComment(Map<String, dynamic> data, String id) {
    final createdUtc = data['created_utc'] as num?;
    final parentTitle = data['link_title'] as String?;
    final rawLinkId = (data['link_id'] ?? data['parent_id']) as String?;
    final cleanLinkId = rawLinkId?.replaceFirst(RegExp(r'^t3_'), '');

    return EnrichedRedditData(
      id: id,
      title: parentTitle == null ? null : 'Comment on "$parentTitle"',
      parentPostTitle: parentTitle,
      parentPostId: cleanLinkId,
      author: data['author'] as String?,
      body: data['body'] as String?,
      mediaType: MediaType.comment,
      score: data['score'] as int? ?? 0,
      createdAtUtc: createdUtc == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (createdUtc * 1000).toInt(),
              isUtc: true,
            ),
      isSuccess: true,
    );
  }
}
