import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/widgets/enrichment_progress_card.dart';
import 'package:savedex/features/import_export/import_viewmodel.dart';
import 'package:savedex/features/settings/settings_view.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

class ImportView extends ConsumerWidget {
  const ImportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importExportViewModelProvider);
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final settings = ref.watch(settingsViewModelProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import & Export')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const EnrichmentProgressCard(),

          Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF4500).withValues(alpha: 0.15),
                    colorScheme.surfaceContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4500),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cloud_download_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Pull Saved from Reddit',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (settings.isAuthenticatedWithOAuth) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      settings.redditUsername != null
                                          ? 'u/${settings.redditUsername}'
                                          : 'Connected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Fetch saved posts & comments directly via Reddit API',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (state.isImporting)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          state.statusMessage ?? 'Syncing from Reddit...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  else if (settings.isAuthenticatedWithOAuth)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4500),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final summary = await viewModel.pullSavedFromReddit();
                          if (summary != null && context.mounted) {
                            _showSummaryDialog(
                              context,
                              summary,
                              title: 'Reddit Sync Complete!',
                            );
                          } else if (state.errorMessage != null &&
                              context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.errorMessage!),
                                backgroundColor: colorScheme.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Pull Saved from Reddit'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const SettingsView(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.key_rounded),
                        label: const Text('Connect Reddit Account in Settings'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.7),
                    colorScheme.surfaceContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.file_upload_outlined,
                          color: colorScheme.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import Reddit Takeout',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Supports saved_posts.csv, saved_comments.csv, or full ZIP',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (state.isImporting)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          state.statusMessage ?? 'Importing...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final summary = await viewModel.pickAndImportFiles();
                          if (summary != null && context.mounted) {
                            _showSummaryDialog(context, summary);
                          }
                        },
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Select CSV or ZIP File'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How to export from Reddit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '1',
                    'Go to reddit.com/settings/data-request on your browser.',
                    colorScheme,
                  ),
                  _buildStep(
                    '2',
                    'Request "GDPR" or "General data request" for your saved items.',
                    colorScheme,
                  ),
                  _buildStep(
                    '3',
                    'Reddit will email you a download link with a ZIP archive.',
                    colorScheme,
                  ),
                  _buildStep(
                    '4',
                    'Select the downloaded ZIP file directly or open the CSV files here.',
                    colorScheme,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Backup & Export',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export your organized library including custom tags, notes, and stars.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isExporting
                              ? null
                              : () => _handleExport(context, ref, asJson: true),
                          icon: const Icon(Icons.data_object_rounded, size: 18),
                          label: const Text('Export JSON'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isExporting
                              ? null
                              : () =>
                                    _handleExport(context, ref, asJson: false),
                          icon: const Icon(
                            Icons.table_chart_outlined,
                            size: 18,
                          ),
                          label: const Text('Export CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showSummaryDialog(
    BuildContext context,
    ImportSummary summary, {
    String title = 'Import Complete!',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.totalInDatabase != null)
              _buildStatRow(
                'Total items in Library',
                '${summary.totalInDatabase}',
              ),
            _buildStatRow('New items added', '${summary.newItemsImported}'),
            if (summary.updatedItems > 0)
              _buildStatRow(
                'Existing items updated',
                '${summary.updatedItems}',
              ),
            _buildStatRow('Already in Library', '${summary.skippedItems}'),
            _buildStatRow('Fetched from source', '${summary.totalFound}'),
            _buildStatRow(
              'Time taken',
              '${(summary.duration.inMilliseconds / 1000).toStringAsFixed(2)}s',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref, {
    required bool asJson,
  }) async {
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final savedPath = await viewModel.exportLibrary(asJson: asJson);
    if (!context.mounted) return;

    if (savedPath != null) {
      final fileName = savedPath.split(Platform.pathSeparator).last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export saved to $fileName'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
