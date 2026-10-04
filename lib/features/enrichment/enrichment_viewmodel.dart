import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
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

final enrichmentViewModelProvider =
    NotifierProvider<EnrichmentViewModel, EnrichmentState>(() {
      return EnrichmentViewModel();
    });

class EnrichmentViewModel extends Notifier<EnrichmentState> {
  bool _stopRequested = false;
  bool _isDisposed = false;
  Completer<void>? _resumeCompleter;
  Future<void>? _runFuture;

  @override
  EnrichmentState build() {
    _isDisposed = false;
    _stopRequested = false;
    _runFuture = null;
    ref.onDispose(() {
      _isDisposed = true;
      _stopRequested = true;
      if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
        _resumeCompleter!.complete();
        _resumeCompleter = null;
      }
      _runFuture = null;
    });
    return const EnrichmentState();
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

    final delay = settings.isAuthenticatedWithOAuth
        ? AppConstants.oauthRequestDelay
        : AppConstants.anonymousRequestDelay;

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

      final pendingItems = await repo.getPendingEnrichmentItems(limit: 20);
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

      for (final item in pendingItems) {
        if (!_isMounted || state.isPaused) break;

        state = state.copyWith(currentItemTitle: item.title);

        final result = await repo.enrichItem(item);
        if (!_isMounted) break;

        if (result.success) {
          state = state.copyWith(
            completedInSession: state.completedInSession + 1,
            totalPending: (state.totalPending - 1).clamp(0, 999999),
          );
        } else {
          state = state.copyWith(
            failedInSession: state.failedInSession + 1,
            totalPending: (state.totalPending - 1).clamp(0, 999999),
          );
        }

        if (!_isMounted || state.isPaused) break;
        await Future.delayed(delay);
        if (!_isMounted) break;
      }
    }

    if (!_isDisposed && !state.isPaused) {
      state = state.copyWith(isRunning: false, clearTitle: true);
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
  }

  void resumeEnrichment() {
    if (_isDisposed) return;
    if (state.isPaused) {
      state = state.copyWith(isPaused: false);
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
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
      _resumeCompleter = null;
    }

    // _runFuture is retained until _executeEnrichmentLoop() finishes
    if (!_isDisposed) {
      state = const EnrichmentState();
    }
  }

  Future<({bool success, String? error})> enrichSingleItem(
    SavedItem item,
  ) async {
    final repo = ref.read(savedItemRepositoryProvider);
    return repo.enrichItem(item);
  }
}
