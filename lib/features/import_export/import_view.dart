import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
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
      appBar: AppBar(
        title: const Text('Import & Export'),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
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
              progress: state.progress,
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
                        if (context.mounted) {
                          if (summary != null) {
                            _showImportSuccessSnackBar(
                              context,
                              ref,
                              summary,
                              prefix: 'Reddit sync',
                            );
                          } else if (ref
                                  .read(importExportViewModelProvider)
                                  .errorMessage !=
                              null) {
                            _showErrorSnackBar(
                              context,
                              ref
                                  .read(importExportViewModelProvider)
                                  .errorMessage!,
                            );
                          }
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
              progress: state.progress,
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
              progress: state.progress,
            )
          else ...[
            LayoutBuilder(
              builder: (_, constraints) {
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
                      try {
                        await ExternalUrlLauncher.launch(uri);
                      } catch (_) {}
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

  Future<void> _handleCreateBackup(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(importExportViewModelProvider.notifier);
    final savedPath = await viewModel.createBackup();

    if (!context.mounted) return;

    if (savedPath != null) {
      final fileName = savedPath.split(Platform.pathSeparator).last;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Backup created: $fileName'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        _showErrorSnackBar(context, error);
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Backup cancelled: no save location selected'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
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
      _showImportSuccessSnackBar(
        context,
        ref,
        summary,
        prefix: 'Restore complete',
      );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        _showErrorSnackBar(context, error);
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Restore cancelled: no file selected'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
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
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Export saved: $fileName'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        _showErrorSnackBar(context, error);
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Export cancelled: no save location selected'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
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
      _showImportSuccessSnackBar(
        context,
        ref,
        summary,
        offerFetchMetadata: true,
      );
    } else {
      final error = ref.read(importExportViewModelProvider).errorMessage;
      if (error != null) {
        _showErrorSnackBar(context, error);
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Import cancelled: no file selected'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
    }
  }

  static String _formatNumber(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  void _showImportSuccessSnackBar(
    BuildContext context,
    WidgetRef ref,
    ImportSummary summary, {
    String prefix = 'Import complete',
    bool offerFetchMetadata = false,
  }) {
    if (!context.mounted) return;

    final totalInDb = summary.totalInDatabase;
    final dbSuffix = totalInDb != null
        ? ' (${_formatNumber(totalInDb)} in library)'
        : '';

    final String message;
    if (summary.newItemsImported > 0 && summary.updatedItems > 0) {
      message =
          '$prefix: ${_formatNumber(summary.newItemsImported)} new, ${_formatNumber(summary.updatedItems)} updated$dbSuffix';
    } else if (summary.newItemsImported > 0) {
      message =
          '$prefix: ${_formatNumber(summary.newItemsImported)} new items added$dbSuffix';
    } else if (summary.updatedItems > 0) {
      message =
          '$prefix: ${_formatNumber(summary.updatedItems)} items refreshed$dbSuffix';
    } else {
      message = 'Library is up to date$dbSuffix';
    }

    final settings = ref.read(settingsViewModelProvider);
    final bool canOfferFetch =
        offerFetchMetadata &&
        !settings.autoEnrichOnImport &&
        summary.newItemsImported > 0;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: canOfferFetch
              ? SnackBarAction(
                  label: 'Fetch Metadata',
                  onPressed: () {
                    ref
                        .read(enrichmentViewModelProvider.notifier)
                        .startEnrichment();
                  },
                )
              : null,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: canOfferFetch ? 6 : 3),
        ),
      );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }
}
