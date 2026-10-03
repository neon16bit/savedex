import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/widgets/enrichment_progress_card.dart';
import 'package:savedex/features/import_export/import_viewmodel.dart';
import 'package:savedex/features/settings/settings_view.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';

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
      appBar: AppBar(
        title: const Text('Import & Export'),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const EnrichmentProgressCard(),

          _buildSectionHeader('REDDIT API SYNC', colorScheme),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.cloud_download_rounded,
                color: Color(0xFFFF4500),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
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
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Fetch saved posts & comments directly via Reddit API',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (state.isSyncingReddit)
            _buildProgress(
              state.statusMessage ?? 'Syncing from Reddit...',
              colorScheme,
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
                onPressed: state.isBusy
                    ? null
                    : () async {
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
                    MaterialPageRoute(builder: (ctx) => const SettingsView()),
                  );
                },
                icon: const Icon(Icons.key_rounded),
                label: const Text('Connect Reddit Account in Settings'),
              ),
            ),

          const Divider(height: 40),

          _buildSectionHeader('REDDIT TAKEOUT (GDPR)', colorScheme),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.folder_zip_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Import Reddit Takeout',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select your Reddit Takeout CSVs or full ZIP archive',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (state.isImporting && !state.isSyncingReddit)
            _buildProgress(
              state.statusMessage ?? 'Importing takeout files...',
              colorScheme,
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: state.isBusy
                    ? null
                    : () => _handlePickTakeout(context, ref),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Select CSV or ZIP File'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.help_outline_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'How to get your Reddit Takeout',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  const SizedBox(height: 4),
                  _buildStep1WithLink(colorScheme),
                  _buildStep(
                    '2',
                    'Request "GDPR" or "General data request" for your saved items.',
                    colorScheme,
                  ),
                  _buildStep(
                    '3',
                    'Reddit will notify you with a download link containing a ZIP archive.',
                    colorScheme,
                  ),
                  _buildStep(
                    '4',
                    'Select the downloaded ZIP file directly or open the CSV files here.',
                    colorScheme,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],

          const Divider(height: 40),

          _buildSectionHeader('EXPORT DATA', colorScheme),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.file_download_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Export Data',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Export JSON or CSV for external tools',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (state.isExporting)
            _buildProgress(
              state.statusMessage ?? 'Exporting data...',
              colorScheme,
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => _handleExport(context, ref, asJson: true),
                    icon: const Icon(Icons.data_object_rounded, size: 18),
                    label: const Text('Export JSON'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => _handleExport(context, ref, asJson: false),
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

          const Divider(height: 40),

          _buildSectionHeader('BACKUP & RESTORE', colorScheme),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.settings_backup_restore_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Backup & Restore',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Backup snapshots with all user data',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (state.isBackingUp || state.isRestoring)
            _buildProgress(
              state.statusMessage ??
                  (state.isBackingUp
                      ? 'Creating backup...'
                      : 'Restoring library...'),
              colorScheme,
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final backupBtn = FilledButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => _handleCreateBackup(context, ref),
                  icon: const Icon(Icons.archive_rounded, size: 18),
                  label: const Text('Create Backup'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );
                final restoreBtn = OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => _handleRestoreBackup(context, ref),
                  icon: const Icon(Icons.unarchive_rounded, size: 18),
                  label: const Text('Restore Library'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: backupBtn),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: restoreBtn),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: backupBtn),
                    const SizedBox(width: 12),
                    Expanded(child: restoreBtn),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Prefers .savedex. Supports CSV and JSON exports for restore.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildProgress(String message, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ],
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

  Widget _buildStep1WithLink(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '1',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Go to ', style: TextStyle(fontSize: 13)),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(
                        'https://www.reddit.com/settings/data-request',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Text(
                      'reddit.com/settings/data-request',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const Text(
                  ' in your web browser.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
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
            Expanded(child: Text(title)),
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

  Future<void> _handleCreateBackup(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final savedPath = await viewModel.createBackup();
    if (!context.mounted) return;

    if (savedPath != null) {
      final fileName = savedPath.split(Platform.pathSeparator).last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Backup saved: $fileName')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreBackup(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final summary = await viewModel.restoreBackup();
    if (!context.mounted) return;

    if (summary != null) {
      _showSummaryDialog(context, summary, title: 'Library Restored!');
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Export saved to $fileName')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handlePickTakeout(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final summary = await viewModel.pickAndImportFiles();
    if (!context.mounted) return;

    if (summary != null) {
      _showSummaryDialog(context, summary, title: 'Takeout Imported!');
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
