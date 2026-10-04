import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/repositories/settings_repository.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/import_export/import_viewmodel.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

// handles both import/export and metadata enrichment
class ImportExportProgressCard extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry margin;
  final bool isDense;

  const ImportExportProgressCard({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.isDense = false,
  });

  @override
  ConsumerState<ImportExportProgressCard> createState() =>
      _ImportExportProgressCardState();
}

class _ImportExportProgressCardState
    extends ConsumerState<ImportExportProgressCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importExportViewModelProvider);
    final importVm = ref.read(importExportViewModelProvider.notifier);

    final enrichState = ref.watch(enrichmentViewModelProvider);
    final enrichVm = ref.read(enrichmentViewModelProvider.notifier);

    final settings = ref.watch(settingsViewModelProvider);

    final pendingCount =
        ref.watch(pendingEnrichmentCountProvider).asData?.value ?? 0;

    final isEnriching = enrichState.isRunning || enrichState.isPaused;
    final isImportBusy =
        importState.cardStatus == ImportExportCardStatus.running;
    final isImportCompleted =
        importState.cardStatus == ImportExportCardStatus.completed;
    final isImportFailed =
        importState.cardStatus == ImportExportCardStatus.failed;

    // if nothing is active and no completed/failed status is pending, show nothing.
    if (!isEnriching && importState.cardStatus == ImportExportCardStatus.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isPipelineMode = isEnriching && importState.lastImportSummary != null;

    // card styling
    final isFailed = isImportFailed && !isEnriching;
    final borderColor = isFailed
        ? colorScheme.error.withValues(alpha: 0.5)
        : colorScheme.primary.withValues(alpha: 0.25);

    final canExpand = isPipelineMode || isImportCompleted || isFailed;

    return Card(
      margin: widget.margin,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      color: colorScheme.surfaceContainerHigh,
      child: MouseRegion(
        cursor: canExpand ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canExpand
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isDense ? 12 : 16,
              vertical: widget.isDense ? 10 : 14,
            ),
            child: isEnriching
                ? _buildEnrichmentOrPipelineContent(
                    context,
                    colorScheme,
                    enrichState,
                    enrichVm,
                    importState,
                    importVm,
                    isPipelineMode,
                  )
                : _buildImportExportContent(
                    context,
                    colorScheme,
                    settings,
                    importState,
                    importVm,
                    enrichVm,
                    pendingCount,
                    isImportBusy,
                    isImportCompleted,
                    isFailed,
                    isEnriching,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrichmentOrPipelineContent(
    BuildContext context,
    ColorScheme colorScheme,
    EnrichmentState enrichState,
    EnrichmentViewModel enrichVm,
    ImportExportState importState,
    ImportExportViewModel importVm,
    bool isPipelineMode,
  ) {
    final total = enrichState.totalToEnrich > 0
        ? enrichState.totalToEnrich
        : (enrichState.processedCount + enrichState.totalPending);
    final processed = enrichState.processedCount;
    final percent = total > 0
        ? (processed / total * 100).toInt().clamp(0, 100)
        : 0;
    final summary = importState.lastImportSummary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: enrichState.isPaused
                  ? Icon(
                      Icons.pause_circle_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: enrichState.progress > 0
                          ? enrichState.progress
                          : null,
                      color: colorScheme.primary,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        enrichState.isPaused
                            ? 'Enrichment Paused'
                            : 'Downloading Metadata',
                        style: TextStyle(
                          fontSize: widget.isDense ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (isPipelineMode && summary != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${_formatNumber(summary.newItemsImported)} imported',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (enrichState.currentItemTitle != null &&
                      enrichState.currentItemTitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      enrichState.currentItemTitle!,
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

            if (isPipelineMode) ...[
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
            ],

            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: enrichState.isPaused ? 'Resume' : 'Pause',
              icon: Icon(
                enrichState.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: colorScheme.primary,
              ),
              onPressed: () {
                if (enrichState.isPaused) {
                  enrichVm.resumeEnrichment();
                } else {
                  enrichVm.pauseEnrichment();
                }
              },
            ),

            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Stop Enrichment',
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                enrichVm.stopEnrichment();
                importVm.dismissCard();
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        // progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: enrichState.isPaused ? null : enrichState.progress,
            minHeight: 5,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              enrichState.isPaused ? colorScheme.outline : colorScheme.primary,
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
                    ? (enrichState.failedInSession > 0
                          ? '${_formatNumber(total)} items to enrich (${_formatNumber(enrichState.failedInSession)} failed)${isPipelineMode ? ' • Import summary ⌄' : ''}'
                          : '${_formatNumber(total)} items to enrich${isPipelineMode ? ' • Import summary ⌄' : ''}')
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
                  ? '${_formatNumber(processed)}/${_formatNumber(total)} ($percent%)'
                  : '${_formatNumber(processed)} completed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),

        // import breakdown
        if (isPipelineMode && summary != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Import Completed in ${(summary.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (summary.totalInDatabase != null)
                        _buildStatRow(
                          'Total items in Library',
                          _formatNumber(summary.totalInDatabase!),
                          colorScheme,
                        ),
                      _buildStatRow(
                        'New items added',
                        _formatNumber(summary.newItemsImported),
                        colorScheme,
                      ),
                      if (summary.updatedItems > 0)
                        _buildStatRow(
                          'Existing items updated',
                          _formatNumber(summary.updatedItems),
                          colorScheme,
                        ),
                      _buildStatRow(
                        'Already up to date',
                        _formatNumber(summary.skippedItems),
                        colorScheme,
                      ),
                      _buildStatRow(
                        'Total in source file',
                        _formatNumber(summary.totalFound),
                        colorScheme,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = false;
                            });
                          },
                          child: const Text('Hide breakdown'),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildImportExportContent(
    BuildContext context,
    ColorScheme colorScheme,
    UserSettings settings,
    ImportExportState importState,
    ImportExportViewModel importVm,
    EnrichmentViewModel enrichVm,
    int pendingCount,
    bool isImportBusy,
    bool isImportCompleted,
    bool isFailed,
    bool isEnriching,
  ) {
    final title = _getTitle(importState.activeType, importState.cardStatus);
    final subtitle = _getSubtitle(importState, pendingCount);
    final summary = importState.lastImportSummary;

    final percent = importState.progress != null
        ? (importState.progress! * 100).toInt().clamp(0, 100)
        : null;

    // when items need enrichment
    final showEnrichAction =
        (isImportCompleted || isImportBusy) &&
        pendingCount > 0 &&
        !isEnriching &&
        (isImportCompleted || !settings.autoEnrichOnImport);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: isImportBusy
                    ? CircularProgressIndicator(
                        strokeWidth: 2.5,
                        value: importState.progress,
                        color: colorScheme.primary,
                      )
                    : isImportCompleted
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      )
                    : Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: colorScheme.error,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: widget.isDense ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isFailed
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            if (showEnrichAction) ...[
              FilledButton.tonalIcon(
                onPressed: isImportBusy
                    ? () => importVm.queueEnrichmentAfterImport()
                    : () => enrichVm.startEnrichment(),
                icon: isImportBusy && importState.enrichQueued
                    ? const Icon(Icons.check_rounded, size: 14)
                    : const Icon(Icons.auto_awesome_rounded, size: 13),
                label: Text(
                  isImportBusy && importState.enrichQueued
                      ? 'Queued'
                      : 'Enrich Now',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
            ],

            if (isImportCompleted || isFailed) ...[
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Dismiss',
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => importVm.dismissCard(),
              ),
            ],
          ],
        ),

        // progress bar is only shown when running
        if (isImportBusy) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: importState.progress,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  importState.statusMessage ?? 'In progress...',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percent != null ? '$percent%' : 'Working...',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],

        // breakdown
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 10),
                    if (summary != null) ...[
                      if (summary.totalInDatabase != null)
                        _buildStatRow(
                          'Total items in Library',
                          _formatNumber(summary.totalInDatabase!),
                          colorScheme,
                        ),
                      _buildStatRow(
                        'New items added',
                        _formatNumber(summary.newItemsImported),
                        colorScheme,
                      ),
                      if (summary.updatedItems > 0)
                        _buildStatRow(
                          'Existing items updated',
                          _formatNumber(summary.updatedItems),
                          colorScheme,
                        ),
                      _buildStatRow(
                        importState.activeType == ImportExportType.restore
                            ? 'Already up to date'
                            : 'Already in Library',
                        _formatNumber(summary.skippedItems),
                        colorScheme,
                      ),
                      _buildStatRow(
                        importState.activeType == ImportExportType.restore
                            ? 'Total items in backup'
                            : 'Fetched from source',
                        _formatNumber(summary.totalFound),
                        colorScheme,
                      ),
                      if (pendingCount > 0)
                        _buildStatRow(
                          'Needs enrichment',
                          '${_formatNumber(pendingCount)} items',
                          colorScheme,
                          valueColor: colorScheme.primary,
                        ),
                      _buildStatRow(
                        'Time taken',
                        '${(summary.duration.inMilliseconds / 1000).toStringAsFixed(2)}s',
                        colorScheme,
                      ),
                    ] else if (importState.lastSavedFilePath != null) ...[
                      _buildStatRow(
                        'File Name',
                        importState.lastSavedFilePath!
                            .split(Platform.pathSeparator)
                            .last,
                        colorScheme,
                      ),
                      _buildStatRow(
                        'Location',
                        importState.lastSavedFilePath!,
                        colorScheme,
                      ),
                    ] else if (importState.errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          importState.errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (pendingCount > 0) ...[
                          FilledButton.icon(
                            onPressed: () => enrichVm.startEnrichment(),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 15,
                            ),
                            label: Text(
                              'Enrich ${_formatNumber(pendingCount)} items',
                            ),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          onPressed: () => importVm.dismissCard(),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Dismiss'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _getTitle(ImportExportType type, ImportExportCardStatus status) {
    final isDone = status == ImportExportCardStatus.completed;
    final isFail = status == ImportExportCardStatus.failed;

    switch (type) {
      case ImportExportType.restore:
        return isDone
            ? 'Library Restored'
            : isFail
            ? 'Restore Failed'
            : 'Restoring Library';
      case ImportExportType.takeoutImport:
        return isDone
            ? 'Takeout Imported'
            : isFail
            ? 'Import Failed'
            : 'Importing Reddit Takeout';
      case ImportExportType.redditSync:
        return isDone
            ? 'Reddit Sync Complete'
            : isFail
            ? 'Sync Failed'
            : 'Syncing from Reddit';
      case ImportExportType.backup:
        return isDone
            ? 'Backup Created'
            : isFail
            ? 'Backup Failed'
            : 'Creating Backup';
      case ImportExportType.export:
        return isDone
            ? 'Export Saved'
            : isFail
            ? 'Export Failed'
            : 'Exporting Data';
      case ImportExportType.none:
        return isDone
            ? 'Operation Complete'
            : isFail
            ? 'Operation Failed'
            : 'Working...';
    }
  }

  String _getSubtitle(ImportExportState state, int pendingCount) {
    if (state.cardStatus == ImportExportCardStatus.failed) {
      return state.errorMessage ?? 'An error occurred';
    }

    if (state.cardStatus == ImportExportCardStatus.completed) {
      if (state.lastImportSummary != null) {
        final s = state.lastImportSummary!;
        final timeStr = (s.duration.inMilliseconds / 1000).toStringAsFixed(1);

        final parts = <String>[];
        if (s.newItemsImported > 0) {
          parts.add('${_formatNumber(s.newItemsImported)} added');
        }
        if (s.updatedItems > 0) {
          parts.add('${_formatNumber(s.updatedItems)} updated');
        }
        final details = parts.isNotEmpty ? ' (${parts.join(', ')})' : '';

        final unenrichedSuffix = pendingCount > 0
            ? ' · ${_formatNumber(pendingCount)} unenriched'
            : '';

        if (s.newItemsImported > 0 || s.updatedItems > 0) {
          return '✓ ${_formatNumber(s.totalFound)} items$details in ${timeStr}s$unenrichedSuffix';
        } else {
          return '✓ Library up to date (${_formatNumber(s.totalFound)} verified)$unenrichedSuffix';
        }
      }
      if (state.lastSavedFilePath != null) {
        final name = state.lastSavedFilePath!
            .split(Platform.pathSeparator)
            .last;
        return '✓ Saved to $name';
      }
      return state.statusMessage ?? 'Complete';
    }

    if (state.cardStatus == ImportExportCardStatus.running) {
      return state.statusMessage ?? 'In progress...';
    }

    return state.statusMessage ?? 'Processing...';
  }

  Widget _buildStatRow(
    String label,
    String value,
    ColorScheme colorScheme, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
