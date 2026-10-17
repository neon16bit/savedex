import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RedGifsVideoInfo {
  final String id;
  final String? hdUrl;
  final String? sdUrl;
  final String? posterUrl;
  final bool hasAudio;
  final double? duration;
  final int? width;
  final int? height;

  const RedGifsVideoInfo({
    required this.id,
    this.hdUrl,
    this.sdUrl,
    this.posterUrl,
    this.hasAudio = false,
    this.duration,
    this.width,
    this.height,
  });

  String? get bestUrl => hdUrl ?? sdUrl;
}

class RedGifsApiService {
  final http.Client _client;
  String? _cachedToken;
  DateTime? _tokenExpiry;

  RedGifsApiService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  static String? extractId(String urlOrId) {
    final trimmed = urlOrId.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !trimmed.contains('/')) {
      return trimmed;
    }

    final pathSegments = uri.pathSegments;
    final watchIndex = pathSegments.indexWhere(
      (s) => s.toLowerCase() == 'watch' || s.toLowerCase() == 'ifr',
    );
    if (watchIndex != -1 && watchIndex + 1 < pathSegments.length) {
      final candidate = pathSegments[watchIndex + 1].trim();
      return candidate.isNotEmpty ? candidate : null;
    } else if (pathSegments.isNotEmpty) {
      final candidate = pathSegments.last.trim();
      return candidate.isNotEmpty ? candidate : null;
    }
    return null;
  }

  Map<String, String> _buildHeaders(String? userAgent, {String? token}) {
    return {
      'Accept': 'application/json',
      if (userAgent != null && userAgent.trim().isNotEmpty)
        'User-Agent': userAgent.trim(),
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> getTemporaryToken({String? userAgent}) async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    try {
      final res = await _client
          .get(
            Uri.parse('https://api.redgifs.com/v2/auth/temporary'),
            headers: _buildHeaders(userAgent),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cachedToken = data['token'] as String?;
        _tokenExpiry = DateTime.now().add(const Duration(hours: 12));
        return _cachedToken;
      } else {
        debugPrint('RedGifs auth failed with HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('RedGifs temporary token error: $e');
    }
    return null;
  }

  Future<RedGifsVideoInfo?> fetchVideoInfo(
    String urlOrId, {
    String? userAgent,
  }) async {
    final id = extractId(urlOrId);
    if (id == null || id.isEmpty) return null;

    final token = await getTemporaryToken(userAgent: userAgent);
    if (token == null) return null;

    try {
      final res = await _client
          .get(
            Uri.parse('https://api.redgifs.com/v2/gifs/$id'),
            headers: _buildHeaders(userAgent, token: token),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 401 || res.statusCode == 403) {
        _cachedToken = null;
        _tokenExpiry = null;
        return null;
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final gif = data['gif'] as Map<String, dynamic>?;
        if (gif == null) return null;

        final urls = gif['urls'] as Map<String, dynamic>?;
        final hd = urls?['hd'] as String?;
        final sd = urls?['sd'] as String?;
        final poster = urls?['poster'] as String?;
        final hasAudio = gif['hasAudio'] == true;
        final duration = (gif['duration'] as num?)?.toDouble();
        final width = (gif['width'] as num?)?.toInt();
        final height = (gif['height'] as num?)?.toInt();

        return RedGifsVideoInfo(
          id: id,
          hdUrl: hd,
          sdUrl: sd,
          posterUrl: poster,
          hasAudio: hasAudio,
          duration: duration,
          width: width,
          height: height,
        );
      }
    } catch (e) {
      debugPrint('RedGifs fetchVideoInfo error: $e');
    }
    return null;
  }
}
