import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/import_export/import_viewmodel.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class BackupRestoreView extends ConsumerWidget {
  const BackupRestoreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importExportViewModelProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildSectionHeader('CREATE BACKUP', colorScheme),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.archive_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Create Backup',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Save a complete .savedex snapshot including saved posts, comments, collections, user notes, and subreddit metadata.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (state.isBackingUp)
            _buildProgress(
              state.statusMessage ?? 'Creating backup...',
              colorScheme,
              progress: state.progress,
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isBusy
                    ? null
                    : () => _handleCreateBackup(context, ref),
                icon: const Icon(Icons.archive_rounded),
                label: const Text('Create Backup'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

          const Divider(height: 40),

          _buildSectionHeader('RESTORE LIBRARY', colorScheme),
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
                'Restore Library',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Restore saved items, collections, and notes from a backup file.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (state.isRestoring)
            _buildProgress(
              state.statusMessage ?? 'Restoring library...',
              colorScheme,
              progress: state.progress,
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: state.isBusy
                    ? null
                    : () => _handleRestoreBackup(context, ref),
                icon: const Icon(Icons.unarchive_rounded),
                label: const Text('Select Backup File'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                    'Supports .savedex backups as well as JSON and CSV exports.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
              progress: state.progress,
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

  Widget _buildProgress(
    String message,
    ColorScheme colorScheme, {
    double? progress,
  }) {
    final percent = progress != null
        ? (progress * 100).clamp(0, 100).toInt()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (percent != null) ...[
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Future<void> _handleCreateBackup(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final savedPath = await viewModel.createBackup();

    if (!context.mounted) return;

    if (savedPath != null) {
      final fileName = p.basename(savedPath);
      showAppSnackBar(
        context,
        'Backup created: $fileName',
        duration: const Duration(seconds: 3),
      );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        _showErrorSnackBar(context, error);
      } else {
        showAppSnackBar(context, 'Backup cancelled: no save location selected');
      }
    }
  }

  Future<void> _handleRestoreBackup(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final summary = await viewModel.restoreBackup();

    if (!context.mounted) return;

    if (summary != null) {
      _showRestoreSuccessSnackBar(context, ref, summary);
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        _showErrorSnackBar(context, error);
      } else {
        showAppSnackBar(context, 'Restore cancelled: no file selected');
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
      final fileName = p.basename(savedPath);
      showAppSnackBar(
        context,
        'Export saved: $fileName',
        duration: const Duration(seconds: 3),
      );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        _showErrorSnackBar(context, error);
      } else {
        showAppSnackBar(context, 'Export cancelled: no save location selected');
      }
    }
  }

  static String _formatNumber(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  void _showRestoreSuccessSnackBar(
    BuildContext context,
    WidgetRef ref,
    ImportSummary summary,
  ) {
    final totalInDb = summary.totalInDatabase;
    final dbSuffix = totalInDb != null
        ? ' (${_formatNumber(totalInDb)} in library)'
        : '';

    final String message;
    if (summary.newItemsImported > 0 && summary.updatedItems > 0) {
      message =
          'Restore complete: ${_formatNumber(summary.newItemsImported)} new, ${_formatNumber(summary.updatedItems)} updated$dbSuffix';
    } else if (summary.newItemsImported > 0) {
      message =
          'Restore complete: ${_formatNumber(summary.newItemsImported)} new items added$dbSuffix';
    } else if (summary.updatedItems > 0) {
      message =
          'Restore complete: ${_formatNumber(summary.updatedItems)} items refreshed$dbSuffix';
    } else {
      message = 'Library is up to date$dbSuffix';
    }

    final willAutoEnrich = ref
        .read(importExportViewModelProvider)
        .autoEnrichScheduled;
    showAppSnackBar(
      context,
      message,
      duration: willAutoEnrich
          ? const Duration(milliseconds: 1500)
          : const Duration(seconds: 3),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    showAppSnackBar(
      context,
      message,
      isError: true,
      duration: const Duration(seconds: 4),
    );
  }
}
