import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
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

class RedditApiService {
  final http.Client _client;
  String? _userAgent;
  String? _oauthClientId;
  String? _oauthClientSecret;
  String? _redirectUri;
  String? _refreshToken;
  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _anonymousAccessToken;
  DateTime? _anonymousTokenExpiry;
  String? _lastAuthError;
  void Function(String accessToken, int expiresIn)? onTokenRefreshed;

  RedditApiService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  String get _effectiveUserAgent =>
      (_userAgent != null && _userAgent!.trim().isNotEmpty)
      ? _userAgent!.trim()
      : '';

  void updateCredentials({
    String? userAgent,
    String? clientId,
    String? clientSecret,
    String? redirectUri,
    String? refreshToken,
    String? accessToken,
    DateTime? tokenExpiry,
    bool clearTokens = false,
  }) {
    if (clientId != null && _oauthClientId != clientId) {
      _anonymousAccessToken = null;
      _anonymousTokenExpiry = null;
    }
    if (userAgent != null) _userAgent = userAgent;
    if (clientId != null) _oauthClientId = clientId;
    if (clientSecret != null) _oauthClientSecret = clientSecret;
    if (redirectUri != null) _redirectUri = redirectUri;
    if (clearTokens) {
      _refreshToken = null;
      _accessToken = null;
      _tokenExpiry = null;
    } else {
      if (refreshToken != null) _refreshToken = refreshToken;
      if (accessToken != null) _accessToken = accessToken;
      if (tokenExpiry != null) _tokenExpiry = tokenExpiry;
    }
  }

  String? get redirectUri => _redirectUri;
  String? get userAgent => _userAgent;

  bool get hasUserOAuth =>
      _refreshToken != null &&
      _refreshToken!.isNotEmpty &&
      _oauthClientId != null &&
      _oauthClientId!.isNotEmpty;

  bool get hasOAuthCredentials =>
      _oauthClientId != null &&
      _oauthClientId!.isNotEmpty &&
      _oauthClientSecret != null &&
      _oauthClientSecret!.isNotEmpty;

  static String buildAuthorizationUrl({
    required String clientId,
    required String redirectUri,
    String state = 'savedex_auth',
  }) {
    final scopes = Uri.encodeComponent(AppConstants.defaultOauthScopes);
    return 'https://www.reddit.com/api/v1/authorize.compact?'
        'client_id=${Uri.encodeComponent(clientId)}&'
        'response_type=code&'
        'state=${Uri.encodeComponent(state)}&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'duration=permanent&'
        'scope=$scopes';
  }

  // parses the code parameter from raw auth/redirect url
  static String? parseCodeFromRedirectUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.contains('code=')) {
      try {
        final uri = Uri.parse(trimmed.replaceAll('#_', ''));
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return code;
        }
      } catch (_) {
        final match = RegExp(r'[?&]code=([^&#\s]+)').firstMatch(trimmed);
        if (match != null) {
          return match.group(1);
        }
      }
    }

    return trimmed;
  }

  Future<({String accessToken, String? refreshToken, int expiresIn})?>
  _postTokenRequest({
    required String basicAuth,
    required Map<String, String> body,
    String? userAgent,
    int defaultExpiresIn = 3600,
  }) async {
    try {
      final effectiveUser = (userAgent != null && userAgent.isNotEmpty)
          ? userAgent
          : _effectiveUserAgent;

      final response = await _client
          .post(
            Uri.parse('https://www.reddit.com/api/v1/access_token'),
            headers: {
              'Authorization': 'Basic $basicAuth',
              'User-Agent': effectiveUser,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('access_token')) {
          final accessToken = data['access_token'] as String;
          final refreshToken = data['refresh_token'] as String?;
          final expiresIn = data['expires_in'] as int? ?? defaultExpiresIn;
          _lastAuthError = null;
          return (
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
          );
        } else {
          _lastAuthError = 'Unexpected token response: ${response.body}';
        }
      } else {
        _lastAuthError = 'HTTP ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      _lastAuthError = e.toString();
    }
    return null;
  }

  // exchanges the OAuth authorization code for access and refresh tokens
  Future<({String accessToken, String? refreshToken, int expiresIn})?>
  exchangeAuthorizationCode({
    required String code,
    required String clientId,
    String? clientSecret,
    String? redirectUri,
    String? userAgent,
  }) async {
    final effectiveRedirectUri = (redirectUri != null && redirectUri.isNotEmpty)
        ? redirectUri
        : _redirectUri;
    if (effectiveRedirectUri == null || effectiveRedirectUri.isEmpty) {
      return null;
    }

    final secret = clientSecret ?? '';
    final basicAuth = base64Encode(utf8.encode('$clientId:$secret'));
    return _postTokenRequest(
      basicAuth: basicAuth,
      userAgent: userAgent,
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': effectiveRedirectUri,
      },
    );
  }

  // refreshes user access token using stored refresh token
  Future<({String accessToken, int expiresIn})?> refreshUserToken({
    required String refreshToken,
    required String clientId,
    String? clientSecret,
    String? userAgent,
  }) async {
    final secret = clientSecret ?? '';
    final basicAuth = base64Encode(utf8.encode('$clientId:$secret'));
    final result = await _postTokenRequest(
      basicAuth: basicAuth,
      userAgent: userAgent,
      body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
    );
    if (result != null) {
      return (accessToken: result.accessToken, expiresIn: result.expiresIn);
    }
    return null;
  }

  Future<String?> _getAnonymousToken({bool forceRefresh = false}) async {
    if (_oauthClientId == null || _oauthClientId!.trim().isEmpty) {
      return null;
    }

    if (!forceRefresh &&
        _anonymousAccessToken != null &&
        _anonymousTokenExpiry != null &&
        DateTime.now().isBefore(_anonymousTokenExpiry!)) {
      return _anonymousAccessToken;
    }

    final clientId = _oauthClientId!.trim();
    final basicAuth = base64Encode(utf8.encode('$clientId:'));
    final result = await _postTokenRequest(
      basicAuth: basicAuth,
      body: {
        'grant_type': 'https://oauth.reddit.com/grants/installed_client',
        'device_id': 'DO_NOT_TRACK_THIS_DEVICE',
      },
      defaultExpiresIn: 86400,
    );

    if (result != null) {
      _anonymousAccessToken = result.accessToken;
      _anonymousTokenExpiry = DateTime.now().add(
        Duration(seconds: result.expiresIn - 60),
      );
      return _anonymousAccessToken;
    }
    return null;
  }

  Future<String?> _getValidToken({bool forceRefresh = false}) async {
    if (hasUserOAuth) {
      if (!forceRefresh &&
          _accessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }
      final refreshed = await refreshUserToken(
        refreshToken: _refreshToken!,
        clientId: _oauthClientId!,
        clientSecret: _oauthClientSecret,
        userAgent: _effectiveUserAgent,
      );
      if (refreshed != null) {
        _accessToken = refreshed.accessToken;
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: refreshed.expiresIn - 60),
        );
        onTokenRefreshed?.call(refreshed.accessToken, refreshed.expiresIn);
        return _accessToken;
      }
    }

    if (hasOAuthCredentials) {
      if (!forceRefresh &&
          _accessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }

      final basicAuth = base64Encode(
        utf8.encode('$_oauthClientId:$_oauthClientSecret'),
      );
      final result = await _postTokenRequest(
        basicAuth: basicAuth,
        body: {'grant_type': 'client_credentials'},
      );
      if (result != null) {
        _accessToken = result.accessToken;
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: result.expiresIn - 60),
        );
        return _accessToken;
      }
    }

    if (_oauthClientId != null && _oauthClientId!.trim().isNotEmpty) {
      return _getAnonymousToken(forceRefresh: forceRefresh);
    }

    return null;
  }

  Future<({http.Response? response, String? error, bool isRateLimited})>
  _getWithAuth(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    String? token = await _getValidToken();
    if (token == null) {
      final detail = _lastAuthError != null ? ' ($_lastAuthError)' : '';
      return (
        response: null,
        error: 'Not authenticated with Reddit API $detail',
        isRateLimited: false,
      );
    }

    try {
      var response = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'bearer $token',
              'User-Agent': _effectiveUserAgent,
            },
          )
          .timeout(timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        token = await _getValidToken(forceRefresh: true);
        if (token != null) {
          response = await _client
              .get(
                uri,
                headers: {
                  'Authorization': 'bearer $token',
                  'User-Agent': _effectiveUserAgent,
                },
              )
              .timeout(timeout);
        }
      }

      if (response.statusCode == 429) {
        return (
          response: response,
          error: 'Rate limit exceeded (429)',
          isRateLimited: true,
        );
      }

      return (response: response, error: null, isRateLimited: false);
    } catch (e) {
      return (response: null, error: e.toString(), isRateLimited: false);
    }
  }

  Future<({String? username, String? error})> fetchMyUsername() async {
    final result = await _getWithAuth(
      Uri.parse('https://oauth.reddit.com/api/v1/me?raw_json=1'),
    );

    if (result.response == null) {
      return (username: null, error: result.error);
    }

    final response = result.response!;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['name'] is String) {
        return (username: data['name'] as String, error: null);
      }
    }
    return (
      username: null,
      error: 'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  // fetches a single page of saved items from reddit api
  Future<
    ({
      List<SavedItemsTableCompanion> items,
      String? after,
      bool isRateLimited,
      String? error,
    })
  >
  fetchSavedPage({
    required String username,
    String? after,
    int limit = 100,
    int startImportOrder = 0,
  }) async {
    final queryParams = {
      'raw_json': '1',
      'limit': limit.toString(),
      if (after != null && after.isNotEmpty) 'after': after,
    };

    final requestUri = Uri.parse(
      'https://oauth.reddit.com/user/$username/saved.json',
    ).replace(queryParameters: queryParams);

    final result = await _getWithAuth(
      requestUri,
      timeout: const Duration(seconds: 15),
    );

    if (result.isRateLimited) {
      return (
        items: <SavedItemsTableCompanion>[],
        after: after,
        isRateLimited: true,
        error: result.error,
      );
    }

    if (result.response == null) {
      return (
        items: <SavedItemsTableCompanion>[],
        after: null,
        isRateLimited: false,
        error: result.error,
      );
    }

    final response = result.response!;
    if (response.statusCode != 200) {
      return (
        items: <SavedItemsTableCompanion>[],
        after: null,
        isRateLimited: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! Map) {
        return (
          items: <SavedItemsTableCompanion>[],
          after: null,
          isRateLimited: false,
          error: 'Invalid listing response format',
        );
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final nextAfter = data['after'] as String?;
      final children = data['children'] as List<dynamic>? ?? [];

      final List<SavedItemsTableCompanion> companions = [];
      final now = DateTime.now().toUtc();

      for (int i = 0; i < children.length; i++) {
        final child = children[i];
        if (child is! Map) continue;
        final kind = child['kind'] as String?;
        final childData = child['data'] as Map<String, dynamic>?;
        if (childData == null) continue;

        final id = childData['id'] as String?;
        if (id == null || id.isEmpty) continue;

        final importOrder = startImportOrder + i;
        final rawPermalink = (childData['permalink'] as String?) ?? '';
        final canonicalPermalink = rawPermalink.startsWith('/')
            ? rawPermalink
            : (rawPermalink.isNotEmpty
                  ? '/$rawPermalink'
                  : '/r/${childData['subreddit']}/comments/$id/');
        final subreddit = (childData['subreddit'] as String?) ?? 'reddit';

        if (kind == 't3') {
          final parsed = _parsePostData(childData, id: id);
          companions.add(
            parsed.toCompanion(
              permalink: canonicalPermalink,
              itemType: ItemType.post,
              subreddit: subreddit,
              importOrder: importOrder,
              savedAtUtc: now,
            ),
          );
        } else if (kind == 't1') {
          final linkTitle = childData['link_title'] as String?;
          final linkId = childData['link_id'] as String?;
          final parsed = _parseCommentData(
            childData,
            linkTitle != null
                ? {
                    'title': linkTitle,
                    'link_flair_text': childData['link_flair_text'],
                    'subreddit_type': childData['subreddit_type'],
                  }
                : null,
            id: id,
            parentPostId: linkId,
            parentPostTitle: linkTitle,
          );
          companions.add(
            parsed.toCompanion(
              permalink: canonicalPermalink,
              itemType: ItemType.comment,
              subreddit: subreddit,
              importOrder: importOrder,
              savedAtUtc: now,
            ),
          );
        }
      }

      return (
        items: companions,
        after: (nextAfter != null && nextAfter.isNotEmpty) ? nextAfter : null,
        isRateLimited: false,
        error: null,
      );
    } catch (e) {
      return (
        items: <SavedItemsTableCompanion>[],
        after: null,
        isRateLimited: false,
        error: 'Failed to parse saved items: $e',
      );
    }
  }

  // fetches metadata for a single item
  Future<EnrichedRedditData> fetchMetadata({
    required String id,
    required String permalink,
    required ItemType itemType,
    String? subreddit,
    String? postId,
    String? commentId,
  }) async {
    if (_oauthClientId == null || _oauthClientId!.trim().isEmpty) {
      return EnrichedRedditData.failure(
        id,
        'Reddit Client ID is missing. Please configure your Reddit API credentials in Settings.',
      );
    }

    String cleanPath = Uri.tryParse(permalink)?.path ?? permalink;
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    if (cleanPath.endsWith('/')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }
    if (!cleanPath.endsWith('.json')) {
      cleanPath = '$cleanPath.json';
    }

    final requestUri = Uri.parse(
      '${AppConstants.redditOauthUrl}$cleanPath?raw_json=1',
    );

    final result = await _getWithAuth(requestUri);

    if (result.isRateLimited) {
      return EnrichedRedditData.failure(
        id,
        result.error ?? 'Rate limit exceeded (429)',
        isRateLimited: true,
      );
    }

    if (result.response == null) {
      return EnrichedRedditData.failure(id, result.error ?? 'Request failed');
    }

    final response = result.response!;
    if (response.statusCode == 404 || response.statusCode == 403) {
      return EnrichedRedditData.failure(
        id,
        'Item deleted or inaccessible (${response.statusCode})',
      );
    }

    if (response.statusCode != 200) {
      return EnrichedRedditData.failure(
        id,
        'HTTP error ${response.statusCode}',
      );
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      return _parseRedditResponse(decoded, id: id, itemType: itemType);
    } catch (e) {
      return EnrichedRedditData.failure(id, e.toString());
    }
  }

  EnrichedRedditData _parseRedditResponse(
    dynamic data, {
    required String id,
    required ItemType itemType,
  }) {
    try {
      if (data is List && data.isNotEmpty) {
        final postListing = data[0]['data']['children'] as List?;
        final postData = (postListing != null && postListing.isNotEmpty)
            ? postListing[0]['data']
            : null;

        if (itemType == ItemType.comment && data.length > 1) {
          final commentListing = data[1]['data']['children'] as List?;
          final commentData =
              (commentListing != null && commentListing.isNotEmpty)
              ? commentListing[0]['data']
              : null;

          if (commentData != null) {
            return _parseCommentData(commentData, postData, id: id);
          }
        }

        if (postData != null) {
          return _parsePostData(postData, id: id);
        }
      } else if (data is Map && data.containsKey('data')) {
        final children = data['data']['children'] as List?;
        if (children != null && children.isNotEmpty) {
          final postData = children[0]['data'];
          return _parsePostData(postData, id: id);
        }
      }
    } catch (e) {
      return EnrichedRedditData.failure(id, 'Error parsing response: $e');
    }

    return EnrichedRedditData.failure(id, 'Unknown response structure');
  }

  EnrichedRedditData _parsePostData(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final title = data['title'] as String?;
    final author = data['author'] as String?;
    final score = data['score'] as int? ?? (data['ups'] as int? ?? 0);
    final numComments = data['num_comments'] as int? ?? 0;
    final selftext = data['selftext'] as String?;
    final url = data['url'] as String?;
    final isNsfw = data['over_18'] as bool? ?? false;
    final isVideo = data['is_video'] as bool? ?? false;
    final createdUtcSec = data['created_utc'] as num?;
    final createdAt = createdUtcSec != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (createdUtcSec * 1000).toInt(),
            isUtc: true,
          )
        : null;

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

    // high res preview
    final preview = data['preview'];
    if (preview != null &&
        preview['images'] is List &&
        (preview['images'] as List).isNotEmpty) {
      final source = preview['images'][0]['source'];
      if (source != null && source['url'] is String) {
        mediaUrl = (source['url'] as String).replaceAll('&amp;', '&');
        thumbnailUrl ??= mediaUrl;
        mediaType = MediaType.image;
      }
    }

    // video
    if (isVideo) {
      mediaType = MediaType.video;
      final media = data['media'] ?? data['secure_media'];
      if (media != null && media['reddit_video'] != null) {
        mediaUrl = media['reddit_video']['fallback_url'] as String?;
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
      score: score,
      numComments: numComments,
      isNsfw: isNsfw,
      createdAtUtc: createdAt,
      postFlair: postFlair,
      subredditType: subredditType,
      isSuccess: true,
    );
  }

  EnrichedRedditData _parseCommentData(
    Map<String, dynamic> commentData,
    Map<String, dynamic>? postData, {
    required String id,
    String? parentPostId,
    String? parentPostTitle,
  }) {
    final body = commentData['body'] as String?;
    final author = commentData['author'] as String?;
    final score =
        commentData['score'] as int? ?? (commentData['ups'] as int? ?? 0);
    final createdUtcSec = commentData['created_utc'] as num?;
    final createdAt = createdUtcSec != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (createdUtcSec * 1000).toInt(),
            isUtc: true,
          )
        : null;

    final resolvedParentTitle =
        parentPostTitle ??
        (postData != null ? postData['title'] as String? : null);
    final rawFlair = postData != null
        ? (postData['link_flair_text'] as String?)
        : null;
    final postFlair = (rawFlair != null && rawFlair.trim().isNotEmpty)
        ? rawFlair.trim()
        : null;
    final subredditType =
        (commentData['subreddit_type'] as String?) ??
        (postData?['subreddit_type'] as String?) ??
        'public';

    return EnrichedRedditData(
      id: id,
      title: resolvedParentTitle != null
          ? 'Comment on "$resolvedParentTitle"'
          : null,
      parentPostTitle: resolvedParentTitle,
      parentPostId: parentPostId,
      author: author,
      body: body,
      mediaType: MediaType.comment,
      score: score,
      createdAtUtc: createdAt,
      postFlair: postFlair,
      subredditType: subredditType,
      isSuccess: true,
    );
  }
}
