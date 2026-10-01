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
  Completer<void>? _resumeCompleter;

  @override
  EnrichmentState build() {
    ref.onDispose(() {
      _stopRequested = true;
      if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
        _resumeCompleter!.complete();
      }
    });
    return const EnrichmentState();
  }

  Future<void> startEnrichment() async {
    if (state.isRunning && !state.isPaused) return;

    _stopRequested = false;

    final repo = ref.read(savedItemRepositoryProvider);
    final settings = ref.read(settingsViewModelProvider);

    final delay = settings.isAuthenticatedWithOAuth
        ? AppConstants.oauthRequestDelay
        : AppConstants.anonymousRequestDelay;

    final pendingCount = await repo.getPendingEnrichmentCount();
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

    while (!_stopRequested) {
      if (state.isPaused && _resumeCompleter != null) {
        await _resumeCompleter!.future;
        if (_stopRequested) break;
      }

      final currentPending = await repo.getPendingEnrichmentCount();
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
        if (_stopRequested || state.isPaused) break;

        state = state.copyWith(currentItemTitle: item.title);

        final result = await repo.enrichItem(item);

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

        await Future.delayed(delay);
      }
    }
  }

  void pauseEnrichment() {
    if (!state.isPaused) {
      _resumeCompleter = Completer<void>();
      state = state.copyWith(isPaused: true);
    }
  }

  void resumeEnrichment() {
    if (state.isPaused) {
      state = state.copyWith(isPaused: false);
      if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
        _resumeCompleter!.complete();
        _resumeCompleter = null;
      }
    }
    if (!state.isRunning) {
      startEnrichment();
    }
  }

  void stopEnrichment() {
    _stopRequested = true;
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
      _resumeCompleter = null;
    }
    state = const EnrichmentState();
  }

  Future<({bool success, String? error})> enrichSingleItem(
    SavedItem item,
  ) async {
    final repo = ref.read(savedItemRepositoryProvider);
    return repo.enrichItem(item);
  }
}
