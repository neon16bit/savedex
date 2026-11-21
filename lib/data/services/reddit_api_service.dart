import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/enriched_reddit_data.dart';
import 'package:savedex/data/models/saved_item_model.dart';

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
  Future<String?>? _inFlightTokenRefresh;
  int _credentialsGeneration = 0;
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
    bool clearUserAgent = false,
    bool clearClientId = false,
    bool clearClientSecret = false,
    bool clearRedirectUri = false,
  }) {
    final nextClientId = clearClientId ? null : (clientId ?? _oauthClientId);
    final nextClientSecret =
        clearClientSecret ? null : (clientSecret ?? _oauthClientSecret);

    final clientIdChanged = nextClientId != _oauthClientId;
    final clientSecretChanged = nextClientSecret != _oauthClientSecret;
    if (clientIdChanged) {
      _anonymousAccessToken = null;
      _anonymousTokenExpiry = null;
    }
    if (clientIdChanged || clientSecretChanged) {
      _accessToken = null;
      _tokenExpiry = null;
    }

    final authChanged =
        clearTokens ||
        clientIdChanged ||
        clientSecretChanged ||
        refreshToken != null ||
        accessToken != null ||
        tokenExpiry != null;
    if (authChanged) {
      _credentialsGeneration++;
      _inFlightTokenRefresh = null;
    }

    _userAgent = clearUserAgent ? null : (userAgent ?? _userAgent);
    _oauthClientId = nextClientId;
    _oauthClientSecret = nextClientSecret;
    _redirectUri = clearRedirectUri ? null : (redirectUri ?? _redirectUri);
    if (clearTokens) {
      _refreshToken = null;
      _accessToken = null;
      _tokenExpiry = null;
      _inFlightTokenRefresh = null;
    } else {
      if (refreshToken != null) _refreshToken = refreshToken;
      if (accessToken != null) _accessToken = accessToken;
      if (tokenExpiry != null) _tokenExpiry = tokenExpiry;
    }
  }

  String? get clientId => _oauthClientId;
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

  static Duration safeTokenLifetime(int expiresIn) {
    if (expiresIn <= 0) return Duration.zero;
    if (expiresIn <= 60) return Duration(seconds: expiresIn);
    return Duration(seconds: (expiresIn - 300).clamp(60, expiresIn));
  }

  static String generateOAuthState() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String buildAuthorizationUrl({
    required String clientId,
    required String redirectUri,
    required String state,
    bool compact = true,
  }) {
    final scopes = Uri.encodeComponent(AppConstants.defaultOauthScopes);
    final endpoint = compact ? 'authorize.compact' : 'authorize';
    return 'https://www.reddit.com/api/v1/$endpoint?'
        'client_id=${Uri.encodeComponent(clientId)}&'
        'response_type=code&'
        'state=${Uri.encodeComponent(state)}&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'duration=permanent&'
        'scope=$scopes';
  }

  Future<({String accessToken, String? refreshToken, int expiresIn})?>
  _postTokenRequest({
    required String basicAuth,
    required Map<String, String> body,
    String? userAgent,
    int defaultExpiresIn = 3600,
    int maxAttempts = 2,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final effectiveUser = (userAgent != null && userAgent.isNotEmpty)
        ? userAgent
        : _effectiveUserAgent;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
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
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            final rawAccessToken = data['access_token'];
            if (rawAccessToken is String && rawAccessToken.isNotEmpty) {
              final rawRefreshToken = data['refresh_token'];
              final refreshToken =
                  (rawRefreshToken is String && rawRefreshToken.isNotEmpty)
                  ? rawRefreshToken
                  : null;
              final rawExpiresIn = data['expires_in'];
              final expiresIn = rawExpiresIn is num
                  ? rawExpiresIn.toInt()
                  : defaultExpiresIn;
              _lastAuthError = null;
              return (
                accessToken: rawAccessToken,
                refreshToken: refreshToken,
                expiresIn: expiresIn,
              );
            }
          }
          _lastAuthError = 'Unexpected token response: ${response.body}';
          return null;
        }

        _lastAuthError = 'HTTP ${response.statusCode}: ${response.body}';
        if (response.statusCode >= 400 &&
            response.statusCode < 500 &&
            response.statusCode != 429) {
          return null;
        }
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
      } catch (e) {
        _lastAuthError = e.toString();
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
      }
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

  Future<String?> _getAnonymousToken({
    int? generation,
    bool forceRefresh = false,
  }) async {
    if (_oauthClientId == null || _oauthClientId!.trim().isEmpty) {
      return null;
    }

    if (!forceRefresh &&
        _anonymousAccessToken != null &&
        _anonymousTokenExpiry != null &&
        DateTime.now().isBefore(_anonymousTokenExpiry!)) {
      return _anonymousAccessToken;
    }

    final expectedGeneration = generation ?? _credentialsGeneration;
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

    if (expectedGeneration != _credentialsGeneration ||
        _oauthClientId == null ||
        _oauthClientId!.trim().isEmpty) {
      return null;
    }

    if (result != null) {
      _anonymousAccessToken = result.accessToken;
      _anonymousTokenExpiry = DateTime.now().add(
        safeTokenLifetime(result.expiresIn),
      );
      return _anonymousAccessToken;
    }
    return null;
  }

  Future<String?> _getValidToken({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        (hasUserOAuth || hasOAuthCredentials) &&
        _accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    final hasClientId =
        _oauthClientId != null && _oauthClientId!.trim().isNotEmpty;
    if (!hasUserOAuth && !hasOAuthCredentials && !hasClientId) {
      return null;
    }

    if (_inFlightTokenRefresh != null) {
      return await _inFlightTokenRefresh!;
    }

    final generation = _credentialsGeneration;
    final refreshFuture = _executeTokenRefresh(
      generation: generation,
      forceRefresh: forceRefresh,
    );
    _inFlightTokenRefresh = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_inFlightTokenRefresh, refreshFuture)) {
        _inFlightTokenRefresh = null;
      }
    }
  }

  Future<String?> _executeTokenRefresh({
    required int generation,
    bool forceRefresh = false,
  }) async {
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
      if (generation != _credentialsGeneration || !hasUserOAuth) {
        return null;
      }
      if (refreshed != null) {
        _accessToken = refreshed.accessToken;
        _tokenExpiry = DateTime.now().add(
          safeTokenLifetime(refreshed.expiresIn),
        );
        onTokenRefreshed?.call(refreshed.accessToken, refreshed.expiresIn);
        return _accessToken;
      }
      return null;
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
      if (generation != _credentialsGeneration || !hasOAuthCredentials) {
        return null;
      }
      if (result != null) {
        _accessToken = result.accessToken;
        _tokenExpiry = DateTime.now().add(
          safeTokenLifetime(result.expiresIn),
        );
        return _accessToken;
      }
      return null;
    }

    if (_oauthClientId != null && _oauthClientId!.trim().isNotEmpty) {
      return _getAnonymousToken(
        generation: generation,
        forceRefresh: forceRefresh,
      );
    }

    return null;
  }

  Future<({http.Response? response, String? error, bool isRateLimited})>
  _getWithAuth(
    Uri uri, {
    Duration timeout = const Duration(seconds: 20),
    int maxAttempts = 2,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      String? token = await _getValidToken();
      if (token == null) {
        final detail = _lastAuthError != null ? ' ($_lastAuthError)' : '';
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        return (
          response: null,
          error: 'Not authenticated with Reddit API$detail',
          isRateLimited: false,
        );
      }

      try {
        final generation = _credentialsGeneration;
        var response = await _client
            .get(
              uri,
              headers: {
                'Authorization': 'bearer $token',
                'User-Agent': _effectiveUserAgent,
              },
            )
            .timeout(timeout);

        if (response.statusCode == 401) {
          final sameGeneration = generation == _credentialsGeneration;
          if (sameGeneration) {
            _accessToken = null;
            _tokenExpiry = null;
          }
          token = await _getValidToken(forceRefresh: sameGeneration);
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
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        return (response: null, error: e.toString(), isRateLimited: false);
      }
    }

    return (
      response: null,
      error: 'Request failed after $maxAttempts attempts',
      isRateLimited: false,
    );
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
              importOrder: 0,
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
              importOrder: 0,
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

    final rawTitle = data['title'] as String?;
    final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : rawParentTitle;

    final author = data['author'] as String?;
    final score = data['score'] as int? ?? (data['ups'] as int? ?? 0);
    final numComments = data['num_comments'] as int? ?? 0;

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

    final isNsfw =
        (data['over_18'] as bool? ?? false) ||
        (parentData?['over_18'] as bool? ?? false) ||
        (rootParentData?['over_18'] as bool? ?? false);

    final createdUtcSec = data['created_utc'] as num?;
    final createdAt = createdUtcSec != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (createdUtcSec * 1000).toInt(),
            isUtc: true,
          )
        : null;

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

    // use a medium preview in feeds
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

        final variants = image['variants'] as Map?;
        if (variants != null) {
          final mp4Variant = variants['mp4'];
          final gifVariant = variants['gif'];
          String? variantUrl;
          if (mp4Variant is Map &&
              mp4Variant['source'] is Map &&
              mp4Variant['source']['url'] is String) {
            variantUrl = (mp4Variant['source']['url'] as String).replaceAll(
              '&amp;',
              '&',
            );
          } else if (gifVariant is Map &&
              gifVariant['source'] is Map &&
              gifVariant['source']['url'] is String) {
            variantUrl = (gifVariant['source']['url'] as String).replaceAll(
              '&amp;',
              '&',
            );
          }
          if (variantUrl != null) {
            mediaUrl = variantUrl;
            mediaType = MediaType.gif;
          }
        }
      }

      final videoPreview = (preview['reddit_video_preview'] is Map)
          ? preview['reddit_video_preview'] as Map
          : (parentPreview != null &&
                parentPreview['reddit_video_preview'] is Map)
          ? parentPreview['reddit_video_preview'] as Map
          : null;
      if (videoPreview != null) {
        final previewVideoUrl =
            (videoPreview['hls_url'] ?? videoPreview['fallback_url'])
                as String?;
        if (previewVideoUrl != null) {
          mediaUrl = previewVideoUrl.replaceAll('&amp;', '&');
          final domain =
              ((data['domain'] as String?) ??
                      (parentData?['domain'] as String?) ??
                      (rootParentData?['domain'] as String?) ??
                      '')
                  .toLowerCase();
          final isRedGifs =
              domain.contains('redgifs.com') ||
              (effectiveUrl ?? '').toLowerCase().contains('redgifs.com');
          if (isRedGifs) {
            mediaType = MediaType.video;
          } else {
            mediaType = (videoPreview['is_gif'] == true || isGifFlag)
                ? MediaType.gif
                : MediaType.video;
          }
        }
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

    // video / gif
    final isVideo =
        (data['is_video'] as bool? ?? false) ||
        (parentData?['is_video'] as bool? ?? false) ||
        (rootParentData?['is_video'] as bool? ?? false) ||
        (parentData?['media'] is Map &&
            (parentData!['media'] as Map)['reddit_video'] != null) ||
        (parentData?['secure_media'] is Map &&
            (parentData!['secure_media'] as Map)['reddit_video'] != null) ||
        (rootParentData?['media'] is Map &&
            (rootParentData!['media'] as Map)['reddit_video'] != null) ||
        (rootParentData?['secure_media'] is Map &&
            (rootParentData!['secure_media'] as Map)['reddit_video'] != null);

    if (galleryImages.isNotEmpty) {
    } else if (isVideo) {
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
          } else {
            mediaType = MediaType.video;
          }
        }
      } else {
        mediaType = isGifFlag ? MediaType.gif : MediaType.video;
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
      body: selftext,
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

  Future<({bool? isNsfw, String? iconUrl})?> fetchSubredditAbout(
    String subredditName,
  ) async {
    final normalized = SavedItem.normalizeSubredditKey(subredditName);
    if (normalized.isEmpty) return null;

    final isUser = normalized.startsWith('u_');
    final targetName = isUser ? normalized.substring(2) : normalized;
    if (targetName.isEmpty) return null;

    final path = isUser ? 'user/$targetName/about' : 'r/$targetName/about';

    http.Response? response;

    if (hasUserOAuth || hasOAuthCredentials) {
      final authResult = await _getWithAuth(
        Uri.parse('https://oauth.reddit.com/$path?raw_json=1'),
      );
      response = authResult.response;
    }

    if (response == null ||
        (response.statusCode != 200 &&
            response.statusCode != 403 &&
            response.statusCode != 404)) {
      try {
        final publicUri = Uri.parse(
          'https://www.reddit.com/$path.json?raw_json=1',
        );
        response = await _client
            .get(
              publicUri,
              headers: {
                if (_effectiveUserAgent.isNotEmpty)
                  'User-Agent': _effectiveUserAgent,
              },
            )
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        return null;
      }
    }

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        if (json is Map && json['data'] is Map) {
          final data = json['data'] as Map;
          if (data['is_suspended'] == true) {
            return (isNsfw: null, iconUrl: null);
          }
          final userSub = data['subreddit'] is Map
              ? data['subreddit'] as Map
              : null;
          final bool isNsfw =
              (data['over18'] as bool?) ??
              (userSub?['over_18'] as bool?) ??
              (userSub?['over18'] as bool?) ??
              false;

          String? cleanIcon(dynamic candidate) {
            if (candidate is String) {
              final cleaned = candidate.replaceAll('&amp;', '&').trim();
              if (cleaned.isNotEmpty && cleaned.startsWith('http')) {
                return cleaned;
              }
            }
            return null;
          }

          final icon =
              cleanIcon(data['community_icon']) ??
              cleanIcon(data['icon_img']) ??
              cleanIcon(userSub?['community_icon']) ??
              cleanIcon(userSub?['icon_img']) ??
              cleanIcon(data['snoovatar_img']) ??
              (isUser ? null : cleanIcon(data['header_img']));

          return (isNsfw: isNsfw, iconUrl: icon);
        }
      } catch (_) {}
    } else if (response.statusCode == 403) {
      if (response.body.contains('quarantined')) {
        return (isNsfw: true, iconUrl: null);
      }
      return (isNsfw: null, iconUrl: null);
    } else if (response.statusCode == 404) {
      return (isNsfw: null, iconUrl: null);
    }

    return null;
  }
}
