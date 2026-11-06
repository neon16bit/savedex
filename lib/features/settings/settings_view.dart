import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/repositories/settings_repository.dart';
import 'package:savedex/theme/app_theme.dart';
import 'package:savedex/data/services/reddit_api_service.dart';
import 'package:savedex/data/services/reddit_auth_service.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/import_export/import_view.dart';
import 'package:savedex/features/import_export/import_viewmodel.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
        children: [
          _buildSectionHeader('Data & Takeout', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.file_upload_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text(
                    'Import & Export Data',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Reddit Takeout, API sync, backups, and exports',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportView()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const _ImageCacheTile(),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_sweep_rounded,
                      color: colorScheme.error,
                    ),
                  ),
                  title: Text(
                    'Clear Saved Database',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Delete all saved posts, comments, collections, and search index',
                  ),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () => _confirmClearDatabase(context, ref),
                    child: const Text('Clear All'),
                  ),
                ),
              ],
            ),
          ),

          _buildSectionHeader('Media Playback', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_off_outlined),
                  title: const Text('Start Videos Muted'),
                  subtitle: const Text('Videos start muted by default.'),
                  value: settings.startVideosMuted,
                  onChanged: (val) => viewModel.toggleStartVideosMuted(val),
                ),
              ],
            ),
          ),

          _buildSectionHeader('Appearance & Theme', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Material You (Dynamic Color)'),
                  subtitle: const Text(
                    'Use system wallpaper palette when available',
                  ),
                  trailing: Switch(
                    value: settings.useDynamicColor,
                    onChanged: (val) => viewModel.toggleDynamicColor(val),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Accent Color',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(AppTheme.presets.length, (
                            index,
                          ) {
                            final presetColor = AppTheme.presets[index];
                            final isSelected =
                                !settings.useDynamicColor &&
                                settings.seedColorIndex == index;

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {
                                  if (settings.useDynamicColor) {
                                    viewModel.toggleDynamicColor(false);
                                  }
                                  viewModel.setSeedColorIndex(index);
                                },
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: presetColor,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: colorScheme.primary,
                                            width: 3.5,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: presetColor.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Theme Mode'),
                  subtitle: Text(
                    settings.themeMode == ThemeMode.system
                        ? 'System Default'
                        : settings.themeMode == ThemeMode.dark
                        ? 'Dark Mode'
                        : 'Light Mode',
                  ),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.auto_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 16),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) =>
                        viewModel.setThemeMode(set.first),
                    showSelectedIcon: false,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Pure Black'),
                  subtitle: const Text(
                    'Use deep pitch black for dark theme surfaces',
                  ),
                  trailing: Switch(
                    value: settings.isAmoled,
                    onChanged: (val) => viewModel.toggleAmoled(val),
                  ),
                ),
              ],
            ),
          ),

          _buildSectionHeader('Reddit API', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_outlined),
                  title: const Text('Auto-Fetch Metadata on Import'),
                  subtitle: const Text(
                    'Download post metadata & flairs right after CSV import',
                  ),
                  trailing: Switch(
                    value: settings.autoEnrichOnImport,
                    onChanged: (val) => viewModel.toggleAutoEnrich(val),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final pendingCount =
                        ref
                            .watch(pendingEnrichmentCountProvider)
                            .asData
                            ?.value ??
                        0;
                    final enrichState = ref.watch(enrichmentViewModelProvider);
                    final enrichVm = ref.read(
                      enrichmentViewModelProvider.notifier,
                    );
                    final isEnriching =
                        enrichState.isRunning || enrichState.isPaused;

                    final formattedCount = pendingCount
                        .toString()
                        .replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (m) => '${m[1]},',
                        );

                    String subtitle;
                    if (isEnriching) {
                      final total = enrichState.totalToEnrich > 0
                          ? enrichState.totalToEnrich
                          : (enrichState.processedCount +
                                enrichState.totalPending);
                      final percent = total > 0
                          ? ((enrichState.processedCount / total) * 100)
                                .toInt()
                                .clamp(0, 100)
                          : 0;
                      subtitle = enrichState.isPaused
                          ? 'Metadata download paused (${enrichState.processedCount}/$total · $percent%)'
                          : 'Downloading metadata (${enrichState.processedCount}/$total · $percent%)';
                    } else if (pendingCount > 0) {
                      subtitle =
                          '$formattedCount ${pendingCount == 1 ? "item needs" : "items need"} metadata & images';
                    } else {
                      subtitle = 'All items in library have complete metadata';
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: pendingCount > 0 || isEnriching
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: pendingCount > 0 || isEnriching
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: const Text(
                            'Download Library Metadata',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(subtitle),
                          trailing: FilledButton.tonal(
                            onPressed: (pendingCount == 0 || isEnriching)
                                ? null
                                : () => enrichVm.startEnrichment(),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              isEnriching
                                  ? (enrichState.isPaused
                                        ? 'Paused'
                                        : 'Running...')
                                  : 'Fetch Metadata',
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: isEnriching
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    10,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: enrichState.isPaused
                                              ? null
                                              : enrichState.progress,
                                          minHeight: 5,
                                          backgroundColor: colorScheme
                                              .surfaceContainerHighest,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                enrichState.isPaused
                                                    ? colorScheme.outline
                                                    : colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              enrichState.currentItemTitle !=
                                                          null &&
                                                      enrichState
                                                          .currentItemTitle!
                                                          .isNotEmpty
                                                  ? enrichState
                                                        .currentItemTitle!
                                                  : (enrichState.isPaused
                                                        ? 'Download paused'
                                                        : 'Downloading metadata...'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            iconSize: 18,
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            tooltip: enrichState.isPaused
                                                ? 'Resume'
                                                : 'Pause',
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
                                          const SizedBox(width: 4),
                                          IconButton(
                                            iconSize: 18,
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            tooltip: 'Stop Download',
                                            icon: Icon(
                                              Icons.close_rounded,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            onPressed: () =>
                                                enrichVm.stopEnrichment(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final recoveryState = ref.watch(
                      archiveRecoveryStateProvider,
                    );
                    final recoveryVm = ref.read(
                      archiveRecoveryStateProvider.notifier,
                    );
                    final isEnrichmentRunning = ref.watch(
                      enrichmentViewModelProvider.select((s) => s.isRunning),
                    );

                    final count =
                        ref.watch(archiveRecoveryCountProvider).asData?.value ??
                        0;
                    final unavailableCount =
                        ref
                            .watch(archiveUnavailableCountProvider)
                            .asData
                            ?.value ??
                        0;
                    final isStarting = recoveryState.isStarting;
                    final isRunning = recoveryState.isRunning;
                    final hasSummary =
                        !isStarting &&
                        !isRunning &&
                        recoveryState.total > 0 &&
                        recoveryState.processed > 0;
                    final String subtitle;
                    if (isStarting) {
                      subtitle = 'Preparing archive recovery...';
                    } else if (isRunning) {
                      subtitle =
                          'Recovering ${recoveryState.processed}/${recoveryState.total} items';
                    } else if (hasSummary) {
                      subtitle =
                          '${recoveryState.completed} recovered, ${recoveryState.failed} unavailable';
                    } else if (count == 0 && unavailableCount > 0) {
                      subtitle =
                          'All eligible items checked ($unavailableCount unavailable in archive)';
                    } else if (count == 0 && unavailableCount == 0) {
                      subtitle = 'No failed or removed items available';
                    } else if (unavailableCount > 0) {
                      subtitle =
                          '$count items available ($unavailableCount unavailable in archive)';
                    } else {
                      subtitle = '$count items available for archive recovery';
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isStarting || isRunning
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.archive_rounded,
                              color: isRunning
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: const Text(
                            'Recover Removed Content',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(subtitle),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (unavailableCount > 0 &&
                                  !isRunning &&
                                  !isStarting)
                                IconButton(
                                  icon: const Icon(
                                    Icons.restart_alt_rounded,
                                    size: 20,
                                  ),
                                  tooltip:
                                      'Reset and re-check $unavailableCount unavailable item(s)',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                          'Re-check Unavailable Items?',
                                        ),
                                        content: Text(
                                          'This will reset the status of $unavailableCount item(s) previously not found in public archives so they can be queried again.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Reset'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await recoveryVm.resetUnavailable();
                                    }
                                  },
                                ),
                              FilledButton.tonal(
                                onPressed:
                                    (count == 0 ||
                                        isStarting ||
                                        isRunning ||
                                        isEnrichmentRunning)
                                    ? null
                                    : recoveryVm.start,
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  isStarting
                                      ? 'Preparing...'
                                      : isRunning
                                      ? 'Running...'
                                      : 'Recover Now',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isRunning)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: LinearProgressIndicator(
                                      value: recoveryState.progress,
                                      minHeight: 5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: recoveryVm.stop,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: const Text('Stop'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.archive_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Archive Recovery Backend',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Choose where recovered metadata is looked up.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ArchiveBackend>(
                        initialValue: settings.archiveBackend,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Backend',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (backend) {
                          if (backend != null) {
                            viewModel.setArchiveBackend(backend);
                          }
                        },
                        items: [
                          for (final backend in ArchiveBackend.values)
                            DropdownMenuItem(
                              value: backend,
                              child: Text(
                                backend.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: settings.isAuthenticatedWithOAuth
                          ? colorScheme.primaryContainer
                          : (settings.redditClientId != null &&
                                settings.redditClientId!.isNotEmpty)
                          ? colorScheme.secondaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      settings.isAuthenticatedWithOAuth
                          ? Icons.verified_user_rounded
                          : (settings.redditClientId != null &&
                                settings.redditClientId!.isNotEmpty)
                          ? Icons.vpn_key_rounded
                          : Icons.key_off_outlined,
                      color: settings.isAuthenticatedWithOAuth
                          ? colorScheme.primary
                          : (settings.redditClientId != null &&
                                settings.redditClientId!.isNotEmpty)
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: const Text(
                    'Reddit API & OAuth',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    settings.isAuthenticatedWithOAuth
                        ? (settings.redditUsername != null
                              ? 'Authenticated as u/${settings.redditUsername}'
                              : 'Authenticated via OAuth')
                        : (settings.redditClientId != null &&
                              settings.redditClientId!.isNotEmpty)
                        ? 'Client ID configured'
                        : 'Not configured (Client ID required)',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showApiCredentialsDialog(context),
                ),
                if (settings.isAuthenticatedWithOAuth) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Consumer(
                    builder: (context, ref, _) {
                      final importState = ref.watch(
                        importExportViewModelProvider,
                      );
                      final importVm = ref.read(
                        importExportViewModelProvider.notifier,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4500)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.cloud_download_rounded,
                                color: Color(0xFFFF4500),
                              ),
                            ),
                            title: const Text(
                              'Pull Saved from Reddit',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              settings.redditUsername != null
                                  ? 'Pull last 1,000 saves for u/${settings.redditUsername}'
                                  : 'Pull up to 1,000 saved posts & comments',
                            ),
                            trailing: importState.isImporting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : FilledButton.tonal(
                                    onPressed: () async {
                                      final summary = await importVm
                                          .pullSavedFromReddit();
                                      if (context.mounted) {
                                        if (summary != null) {
                                          final totalInDb =
                                              summary.totalInDatabase;
                                          final dbSuffix = totalInDb != null
                                              ? ' ($totalInDb in library)'
                                              : '';
                                          final msg =
                                              summary.newItemsImported > 0
                                              ? 'Reddit sync: ${summary.newItemsImported} new items added$dbSuffix!'
                                              : 'Library is up to date$dbSuffix!';
                                          ScaffoldMessenger.of(context)
                                            ..clearSnackBars()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(msg),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                        } else if (importState.errorMessage !=
                                            null) {
                                          ScaffoldMessenger.of(context)
                                            ..clearSnackBars()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  importState.errorMessage!,
                                                ),
                                                backgroundColor:
                                                    colorScheme.error,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                        }
                                      }
                                    },
                                    child: const Text('Pull Now'),
                                  ),
                          ),
                          if (importState.isImporting &&
                              importState.statusMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const LinearProgressIndicator(),
                                  const SizedBox(height: 6),
                                  Text(
                                    importState.statusMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // About Section
          _buildSectionHeader('About', colorScheme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Savedex'),
                  subtitle: const Text(
                    'Version 0.0.1 • Reddit Saved Library Manager',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('How to get Reddit Takeout CSV'),
                  subtitle: const Text(
                    'Request your data from reddit.com/settings/data-request',
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportView()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  void _confirmClearDatabase(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.error,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Clear Database?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all saved posts, comments, collections, user notes, and the search index from your local library.\n\nThis is useful for resetting and testing imports from scratch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(savedItemRepositoryProvider).clearAllData();
              ref
                  .read(searchFilterViewModelProvider.notifier)
                  .clearAllFilters();
              ref.read(savedFeedPaginationProvider.notifier).clearFeed();
              ref.invalidate(savedFeedPaginationProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Database cleared successfully'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
              }
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  void _showApiCredentialsDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _RedditOAuthDialog());
  }
}

class _RedditOAuthDialog extends ConsumerStatefulWidget {
  const _RedditOAuthDialog();

  @override
  ConsumerState<_RedditOAuthDialog> createState() => _RedditOAuthDialogState();
}

class _RedditOAuthDialogState extends ConsumerState<_RedditOAuthDialog> {
  late final TextEditingController _clientIdController;
  late final TextEditingController _redirectUriController;
  late final TextEditingController _userAgentController;

  bool _isConnecting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsViewModelProvider);
    _clientIdController = TextEditingController(
      text: settings.redditClientId ?? '',
    );
    _redirectUriController = TextEditingController(
      text: settings.redditRedirectUri ?? '',
    );
    _userAgentController = TextEditingController(
      text: settings.userAgent ?? '',
    );

    if (settings.isAuthenticatedWithOAuth && settings.redditUsername == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final apiService = ref.read(redditApiServiceProvider);
          final userResult = await apiService.fetchMyUsername();
          if (userResult.username != null && mounted) {
            ref
                .read(settingsViewModelProvider.notifier)
                .setRedditUsername(userResult.username);
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _redirectUriController.dispose();
    _userAgentController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthorize() async {
    if (_isConnecting) return;
    final clientId = _clientIdController.text.trim();
    final redirectUri = _redirectUriController.text.trim();

    if (clientId.isEmpty || redirectUri.isEmpty) {
      setState(() {
        _errorMessage =
            'Please enter both OAuth Client ID and Redirect URI first.';
        _successMessage = null;
      });
      return;
    }

    final authUrl = RedditApiService.buildAuthorizationUrl(
      clientId: clientId,
      redirectUri: redirectUri,
    );

    await _launchAndroidCustomTab(authUrl, redirectUri);
  }

  Future<void> _launchAndroidCustomTab(
    String authUrl,
    String redirectUri,
  ) async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final parsed = Uri.tryParse(redirectUri);
      final scheme = (parsed != null && parsed.scheme.isNotEmpty)
          ? parsed.scheme
          : 'savedex';

      final callbackUrl = await RedditAuthService.authenticateWithCustomTab(
        authUrl: authUrl,
        redirectUri: redirectUri,
        callbackScheme: scheme,
      );

      final code = RedditApiService.parseCodeFromRedirectUrl(callbackUrl);
      if (code != null && code.isNotEmpty) {
        if (mounted) {
          await _exchangeCode(code, isInternal: true);
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Could not find authorization code in callback URL.';
            _isConnecting = false;
          });
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' || e.code == 'CANCELLED') {
        if (mounted) {
          setState(() {
            _errorMessage = 'Authorization was canceled.';
            _isConnecting = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Custom Tab failed (${e.code}). Try copying the authorization URL below.';
            _isConnecting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Custom Tab error: $e';
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _copyAuthUrl() async {
    final clientId = _clientIdController.text.trim();
    final redirectUri = _redirectUriController.text.trim();

    if (clientId.isEmpty || redirectUri.isEmpty) {
      setState(
        () => _errorMessage =
            'Please enter both OAuth Client ID and Redirect URI first.',
      );
      return;
    }

    final authUrl = RedditApiService.buildAuthorizationUrl(
      clientId: clientId,
      redirectUri: redirectUri,
    );

    await Clipboard.setData(ClipboardData(text: authUrl));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Authorization URL copied to clipboard!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _exchangeCode(String code, {bool isInternal = false}) async {
    if (!isInternal && _isConnecting) return;

    final clientId = _clientIdController.text.trim();
    final redirectUri = _redirectUriController.text.trim();
    final userAgent = _userAgentController.text.trim();

    if (clientId.isEmpty || redirectUri.isEmpty || userAgent.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'OAuth Client ID, Redirect URI, and User Agent must all be provided.';
          _successMessage = null;
          _isConnecting = false;
        });
      }
      return;
    }

    if (!_isConnecting) {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
        _successMessage = null;
      });
    }

    try {
      final apiService = ref.read(redditApiServiceProvider);
      final tokenResult = await apiService.exchangeAuthorizationCode(
        code: code,
        clientId: clientId,
        redirectUri: redirectUri,
        userAgent: userAgent,
      );

      if (tokenResult != null) {
        // Save credentials
        ref
            .read(settingsViewModelProvider.notifier)
            .updateRedditCredentials(
              clientId: clientId,
              redirectUri: redirectUri,
              userAgent: userAgent,
            );

        // Save OAuth tokens
        ref
            .read(settingsViewModelProvider.notifier)
            .setOAuthTokens(
              accessToken: tokenResult.accessToken,
              refreshToken: tokenResult.refreshToken,
              expiresIn: tokenResult.expiresIn,
            );

        // Fetch and persist username
        String usernameInfo = '';
        try {
          final userResult = await apiService.fetchMyUsername();
          if (userResult.username != null) {
            ref
                .read(settingsViewModelProvider.notifier)
                .setRedditUsername(userResult.username);
            usernameInfo = ' as u/${userResult.username}';
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _successMessage =
                'Successfully authenticated with Reddit OAuth$usernameInfo!';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Token exchange failed. Please verify that your Client ID matches the app, Redirect URI is identical, and the code was not already used.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error during token exchange: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _saveCredentials() {
    ref
        .read(settingsViewModelProvider.notifier)
        .updateRedditCredentials(
          clientId: _clientIdController.text,
          redirectUri: _redirectUriController.text,
          userAgent: _userAgentController.text,
        );
    Navigator.of(context).pop();
  }

  Widget _buildTextFields() {
    return Column(
      children: [
        TextField(
          controller: _clientIdController,
          decoration: InputDecoration(
            labelText: 'OAuth Client ID',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            suffixIcon: _clientIdController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () =>
                        setState(() => _clientIdController.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _redirectUriController,
          decoration: InputDecoration(
            labelText: 'Redirect URI',
            prefixIcon: const Icon(Icons.link_rounded, size: 20),
            suffixIcon: _redirectUriController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () =>
                        setState(() => _redirectUriController.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userAgentController,
          decoration: InputDecoration(
            labelText: 'User Agent',
            prefixIcon: const Icon(Icons.devices_rounded, size: 20),
            suffixIcon: _userAgentController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () =>
                        setState(() => _userAgentController.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsViewModelProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isConnected = settings.isAuthenticatedWithOAuth;
    final hasUnsavedChanges =
        _clientIdController.text != (settings.redditClientId ?? '') ||
        _redirectUriController.text != (settings.redditRedirectUri ?? '') ||
        _userAgentController.text != (settings.userAgent ?? '');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              color: colorScheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Reddit API & OAuth',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.redditUsername != null
                                  ? 'u/${settings.redditUsername}'
                                  : 'OAuth Connected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'OAuth Active',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(settingsViewModelProvider.notifier)
                              .clearOAuthAuth();
                          setState(() {
                            _successMessage = null;
                            _errorMessage = null;
                          });
                        },
                        child: const Text(
                          'Disconnect',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
                    leading: Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      'API Credentials',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      hasUnsavedChanges
                          ? 'Unsaved changes'
                          : 'Client ID, Redirect URI and User Agent',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: hasUnsavedChanges
                            ? colorScheme.error
                            : colorScheme.outline,
                      ),
                    ),
                    children: [
                      _buildTextFields(),
                      if (hasUnsavedChanges && RedditAuthService.isAndroid) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handleAuthorize,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text(
                              'Authorize again with New Credentials',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enter your Reddit OAuth Client ID and Redirect URI to authorize.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildTextFields(),
                const SizedBox(height: 16),
                if (RedditAuthService.isAndroid) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              (_clientIdController.text.trim().isEmpty ||
                                  _redirectUriController.text.trim().isEmpty ||
                                  _isConnecting)
                              ? null
                              : _handleAuthorize,
                          icon: _isConnecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.open_in_browser_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _isConnecting
                                ? 'Connecting...'
                                : 'Authorize with Reddit',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Copy Auth URL',
                        onPressed:
                            (_clientIdController.text.trim().isEmpty ||
                                _redirectUriController.text.trim().isEmpty)
                            ? null
                            : _copyAuthUrl,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                ],
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_successMessage != null && !isConnected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isConnected && !hasUnsavedChanges ? 'Close' : 'Cancel'),
        ),
        if (hasUnsavedChanges || !isConnected)
          FilledButton(
            onPressed: _saveCredentials,
            child: const Text('Save Credentials'),
          ),
      ],
    );
  }
}

class _ImageCacheTile extends StatefulWidget {
  const _ImageCacheTile();

  @override
  State<_ImageCacheTile> createState() => _ImageCacheTileState();
}

class _ImageCacheTileState extends State<_ImageCacheTile> {
  int? _cacheSizeBytes;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  static int _computeDirectorySizeSync(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;
    var size = 0;
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File) {
          size += entity.lengthSync();
        }
      }
    } catch (_) {}
    return size;
  }

  Future<void> _loadCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDirPath = p.join(tempDir.path, cacheImageFolderName);
      final size = await Isolate.run(
        () => _computeDirectorySizeSync(cacheDirPath),
      );
      if (mounted) {
        setState(() {
          _cacheSizeBytes = size;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cacheSizeBytes = 0;
          _isLoading = false;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  Future<void> _confirmClearCache() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Clear Image Cache?'),
          ],
        ),
        content: const Text(
          'This will remove temporary image files cached on your device. '
          'Your saved posts and notes will not be affected, and images will reload from the web when viewed again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _clearCache();
    }
  }

  Future<void> _clearCache() async {
    if (_isClearing) return;
    setState(() => _isClearing = true);

    try {
      await clearDiskCachedImages();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _loadCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image cache cleared successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not clear image cache: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = _cacheSizeBytes ?? 0;
    final hasCache = size > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.image_outlined,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      title: const Text(
        'Image Cache',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        _isLoading
            ? 'Calculating cache size...'
            : '${_formatBytes(size)} temporary media on disk',
      ),
      trailing: _isClearing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : OutlinedButton(
              onPressed: hasCache ? _confirmClearCache : null,
              child: const Text('Clear'),
            ),
    );
  }
}
