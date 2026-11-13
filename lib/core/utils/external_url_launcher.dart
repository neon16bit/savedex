import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalUrlLauncher {
  static const _channel = MethodChannel('me.neon16bit.savedex/external_url');

  // on android, url_launcher launches external intents without FLAG_ACTIVITY_NEW_TASK,
  // stacking the target app inside savedexs own task. Launching with NEW_TASK keeps
  // Savedex and the target app in separate tasks
  static Future<bool> launch(Uri uri) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final launched = await _channel.invokeMethod<bool>('openUrlInNewTask', {
          'url': uri.toString(),
        });
        if (launched != null) return launched;
      } on MissingPluginException {
        // fall back to url_launcher in tests or environments without the android plugin
      } on PlatformException {
        // fall back to url_launcher if the native launch rejects the request
      }
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
