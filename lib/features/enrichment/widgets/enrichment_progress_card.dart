import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';

class EnrichmentProgressCard extends ConsumerWidget {
  final EdgeInsetsGeometry margin;
  final bool isDense;

  const EnrichmentProgressCard({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(enrichmentViewModelProvider);
    final vm = ref.read(enrichmentViewModelProvider.notifier);

    if (!state.isRunning && !state.isPaused) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = state.totalToEnrich > 0
        ? state.totalToEnrich
        : (state.processedCount + state.totalPending);
    final processed = state.processedCount;
    final percent = total > 0
        ? (processed / total * 100).toInt().clamp(0, 100)
        : 0;

    return Card(
      margin: margin,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: state.isPaused
              ? colorScheme.outlineVariant.withValues(alpha: 0.5)
              : colorScheme.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDense ? 12 : 16,
          vertical: isDense ? 10 : 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: state.isPaused
                      ? Icon(
                          Icons.pause_circle_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        )
                      : CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: state.progress > 0 ? state.progress : null,
                          color: colorScheme.primary,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.isPaused
                            ? 'Enrichment Paused'
                            : 'Downloading Metadata',
                        style: TextStyle(
                          fontSize: isDense ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (state.currentItemTitle != null &&
                          state.currentItemTitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          state.currentItemTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: state.isPaused ? 'Resume' : 'Pause',
                  icon: Icon(
                    state.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: colorScheme.primary,
                  ),
                  onPressed: () {
                    if (state.isPaused) {
                      vm.resumeEnrichment();
                    } else {
                      vm.pauseEnrichment();
                    }
                  },
                ),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Cancel Enrichment',
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => vm.stopEnrichment(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: state.isPaused ? null : state.progress,
                minHeight: 5,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  state.isPaused ? colorScheme.outline : colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    total > 0
                        ? (state.failedInSession > 0
                              ? '$total items to enrich (${state.failedInSession} failed)'
                              : '$total items to enrich')
                        : 'Enriching items...',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  total > 0
                      ? '$processed/$total ($percent%)'
                      : '$processed completed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
