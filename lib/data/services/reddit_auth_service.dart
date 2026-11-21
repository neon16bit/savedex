import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RedditAuthService {
  static const _channel = MethodChannel('me.neon16bit.savedex/reddit_auth');
  static final RegExp _rfc3986SchemeRegExp = RegExp(r'^[a-z][a-z\d+.-]*$');
  static const Set<String> _reservedCustomSchemes = {
    'http',
    'https',
    'file',
    'ftp',
    'mailto',
    'tel',
    'javascript',
    'data',
    'vbscript',
    'about',
    'blob',
    'chrome',
    'edge',
    'ms-settings',
    'ms-windows-store',
    'shell',
    'search-ms',
    'cmd',
    'powershell',
    'explorer',
  };

  static int _nextDesktopAuthSessionId = 0;
  static int? _activeDesktopAuthSessionId;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);
  static bool get isSupported => isAndroid || isDesktop;

  static String? parseCustomScheme(String redirectUri) {
    final trimmed = redirectUri.trim();
    final schemeEnd = trimmed.indexOf('://');
    if (schemeEnd <= 0) return null;

    final rawScheme = trimmed.substring(0, schemeEnd).toLowerCase();
    if (rawScheme.length > 64 || !_rfc3986SchemeRegExp.hasMatch(rawScheme)) {
      return null;
    }
    if (_reservedCustomSchemes.contains(rawScheme)) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.toLowerCase() != rawScheme) return null;
    return rawScheme;
  }

  static int allocateDesktopAuthSessionId() => ++_nextDesktopAuthSessionId;

  static Future<String> authenticateWithDesktopCustomScheme({
    required String authUrl,
    required String redirectUri,
    int? sessionId,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final scheme = parseCustomScheme(redirectUri);
    if (scheme == null) {
      throw PlatformException(
        code: 'INVALID_REDIRECT_URI',
        message: 'Redirect URI must use a valid custom scheme',
      );
    }

    final activeId = sessionId ?? ++_nextDesktopAuthSessionId;
    _activeDesktopAuthSessionId = activeId;
    try {
      final result = await _channel
          .invokeMethod<String>('startDesktopCustomSchemeAuth', {
            'authUrl': authUrl,
            'callbackScheme': scheme,
          })
          .timeout(
            timeout,
            onTimeout: () async {
              if (_activeDesktopAuthSessionId == activeId) {
                await cancelPendingDesktopAuth(
                  sessionId: activeId,
                  force: true,
                );
              }
              throw PlatformException(
                code: 'TIMEOUT',
                message: 'Timed out waiting for Reddit authorization in the browser.',
              );
            },
          );

      if (result == null || result.isEmpty) {
        throw PlatformException(
          code: 'NO_RESULT',
          message: 'No callback URL received from desktop browser.',
        );
      }

      return result;
    } finally {
      if (_activeDesktopAuthSessionId == activeId) {
        _activeDesktopAuthSessionId = null;
      }
    }
  }

  static Future<void> cancelPendingDesktopAuth({
    int? sessionId,
    bool force = false,
  }) async {
    if (sessionId != null) {
      if (_activeDesktopAuthSessionId != sessionId) return;
    } else if (!force && _activeDesktopAuthSessionId == null) {
      return;
    }
    _activeDesktopAuthSessionId = null;
    try {
      await _channel.invokeMethod<void>('cancelDesktopCustomSchemeAuth');
    } on MissingPluginException {
      // Ignore when no native desktop handler is registered
    } on PlatformException {
      // Ignore cancellation cleanup errors
    } catch (_) {}
  }

  static Future<String> authenticateWithCustomTab({
    required String authUrl,
    required String redirectUri,
    required String callbackScheme,
  }) async {
    final result = await _channel.invokeMethod<String>('startCustomTabAuth', {
      'authUrl': authUrl,
      'redirectUri': redirectUri,
      'callbackScheme': callbackScheme,
    });

    if (result == null || result.isEmpty) {
      throw PlatformException(
        code: 'NO_RESULT',
        message: 'No callback URL received from Custom Tab',
      );
    }

    return result;
  }
}
