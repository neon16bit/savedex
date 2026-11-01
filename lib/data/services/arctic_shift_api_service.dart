import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/models/enriched_reddit_data.dart';
import 'package:savedex/data/models/saved_item_model.dart';

class ArcticShiftApiService {
  static const _baseUrl = 'https://arctic-shift.photon-reddit.com';
  static const _maxIdsPerRequest = 1;
  static const _maxAttempts = 3;
  static const _defaultRetryDelay = Duration(seconds: 2);

  http.Client _client;
  final http.Client Function()? _clientFactory;
  final String _userAgent;

  ArcticShiftApiService({
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
        EnrichedRedditData.notFound(id, 'Item was not found in the archive');
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
      '[ArcticShiftApi] Fetching metadata for ${cleanIds.length} ${itemType.name}(s): ${cleanIds.join(', ')}',
    );
    for (var start = 0; start < cleanIds.length; start += _maxIdsPerRequest) {
      if (isCancelled?.call() == true) {
        debugPrint('[ArcticShiftApi] Cancelled before batch start');
        break;
      }
      if (start > 0) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      if (isCancelled?.call() == true) {
        debugPrint('[ArcticShiftApi] Cancelled during delay');
        break;
      }
      final end = (start + _maxIdsPerRequest).clamp(0, cleanIds.length);
      final batchClean = cleanIds.sublist(start, end);

      void markBatchFailure(
        String message, {
        bool isRateLimited = false,
        bool isNotFound = false,
      }) {
        for (final clean in batchClean) {
          final rawList = rawIdsByClean[clean] ?? [clean];
          for (final rawId in rawList) {
            results[rawId] = EnrichedRedditData.failure(
              rawId,
              message,
              isRateLimited: isRateLimited,
              isNotFound: isNotFound,
            );
          }
        }
      }

      final uri = Uri.parse(
        '$_baseUrl/api/${itemType == ItemType.post ? 'posts' : 'comments'}/ids',
      ).replace(queryParameters: {'ids': batchClean.join(',')});
      debugPrint('[ArcticShiftApi] Requesting URL: $uri');

      final fetchResult = await _getWithRetry(uri, isCancelled: isCancelled);

      if (isCancelled?.call() == true) {
        debugPrint('[ArcticShiftApi] Cancelled after HTTP response');
        break;
      }

      final response = fetchResult.response;
      if (response == null) {
        debugPrint(
          '[ArcticShiftApi] ERROR: No successful response (rate-limited: ${fetchResult.isRateLimited}, error: ${fetchResult.error}) for batch: ${batchClean.join(', ')}',
        );
        markBatchFailure(
          fetchResult.error ?? 'Archive lookup failed',
          isRateLimited: fetchResult.isRateLimited,
          isNotFound: false,
        );
        continue;
      }

      debugPrint(
        '[ArcticShiftApi] HTTP ${response.statusCode} (length: ${response.body.length} bytes)',
      );

      try {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? decoded['data'] : null;
        if (data is! List) {
          debugPrint(
            '[ArcticShiftApi] ERROR: Unexpected JSON format: $decoded',
          );
          markBatchFailure('Invalid archive response');
          continue;
        }

        debugPrint(
          '[ArcticShiftApi] Received ${data.length} record(s) from Arctic Shift',
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
            '[ArcticShiftApi]   -> [OK] ID: $clean | title: "${parsed.title}" | author: "${parsed.author}" | mediaType: ${parsed.mediaType.name} | media: "${parsed.mediaUrl}"',
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
              '[ArcticShiftApi]   -> [NOT FOUND] ID: $clean was not returned by archive',
            );
            final rawList = rawIdsByClean[clean] ?? [clean];
            for (final rawId in rawList) {
              results.putIfAbsent(
                rawId,
                () => EnrichedRedditData.notFound(
                  rawId,
                  'Item was not found in the archive',
                ),
              );
            }
          }
        }
      } catch (error) {
        debugPrint('[ArcticShiftApi] ERROR: JSON parsing exception: $error');
        markBatchFailure('Invalid archive response: $error');
      }
    }
    return results;
  }

  Future<({http.Response? response, bool isRateLimited, String? error})>
  _getWithRetry(Uri uri, {bool Function()? isCancelled}) async {
    int? lastStatusCode;
    String? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (isCancelled?.call() == true) {
        return (response: null, isRateLimited: false, error: 'Cancelled');
      }
      lastStatusCode = null;
      try {
        final stopwatch = Stopwatch()..start();
        final response = await _client
            .get(uri, headers: {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 35));
        stopwatch.stop();
        lastStatusCode = response.statusCode;
        debugPrint(
          '[ArcticShiftApi] Attempt $attempt finished in ${stopwatch.elapsedMilliseconds}ms -> HTTP ${response.statusCode}',
        );
        if (isCancelled?.call() == true) {
          return (response: null, isRateLimited: false, error: 'Cancelled');
        }
        if (response.statusCode == 200) {
          return (response: response, isRateLimited: false, error: null);
        }
        if (!_isRetryable(response.statusCode) || attempt == _maxAttempts) {
          final isRateLimited = response.statusCode == 429;
          return (
            response: null,
            isRateLimited: isRateLimited,
            error: isRateLimited
                ? 'Rate limit exceeded (429)'
                : 'HTTP ${response.statusCode}',
          );
        }
        await Future.delayed(_retryDelay(response, attempt));
      } catch (e) {
        lastError = e.toString();
        debugPrint(
          '[ArcticShiftApi] Attempt $attempt failed with exception: $e',
        );
        if (isCancelled?.call() == true || attempt == _maxAttempts) {
          return (
            response: null,
            isRateLimited: lastStatusCode == 429,
            error: lastError,
          );
        }
        await Future.delayed(_defaultRetryDelay * attempt);
      }
    }
    return (
      response: null,
      isRateLimited: lastStatusCode == 429,
      error: lastError ?? 'Lookup failed after $_maxAttempts attempts',
    );
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
        : Duration(seconds: retryAfter.clamp(1, 60));
  }

  EnrichedRedditData _parsePost(Map<String, dynamic> data, String id) {
    final crosspostList = data['crosspost_parent_list'];
    final parentData =
        (crosspostList is List &&
            crosspostList.isNotEmpty &&
            crosspostList.first is Map)
        ? Map<String, dynamic>.from(crosspostList.first as Map)
        : null;

    Map<String, dynamic>? rootParentData = parentData;
    while (rootParentData != null &&
        rootParentData['crosspost_parent_list'] is List &&
        (rootParentData['crosspost_parent_list'] as List).isNotEmpty &&
        (rootParentData['crosspost_parent_list'] as List).first is Map) {
      rootParentData = Map<String, dynamic>.from(
        (rootParentData['crosspost_parent_list'] as List).first as Map,
      );
    }

    final parentPostId =
        (parentData?['id'] as String?) ??
        ((data['crosspost_parent'] as String?)?.replaceFirst('t3_', ''));

    final sourceSub =
        (parentData?['subreddit'] as String?) ??
        (rootParentData?['subreddit'] as String?);
    final rawParentTitle =
        (parentData?['title'] as String?) ??
        (rootParentData?['title'] as String?);
    final formattedSub = (sourceSub != null && sourceSub.trim().isNotEmpty)
        ? (sourceSub.startsWith('u_') || sourceSub.startsWith('u/')
              ? 'u/${sourceSub.replaceFirst(RegExp(r'^u[/_]'), '')}'
              : 'r/$sourceSub')
        : null;
    final parentPostTitle =
        (formattedSub != null &&
            rawParentTitle != null &&
            rawParentTitle.trim().isNotEmpty)
        ? '$formattedSub${AppConstants.crosspostDelimiter}${rawParentTitle.trim()}'
        : (rawParentTitle?.trim() ?? formattedSub);

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
        : rawParentTitle;

    final author = data['author'] as String?;

    final rawSelftext = data['selftext'] as String?;
    final parentSelftext =
        (parentData?['selftext'] as String?) ??
        (rootParentData?['selftext'] as String?);
    final selftext = (rawSelftext != null && rawSelftext.trim().isNotEmpty)
        ? rawSelftext
        : ((parentSelftext != null && parentSelftext.trim().isNotEmpty)
              ? parentSelftext
              : rawSelftext);

    bool isRedditThreadUrl(String? u) {
      if (u == null || u.isEmpty) return false;
      final l = u.toLowerCase();
      return l.contains('reddit.com/r/') || l.contains('/comments/');
    }

    final rawUrl = data['url'] as String?;
    final parentUrl =
        (parentData?['url'] as String?) ?? (rootParentData?['url'] as String?);
    final effectiveUrl = (rawUrl != null && !isRedditThreadUrl(rawUrl))
        ? rawUrl
        : (parentUrl != null && parentUrl.isNotEmpty ? parentUrl : rawUrl);

    final isVideo =
        (data['is_video'] == true) ||
        (parentData?['is_video'] == true) ||
        (rootParentData?['is_video'] == true) ||
        (parentData?['media'] is Map &&
            (parentData!['media'] as Map)['reddit_video'] != null) ||
        (parentData?['secure_media'] is Map &&
            (parentData!['secure_media'] as Map)['reddit_video'] != null) ||
        (rootParentData?['media'] is Map &&
            (rootParentData!['media'] as Map)['reddit_video'] != null) ||
        (rootParentData?['secure_media'] is Map &&
            (rootParentData!['secure_media'] as Map)['reddit_video'] != null);

    final score = data['score'] as int? ?? 0;
    final numComments = data['num_comments'] as int? ?? 0;
    final isNsfw =
        (data['over_18'] as bool? ?? false) ||
        (parentData?['over_18'] as bool? ?? false) ||
        (rootParentData?['over_18'] as bool? ?? false);

    final rawFlair =
        (data['link_flair_text'] as String?) ??
        (parentData?['link_flair_text'] as String?);
    final postFlair = (rawFlair != null && rawFlair.trim().isNotEmpty)
        ? rawFlair.trim()
        : null;
    final subredditType = (data['subreddit_type'] as String?) ?? 'public';

    String? thumbnailUrl;
    String? mediaUrl;
    MediaType mediaType = MediaType.text;

    final rawThumbnail = data['thumbnail'] as String?;
    final parentThumbnail =
        (parentData?['thumbnail'] as String?) ??
        (rootParentData?['thumbnail'] as String?);
    if (rawThumbnail != null && rawThumbnail.startsWith('http')) {
      thumbnailUrl = rawThumbnail;
    } else if (parentThumbnail != null && parentThumbnail.startsWith('http')) {
      thumbnailUrl = parentThumbnail;
    }

    final isGifFlag =
        data['is_gif'] == true ||
        parentData?['is_gif'] == true ||
        rootParentData?['is_gif'] == true;

    final parentPreview = (parentData?['preview'] is Map)
        ? parentData!['preview'] as Map
        : (rootParentData?['preview'] is Map)
        ? rootParentData!['preview'] as Map
        : null;
    final dataPreview = data['preview'];
    final preview =
        (dataPreview is Map &&
            dataPreview['images'] is List &&
            (dataPreview['images'] as List).isNotEmpty)
        ? dataPreview
        : parentPreview;

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
        mediaType = isGifFlag ? MediaType.gif : MediaType.image;
      }
    }

    var galleryMedia = extractGalleryMedia(data);
    if (galleryMedia.images.isEmpty && parentData != null) {
      galleryMedia = extractGalleryMedia(parentData);
    }
    if (galleryMedia.images.isEmpty &&
        rootParentData != null &&
        rootParentData != parentData) {
      galleryMedia = extractGalleryMedia(rootParentData);
    }
    final galleryImages = galleryMedia.images;
    final galleryPreviewImages = galleryMedia.previews;
    if (galleryImages.isNotEmpty) {
      mediaType = MediaType.gallery;
      mediaUrl ??= galleryImages.first;
      thumbnailUrl ??= galleryPreviewImages.isNotEmpty
          ? galleryPreviewImages.first
          : galleryImages.first;
    }

    if (galleryImages.isNotEmpty) {
    } else if (isVideo) {
      mediaType = isGifFlag ? MediaType.gif : MediaType.video;
      final media =
          data['media'] ??
          data['secure_media'] ??
          parentData?['media'] ??
          parentData?['secure_media'] ??
          rootParentData?['media'] ??
          rootParentData?['secure_media'];
      if (media is Map && media['reddit_video'] != null) {
        final redditVideo = media['reddit_video'];
        if (redditVideo is Map) {
          mediaUrl =
              (redditVideo['hls_url'] ?? redditVideo['fallback_url'])
                  as String?;
          if (redditVideo['is_gif'] == true || isGifFlag) {
            mediaType = MediaType.gif;
          }
        }
      }
    } else if (effectiveUrl != null) {
      final lowerUrl = effectiveUrl.toLowerCase();
      if (lowerUrl.contains('redgifs.com') ||
          lowerUrl.endsWith('.mp4') ||
          lowerUrl.contains('v.redd.it')) {
        mediaType = MediaType.video;
        if (mediaUrl == null ||
            (!SavedItem.isVideoUrl(mediaUrl) &&
                !SavedItem.isGifUrl(mediaUrl))) {
          mediaUrl = effectiveUrl;
        }
      } else if (lowerUrl.endsWith('.gif') ||
          lowerUrl.endsWith('.gifv') ||
          isGifFlag) {
        mediaType = MediaType.gif;
        mediaUrl ??= effectiveUrl;
        thumbnailUrl ??= effectiveUrl;
      } else if (lowerUrl.endsWith('.jpg') ||
          lowerUrl.endsWith('.jpeg') ||
          lowerUrl.endsWith('.png') ||
          lowerUrl.endsWith('.webp')) {
        mediaType = MediaType.image;
        mediaUrl ??= effectiveUrl;
        thumbnailUrl ??= effectiveUrl;
      } else if (effectiveUrl.contains('reddit.com/gallery')) {
        mediaType = MediaType.gallery;
      } else if (!effectiveUrl.contains('reddit.com/r/')) {
        mediaType = MediaType.link;
      }
    }

    return EnrichedRedditData(
      id: id,
      title: title,
      parentPostTitle: parentPostTitle,
      parentPostId: parentPostId,
      author: author,
      body: (selftext != null && selftext.trim().isNotEmpty) ? selftext : null,
      url: effectiveUrl,
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
    final rawLinkId = data['link_id'] as String?;
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
    );
  }
}
