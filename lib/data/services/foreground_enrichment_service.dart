import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startEnrichmentForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(EnrichmentTaskHandler());
}

class EnrichmentTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[EnrichmentTaskHandler] onDestroy: isTimeout=$isTimeout');
    if (isTimeout) {
      FlutterForegroundTask.sendDataToMain('timeout');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(id);
  }
}

class ForegroundEnrichmentService {
  static const int _serviceId = 410;
  static const String actionPause = 'enrichment_pause';
  static const String actionResume = 'enrichment_resume';
  static const String actionStop = 'enrichment_stop';
  static const String eventTimeout = 'timeout';

  static bool _isInitialized = false;
  static DateTime? _lastUpdateAt;

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static void initCommunicationPort() {
    if (!isSupported) return;
    FlutterForegroundTask.initCommunicationPort();
  }

  static void initService() {
    if (!isSupported) return;
    if (_isInitialized) return;
    _isInitialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'savedex_enrichment_service',
        channelName: 'Savedex Metadata Service',
        channelDescription: 'Keeps Savedex running in the background while downloading metadata for saved posts and comments.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showWhen: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: false,
        stopWithTask: false,
      ),
    );
  }

  static void addTaskDataCallback(DataCallback callback) {
    if (!isSupported) return;
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  static void removeTaskDataCallback(DataCallback callback) {
    if (!isSupported) return;
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  static Future<void> ensurePermissions() async {
    if (!isSupported) return;
    try {
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {}
  }

  static String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  static List<NotificationButton> _buildButtons({required bool isPaused}) {
    return [
      NotificationButton(
        id: isPaused ? actionResume : actionPause,
        text: isPaused ? 'Resume' : 'Pause',
      ),
      const NotificationButton(id: actionStop, text: 'Stop'),
    ];
  }

  static (String, String) _formatContent({
    required int processed,
    required int total,
    required bool isPaused,
    int failed = 0,
    String? customSubtitle,
  }) {
    final safeTotal = total > 0 ? total : processed;
    final pct = safeTotal > 0
        ? ((processed / safeTotal) * 100).clamp(0, 100).toInt()
        : 0;
    final title = isPaused
        ? 'Metadata download paused'
        : 'Updating Metadata ($pct%)';
    final failedStr = failed > 0 ? ' (${_fmt(failed)} failed)' : '';
    final text =
    customSubtitle != null
        ? '$customSubtitle$failedStr'
        : '${_fmt(processed)} of ${_fmt(safeTotal)} items processed$failedStr';
    return (title, text);
  }

  static Future<void> start({
    required int processed,
    required int total,
    bool isPaused = false,
    int failed = 0,
  }) async {
    if (!isSupported) return;
    initService();
    await ensurePermissions();

    final (title, text) = _formatContent(
      processed: processed,
      total: total,
      isPaused: isPaused,
      failed: failed,
    );
    _lastUpdateAt = DateTime.now();

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _buildButtons(isPaused: isPaused),
          callback: startEnrichmentForegroundCallback,
        );
      } else {
        final result = await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: [ForegroundServiceTypes.dataSync],
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _buildButtons(isPaused: isPaused),
          callback: startEnrichmentForegroundCallback,
        );
        debugPrint(
          '[ForegroundEnrichmentService] startService result: $result',
        );
      }
    } catch (e, stack) {
      debugPrint(
        '[ForegroundEnrichmentService] Failed to start service: $e\n$stack',
      );
    }
  }

  static Future<void> update({
    required int processed,
    required int total,
    bool isPaused = false,
    int failed = 0,
    String? customSubtitle,
    bool force = false,
  }) async {
    if (!isSupported) return;

    final now = DateTime.now();
    if (!force &&
        _lastUpdateAt != null &&
        now.difference(_lastUpdateAt!).inMilliseconds < 750) {
      return;
    }
    _lastUpdateAt = now;

    final (title, text) = _formatContent(
      processed: processed,
      total: total,
      isPaused: isPaused,
      failed: failed,
      customSubtitle: customSubtitle,
    );

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _buildButtons(isPaused: isPaused),
        );
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    _lastUpdateAt = null;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('[ForegroundEnrichmentService] Failed to stop service: $e');
    }
  }
}
