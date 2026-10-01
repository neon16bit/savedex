import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RedditAuthService {
  static const _channel = MethodChannel('me.neon16bit.savedex/reddit_auth');

  //TODO: need to test flutter_web_auth_2

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isSupported => isAndroid;
  static bool get supportsAutomaticAuth => isAndroid;

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

    if (result == null) {
      throw PlatformException(
        code: 'NO_RESULT',
        message: 'No callback URL received from Custom Tab',
      );
    }

    return result;
  }
}
