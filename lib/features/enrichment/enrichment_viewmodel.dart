import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/services/foreground_enrichment_service.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

class EnrichmentState {
  final bool isRunning;
  final bool isPaused;
  final int totalToEnrich;
  final int totalPending;
  final int completedInSession;
  final int failedInSession;
  final String? currentItemTitle;

  const EnrichmentState({
    this.isRunning = false,
    this.isPaused = false,
    this.totalToEnrich = 0,
    this.totalPending = 0,
    this.completedInSession = 0,
    this.failedInSession = 0,
    this.currentItemTitle,
  });

  int get processedCount => completedInSession + failedInSession;

  double get progress {
    final total = totalToEnrich > 0
        ? totalToEnrich
        : (processedCount + totalPending);
    if (total <= 0) return 0.0;
    return (processedCount / total).clamp(0.0, 1.0);
  }

  EnrichmentState copyWith({
    bool? isRunning,
    bool? isPaused,
    int? totalToEnrich,
    int? totalPending,
    int? completedInSession,
    int? failedInSession,
    String? currentItemTitle,
    bool clearTitle = false,
  }) {
    return EnrichmentState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      totalToEnrich: totalToEnrich ?? this.totalToEnrich,
      totalPending: totalPending ?? this.totalPending,
      completedInSession: completedInSession ?? this.completedInSession,
      failedInSession: failedInSession ?? this.failedInSession,
      currentItemTitle: clearTitle
          ? null
          : (currentItemTitle ?? this.currentItemTitle),
    );
  }
}

class ArchiveRecoveryState {
  final bool isStarting;
  final bool isRunning;
  final int total;
  final int completed;
  final int failed;

  const ArchiveRecoveryState({
    this.isStarting = false,
    this.isRunning = false,
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
  });

  int get processed => completed + failed;
  double get progress => total == 0 ? 0 : (processed / total).clamp(0.0, 1.0);
}

final enrichmentViewModelProvider =
    NotifierProvider<EnrichmentViewModel, EnrichmentState>(() {
      return EnrichmentViewModel();
    });

final archiveRecoveryStateProvider =
    NotifierProvider<ArchiveRecoveryNotifier, ArchiveRecoveryState>(
      ArchiveRecoveryNotifier.new,
    );

class ArchiveRecoveryNotifier extends Notifier<ArchiveRecoveryState> {
  bool _stopRequested = false;
  Future<void>? _runFuture;

  @override
  ArchiveRecoveryState build() => const ArchiveRecoveryState();

  Future<void> start() async {
    if (state.isStarting ||
        state.isRunning ||
        _runFuture != null ||
        ref.read(enrichmentViewModelProvider).isRunning) {
      return;
    }
    _stopRequested = false;
    final completer = Completer<void>();
    _runFuture = completer.future;
    state = const ArchiveRecoveryState(isStarting: true);

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final total = await repo.getArchiveRecoveryCount();
      debugPrint(
        '[ArchiveRecovery] Starting archive recovery. Total items eligible in DB: $total',
      );
      if (total == 0 || _stopRequested) {
        debugPrint(
          '[ArchiveRecovery] No eligible items found (or stopped immediately). Exiting.',
        );
        state = const ArchiveRecoveryState();
        return;
      }

      state = ArchiveRecoveryState(isRunning: true, total: total);
      final attemptedIds = <String>{};

      while (!_stopRequested) {
        final items = await repo.getArchiveRecoveryItems(
          limit: 10,
          excludeIds: attemptedIds.toList(),
        );
        if (items.isEmpty || _stopRequested) {
          debugPrint(
            '[ArchiveRecovery] No more items to process or stop requested.',
          );
          break;
        }
        for (final item in items) {
          attemptedIds.add(item.id);
        }
        debugPrint(
          '[ArchiveRecovery] Processing batch of ${items.length} items [${attemptedIds.length}/${state.total}]',
        );

        final resultById = await repo.recoverItemsFromArchive(
          items,
          isCancelled: () => _stopRequested,
        );
        if (_stopRequested) {
          debugPrint(
            '[ArchiveRecovery] Stop requested after recovery call. Exiting loop.',
          );
          break;
        }

        var batchRecovered = 0;
        var batchFailed = 0;
        for (final item in items) {
          final result = resultById[item.id];
          final isSuccess = result != null && result.success;
          if (isSuccess) {
            batchRecovered++;
          } else {
            batchFailed++;
          }
          debugPrint(
            '[ArchiveRecovery] Item ${item.id} -> ${isSuccess ? "RECOVERED" : "FAILED: ${result?.error ?? 'Not found'}"}',
          );
        }

        state = ArchiveRecoveryState(
          isRunning: true,
          total: state.total,
          completed: state.completed + batchRecovered,
          failed: state.failed + batchFailed,
        );
        if (!_stopRequested) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    } catch (e, stack) {
      debugPrint('[ArchiveRecovery] ERROR in recovery loop: $e\n$stack');
      if (!_stopRequested) {
        state = ArchiveRecoveryState(
          isRunning: false,
          isStarting: false,
          total: state.total,
          completed: state.completed,
          failed: state.failed,
        );
      }
    } finally {
      final wasStopRequested = _stopRequested;
      _stopRequested = false;
      _runFuture = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (state.isRunning || wasStopRequested) {
        state = ArchiveRecoveryState(
          total: state.total,
          completed: state.completed,
          failed: state.failed,
        );
      }
      debugPrint(
        '[ArchiveRecovery] Loop terminated. Summary: ${state.completed} recovered, ${state.failed} unavailable (stopped: $wasStopRequested)',
      );
    }
  }

  void stop() {
    debugPrint('[ArchiveRecovery] Stop requested by user');
    if (!state.isRunning && !state.isStarting && _runFuture == null) return;
    _stopRequested = true;
    ref.read(savedItemRepositoryProvider).cancelArchiveRecovery();
    state = ArchiveRecoveryState(
      isRunning: false,
      isStarting: false,
      total: state.total,
      completed: state.completed,
      failed: state.failed,
    );
  }

  Future<void> resetUnavailable() async {
    if (state.isRunning || state.isStarting) return;
    await ref.read(savedItemRepositoryProvider).resetArchiveUnavailableStatus();
    state = const ArchiveRecoveryState();
  }
}

class EnrichmentViewModel extends Notifier<EnrichmentState> {
  bool _stopRequested = false;
  bool _isDisposed = false;
  Completer<void>? _resumeCompleter;
  Future<void>? _runFuture;
  Timer? _pauseTimeoutTimer;

  @override
  EnrichmentState build() {
    _isDisposed = false;
    _stopRequested = false;
    _runFuture = null;
    _pauseTimeoutTimer?.cancel();
    _pauseTimeoutTimer = null;
    ForegroundEnrichmentService.addTaskDataCallback(
      _handleForegroundTaskAction,
    );
    ref.onDispose(() {
      _isDisposed = true;
      _stopRequested = true;
      _pauseTimeoutTimer?.cancel();
      _pauseTimeoutTimer = null;
      ForegroundEnrichmentService.removeTaskDataCallback(
        _handleForegroundTaskAction,
      );
      ForegroundEnrichmentService.stop();
      if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
        _resumeCompleter!.complete();
        _resumeCompleter = null;
      }
      _runFuture = null;
    });
    return const EnrichmentState();
  }

  void _handleForegroundTaskAction(Object data) {
    if (_isDisposed) return;
    if (data == ForegroundEnrichmentService.actionPause ||
        data == ForegroundEnrichmentService.eventTimeout) {
      pauseEnrichment();
    } else if (data == ForegroundEnrichmentService.actionResume) {
      resumeEnrichment();
    } else if (data == ForegroundEnrichmentService.actionStop) {
      stopEnrichment();
    }
  }

  bool get _isMounted => !_isDisposed && !_stopRequested;

  Future<void> startEnrichment() async {
    if (_stopRequested && _runFuture != null) {
      try {
        await _runFuture;
      } catch (_) {}
    }

    // if a run is active, return the existing run future
    if (_runFuture != null) {
      if (state.isPaused) {
        resumeEnrichment();
      }
      return _runFuture!;
    }

    if (state.isRunning && !state.isPaused) {
      return;
    }

    final completer = Completer<void>();
    _runFuture = completer.future;
    _stopRequested = false;

    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
    }
    _resumeCompleter = null;

    () async {
      try {
        await _executeEnrichmentLoop();
      } finally {
        _runFuture = null;
        if (!_isDisposed) {
          _stopRequested = false;
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }();

    return _runFuture!;
  }

  Future<void> _executeEnrichmentLoop() async {
    final repo = ref.read(savedItemRepositoryProvider);
    final settings = ref.read(settingsViewModelProvider);

    final isOAuth = settings.isAuthenticatedWithOAuth;
    final delay = isOAuth
        ? AppConstants.oauthEnrichmentDelay
        : AppConstants.anonymousRequestDelay;
    final workerCount = isOAuth ? AppConstants.oauthEnrichmentWorkers : 1;

    final pendingCount = await repo.getPendingEnrichmentCount();
    if (!_isMounted) return;
    if (pendingCount == 0) {
      state = state.copyWith(
        isRunning: false,
        isPaused: false,
        totalToEnrich: 0,
        totalPending: 0,
        clearTitle: true,
      );
      return;
    }

    final initialTotal = (state.isPaused && state.totalToEnrich > 0)
        ? (state.processedCount + pendingCount > state.totalToEnrich
              ? state.processedCount + pendingCount
              : state.totalToEnrich)
        : pendingCount;

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      totalToEnrich: initialTotal,
      totalPending: pendingCount,
      completedInSession: state.isPaused ? state.completedInSession : 0,
      failedInSession: state.isPaused ? state.failedInSession : 0,
    );

    await ForegroundEnrichmentService.start(
      processed: state.processedCount,
      total: state.totalToEnrich,
      isPaused: false,
      failed: state.failedInSession,
    );

    var consecutive429Batches = 0;

    while (_isMounted) {
      if (state.isPaused && _resumeCompleter != null) {
        await _resumeCompleter!.future;
        if (!_isMounted) break;
      }

      final currentPending = await repo.getPendingEnrichmentCount();
      if (!_isMounted) break;
      if (currentPending == 0) {
        state = state.copyWith(
          isRunning: false,
          isPaused: false,
          totalPending: 0,
          clearTitle: true,
        );
        break;
      }

      final requiredTotal = state.processedCount + currentPending;
      if (requiredTotal > state.totalToEnrich) {
        state = state.copyWith(
          totalToEnrich: requiredTotal,
          totalPending: currentPending,
        );
      } else {
        state = state.copyWith(totalPending: currentPending);
      }

      final pendingItems = await repo.getPendingEnrichmentItems(
        limit: workerCount * 10,
      );
      if (!_isMounted) break;
      if (pendingItems.isEmpty) {
        state = state.copyWith(
          isRunning: false,
          isPaused: false,
          totalPending: 0,
          clearTitle: true,
        );
        break;
      }

      // OAuth users run several workers in parallel
      // anonymous users keep a single sequential worker
      var nextIndex = 0;
      var batchSuccessCount = 0;
      var batchRateLimitedCount = 0;

      Future<void> worker() async {
        while (_isMounted && !state.isPaused) {
          if (nextIndex >= pendingItems.length) break;
          final item = pendingItems[nextIndex++];

          state = state.copyWith(currentItemTitle: item.title);

          final result = await repo.enrichItem(item);
          if (!_isMounted) break;

          if (result.success) {
            batchSuccessCount++;
            state = state.copyWith(
              completedInSession: state.completedInSession + 1,
              totalPending: (state.totalPending - 1).clamp(0, 999999),
            );
            ForegroundEnrichmentService.update(
              processed: state.processedCount,
              total: state.totalToEnrich,
              isPaused: state.isPaused,
              failed: state.failedInSession,
            );
          } else if (result.willRetry) {
            batchRateLimitedCount++;
            ForegroundEnrichmentService.update(
              processed: state.processedCount,
              total: state.totalToEnrich,
              isPaused: state.isPaused,
              failed: state.failedInSession,
              customSubtitle: 'Reddit rate limit reached · cooling down...',
              force: true,
            );
            await Future.delayed(const Duration(seconds: 5));
          } else {
            state = state.copyWith(
              failedInSession: state.failedInSession + 1,
              totalPending: (state.totalPending - 1).clamp(0, 999999),
            );
            ForegroundEnrichmentService.update(
              processed: state.processedCount,
              total: state.totalToEnrich,
              isPaused: state.isPaused,
              failed: state.failedInSession,
            );
          }

          if (!_isMounted || state.isPaused) break;
          await Future.delayed(delay);
        }
      }

      await Future.wait(List.generate(workerCount, (_) => worker()));
      if (!_isMounted) break;

      if (batchSuccessCount == 0 && batchRateLimitedCount > 0) {
        consecutive429Batches++;
        if (consecutive429Batches >= 2) {
          debugPrint(
            '[EnrichmentViewModel] Rate limit active for consecutive batches. Auto-pausing.',
          );
          pauseEnrichment();
          break;
        } else {
          await Future.delayed(const Duration(seconds: 10));
        }
      } else {
        consecutive429Batches = 0;
      }
    }

    _pauseTimeoutTimer?.cancel();
    _pauseTimeoutTimer = null;
    if (!_isDisposed && !state.isPaused) {
      state = state.copyWith(isRunning: false, clearTitle: true);
      await ForegroundEnrichmentService.stop();
    }
  }

  void pauseEnrichment() {
    if (_isDisposed ||
        !state.isRunning ||
        state.isPaused ||
        _runFuture == null) {
      return;
    }
    _resumeCompleter = Completer<void>();
    state = state.copyWith(isPaused: true);
    ForegroundEnrichmentService.update(
      processed: state.processedCount,
      total: state.totalToEnrich,
      isPaused: true,
      failed: state.failedInSession,
      force: true,
    );

    // Auto-release wake lock after 15 minutes of inactivity while paused
    _pauseTimeoutTimer?.cancel();
    _pauseTimeoutTimer = Timer(const Duration(minutes: 15), () async {
      if (_isDisposed || !state.isPaused) return;
      debugPrint(
        '[EnrichmentViewModel] Paused for 15 minutes. Releasing wake lock and stopping foreground service.',
      );
      await ForegroundEnrichmentService.stop();
    });
  }

  void resumeEnrichment() {
    if (_isDisposed) return;
    _pauseTimeoutTimer?.cancel();
    _pauseTimeoutTimer = null;
    if (state.isPaused) {
      state = state.copyWith(isPaused: false);
      ForegroundEnrichmentService.start(
        processed: state.processedCount,
        total: state.totalToEnrich,
        isPaused: false,
        failed: state.failedInSession,
      );
      if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
        _resumeCompleter!.complete();
        _resumeCompleter = null;
      }
    }
    if (_runFuture == null) {
      startEnrichment();
    }
  }

  void stopEnrichment() {
    _stopRequested = true;
    _pauseTimeoutTimer?.cancel();
    _pauseTimeoutTimer = null;
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
      _resumeCompleter = null;
    }
    ForegroundEnrichmentService.stop();

    // _runFuture is retained until _executeEnrichmentLoop() finishes
    if (!_isDisposed) {
      state = const EnrichmentState();
    }
  }

  Future<({bool success, String? error, bool willRetry})> enrichSingleItem(
    SavedItem item,
  ) async {
    final repo = ref.read(savedItemRepositoryProvider);
    return repo.enrichItem(item);
  }

  Future<({bool success, String? error})> recoverSingleItemFromArchive(
    SavedItem item, {
    bool force = false,
  }) {
    return ref
        .read(savedItemRepositoryProvider)
        .recoverItemFromArchive(item, force: force);
  }
}
