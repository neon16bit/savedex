import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';
import 'package:savedex/core/utils/responsive_layout.dart';
import 'package:savedex/data/repositories/settings_repository.dart';
import 'package:savedex/data/services/github_update_service.dart';
import 'package:savedex/theme/app_theme.dart';
import 'package:savedex/data/services/reddit_api_service.dart';
import 'package:savedex/data/services/reddit_auth_service.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/import_export/backup_restore_view.dart';
import 'package:savedex/features/import_export/import_view.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/settings/rate_limits_view.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/settings/subreddit_user_metadata_view.dart';
import 'package:savedex/features/settings/widgets/about_dialog.dart';
import 'package:savedex/features/settings/widgets/update_dialog.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/features/shell/widgets/welcome_onboarding_dialog.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isDesktop ? 20 : null,
        title: const Text('Settings'),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = isDesktop
              ? ResponsiveLayout.centeredHorizontalPadding(
                  constraints.maxWidth,
                  maxContentWidth: kSettingsMaxWidth,
                  minPadding: 24,
                )
              : 16.0;
          return ListView(
            primary: false,
            padding: EdgeInsets.fromLTRB(
              hPad,
              12,
              hPad,
              isDesktop ? 32 : 104,
            ),
            children: [
          _buildSectionHeader('Account & Sync', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    settings.isAuthenticatedWithOAuth
                        ? Icons.verified_user_outlined
                        : Icons.vpn_key_outlined,
                    color: settings.isAuthenticatedWithOAuth
                        ? colorScheme.primary
                        : null,
                  ),
                  title: const Text(
                    'Reddit Account',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    settings.isAuthenticatedWithOAuth
                        ? (settings.redditUsername != null
                              ? 'Connected as u/${settings.redditUsername}'
                              : 'Connected via OAuth')
                        : (settings.redditClientId != null &&
                              settings.redditClientId!.isNotEmpty)
                        ? 'Client ID configured (tap to authorize)'
                        : 'Connect OAuth to sync saved items',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showApiCredentialsDialog(context),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.swap_vert_rounded),
                  title: const Text(
                    'Import & Sync',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Pull via Reddit API or import Takeout CSV/ZIP',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportView()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text(
                    'Pull-to-Refresh Pages',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    'Fetch ${settings.pullToRefreshPages} ${settings.pullToRefreshPages == 1 ? 'page' : 'pages'} (up to ${_formatNumber(settings.pullToRefreshPages * 100)} items) on Saved feed refresh',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showPullToRefreshPagesDialog(
                    context,
                    settings.pullToRefreshPages,
                    viewModel,
                  ),
                ),
              ],
            ),
          ),

          _buildSectionHeader('Appearance', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Builder(
                  builder: (tileContext) => ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text(
                      'Theme Flavor',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(settings.themeFlavor.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          settings.themeFlavor.label,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () => _openThemeFlavorMenu(
                      tileContext,
                      settings.themeFlavor,
                      viewModel,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text(
                    'Pure Black',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Use pitch black backgrounds in dark mode',
                  ),
                  value: settings.isAmoled,
                  onChanged: (val) => viewModel.toggleAmoled(val),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _buildAccentColorSection(
                  context,
                  settings: settings,
                  viewModel: viewModel,
                  colorScheme: colorScheme,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.tonality_outlined),
                  title: const Text(
                    'Pass Through Material Seed',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Generate Material 3 tonal surfaces from accent color',
                  ),
                  value: settings.useCatppuccinSeed,
                  onChanged: (val) => viewModel.toggleCatppuccinSeed(val),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.blur_on_outlined),
                  title: const Text(
                    'Frosted Glass Effects',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Translucent blur on bars, sheets, dialogs, and controls',
                  ),
                  value: settings.enableFrostedEffects,
                  onChanged: (val) => viewModel.toggleFrostedEffects(val),
                ),
              ],
            ),
          ),

          _buildSectionHeader('Playback', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_off_outlined),
                  title: const Text(
                    'Start Videos Muted',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text('Mute video playback by default'),
                  value: settings.startVideosMuted,
                  onChanged: (val) => viewModel.toggleStartVideosMuted(val),
                ),
              ],
            ),
          ),

          _buildSectionHeader('Metadata & Recovery', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.sync_outlined),
                  title: const Text(
                    'Auto-Fetch on Import',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Download post metadata right after CSV import',
                  ),
                  value: settings.autoEnrichOnImport,
                  onChanged: (val) => viewModel.toggleAutoEnrich(val),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
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

                    final formattedCount = _formatNumber(pendingCount);

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
                          ? 'Paused (${enrichState.processedCount}/$total · $percent%)'
                          : 'Downloading (${enrichState.processedCount}/$total · $percent%)';
                    } else if (pendingCount > 0) {
                      subtitle =
                          '$formattedCount ${pendingCount == 1 ? "item needs" : "items need"} metadata';
                    } else {
                      subtitle = 'All items have complete metadata';
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.auto_awesome_outlined,
                            color: pendingCount > 0 || isEnriching
                                ? colorScheme.primary
                                : null,
                          ),
                          title: const Text(
                            'Post & Comment Metadata',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(subtitle),
                          trailing: FilledButton.tonal(
                            onPressed: (pendingCount == 0 || isEnriching)
                                ? null
                                : () => enrichVm.startEnrichment(),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            child: Text(
                              isEnriching
                                  ? (enrichState.isPaused
                                        ? 'Paused'
                                        : 'Running...')
                                  : 'Fetch',
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: isEnriching
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    56,
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
                const Divider(height: 1, indent: 56, endIndent: 16),
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
                          'All checked ($unavailableCount unavailable in archive)';
                    } else if (count == 0 && unavailableCount == 0) {
                      subtitle = 'No failed or removed items need recovery';
                    } else if (unavailableCount > 0) {
                      subtitle =
                          '$count available ($unavailableCount unavailable in archive)';
                    } else {
                      subtitle = '$count items eligible for archive recovery';
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.archive_outlined,
                            color: isRunning ? colorScheme.primary : null,
                          ),
                          title: const Text(
                            'Recover Removed Content',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
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
                                    final confirm = await showFrostedDialog<bool>(
                                      context: context,
                                      builder: (ctx) => FrostedAlertDialog(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                child: Text(
                                  isStarting
                                      ? 'Preparing...'
                                      : isRunning
                                      ? 'Running...'
                                      : 'Recover',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isRunning)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
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
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text(
                    'Archive Source',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(settings.archiveBackend.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showArchiveBackendDialog(
                    context,
                    settings.archiveBackend,
                    viewModel,
                  ),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final isBusy = ref.watch(
                      subredditUserMetadataProvider.select((s) => s.isAnyBusy),
                    );
                    return ListTile(
                      leading: Icon(
                        Icons.tune_rounded,
                        color: isBusy ? colorScheme.primary : null,
                      ),
                      title: const Text(
                        'Subreddit & User Metadata',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        isBusy
                            ? 'Refreshing subreddit & user metadata...'
                            : 'Missing icons, info, and force refresh',
                      ),
                      trailing: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubredditUserMetadataView(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.speed_rounded),
                  title: const Text(
                    'Rate Limits & Concurrency',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Workers, request delays, and archive cooldowns',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RateLimitsView()),
                    );
                  },
                ),
              ],
            ),
          ),

          _buildSectionHeader('Backup & Restore', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.settings_backup_restore_rounded),
              title: const Text(
                'Backup & Restore',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
              subtitle: const Text(
                'Create a snapshots, restore library, or export JSON/CSV',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupRestoreView()),
                );
              },
            ),
          ),

          _buildSectionHeader('Storage & Data', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const _ImageCacheTile(),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    'Clear Saved Database',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: colorScheme.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Delete all saved posts, comments, collections, and index',
                  ),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => _confirmClearDatabase(context, ref),
                    child: const Text('Clear All'),
                  ),
                ),
              ],
            ),
          ),

          _buildSectionHeader('About', colorScheme),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text(
                    'Setup Guide',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: const Text(
                    'How to configure Reddit API & import saves',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showWelcomeOnboardingDialog(context),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                const _CheckForUpdatesTile(),
                const Divider(height: 1, indent: 56, endIndent: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final packageInfo = ref.watch(packageInfoProvider);
                    final version = normalizeVersionString(
                      packageInfo?.version ?? '',
                    );
                    return ListTile(
                      leading: SavedexLogo(
                        size: 28,
                        filled: false,
                        color: colorScheme.onSurface,
                      ),
                      title: const Text(
                        'About Savedex',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        version.isNotEmpty
                            ? 'Version $version • Reddit Saved Library Manager'
                            : 'Reddit Saved Library Manager',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          showAboutSavedexDialog(context, version: version),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
          );
        },
      ),
    );
  }

  void _showArchiveBackendDialog(
    BuildContext context,
    ArchiveBackend current,
    SettingsViewModel viewModel,
  ) {
    showFrostedDialog<void>(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Archive Source'),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
        content: RadioGroup<ArchiveBackend>(
          groupValue: current,
          onChanged: (val) {
            if (val != null) {
              viewModel.setArchiveBackend(val);
            }
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final backend in ArchiveBackend.values)
                RadioListTile<ArchiveBackend>(
                  value: backend,
                  title: Text(
                    backend.label,
                    style: const TextStyle(fontSize: 14.5),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPullToRefreshPagesDialog(
    BuildContext context,
    int currentPages,
    SettingsViewModel viewModel,
  ) {
    var selectedPages = currentPages.clamp(1, 10);
    showFrostedDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;
          return FrostedAlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Pull-to-Refresh Pages'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how many pages to pull when refreshing the Saved feed. Manual sync elsewhere still fetches all 10 pages.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '$selectedPages ${selectedPages == 1 ? 'page' : 'pages'} (up to ${_formatNumber(selectedPages * 100)} items)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Slider(
                  value: selectedPages.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$selectedPages',
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPages = value.round();
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1 page (100)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '10 pages (1,000)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  viewModel.setPullToRefreshPages(selectedPages);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openThemeFlavorMenu(
    BuildContext tileContext,
    ThemeFlavor currentFlavor,
    SettingsViewModel viewModel,
  ) async {
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null ||
        overlay == null ||
        !renderBox.attached ||
        !overlay.attached) {
      return;
    }

    RelativeRect computePosition() {
      final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
      final rect = topLeft & renderBox.size;
      return RelativeRect.fromRect(
        Rect.fromLTWH(rect.right - 16, rect.top + 8, 16, rect.height - 8),
        Offset.zero & overlay.size,
      );
    }

    final colorScheme = Theme.of(tileContext).colorScheme;
    final selected = await showFrostedMenu<ThemeFlavor>(
      context: tileContext,
      position: computePosition(),
      positionBuilder: (_, fallback) {
        if (!tileContext.mounted || !renderBox.attached || !overlay.attached) {
          return fallback;
        }
        return computePosition();
      },
      initialValue: currentFlavor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        for (final flavor in ThemeFlavor.values)
          PopupMenuItem<ThemeFlavor>(
            value: flavor,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    flavor.label,
                    style: TextStyle(
                      fontWeight: currentFlavor == flavor
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: currentFlavor == flavor
                          ? colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                if (currentFlavor == flavor) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
      ],
    );

    if (selected != null) {
      viewModel.setThemeFlavor(selected);
    }
  }

  Widget _buildAccentColorSection(
    BuildContext context, {
    required UserSettings settings,
    required SettingsViewModel viewModel,
    required ColorScheme colorScheme,
  }) {
    final effectiveBrightness = switch (settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final activePalette = effectiveBrightness == Brightness.light
        ? settings.catppuccinLightFlavor.palette
        : settings.catppuccinDarkFlavor.palette;
    final activeAccent = settings.effectiveAccentFor(effectiveBrightness);
    final dynamicAccentColor =
        DynamicAccentScope.of(context, effectiveBrightness) ??
        activePalette.getColorByName(activeAccent);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Text(
            'Accent Color',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAccentSwatchItem(
                label: 'Dynamic',
                isSelected: settings.useDynamicColor,
                colorScheme: colorScheme,
                decoration: BoxDecoration(
                  color: dynamicAccentColor,
                  shape: BoxShape.circle,
                  border: settings.useDynamicColor
                      ? Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.9),
                          width: 2.5,
                        )
                      : null,
                ),
                onTap: () => viewModel.toggleDynamicColor(true),
              ),
              ...CatppuccinPalette.accentNames.map((name) {
                final accentColor = activePalette.getColorByName(name);
                final isSelected =
                    !settings.useDynamicColor &&
                    activeAccent.toLowerCase() == name.toLowerCase();
                return _buildAccentSwatchItem(
                  label: name,
                  isSelected: isSelected,
                  colorScheme: colorScheme,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: colorScheme.onSurface.withValues(alpha: 0.9),
                            width: 2.5,
                          )
                        : null,
                  ),
                  onTap: () => viewModel.setCatppuccinAccent(name),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccentSwatchItem({
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
    required BoxDecoration decoration,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label accent color',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: SizedBox(
            width: 54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 38,
                  height: 38,
                  decoration: decoration,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
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

  static String _formatNumber(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  void _confirmClearDatabase(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showFrostedDialog(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
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
          'This will permanently delete all saved posts, comments, collections, user notes, and the search index from your local library.',
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
              ref.read(enrichmentViewModelProvider.notifier).stopEnrichment();
              ref.read(archiveRecoveryStateProvider.notifier).stop();
              await ref.read(savedItemRepositoryProvider).clearAllData();
              ref
                  .read(searchFilterViewModelProvider.notifier)
                  .clearAllFilters();
              ref.read(savedFeedPaginationProvider.notifier).clearFeed();
              ref.invalidate(savedFeedPaginationProvider);
              ref.invalidate(enrichmentViewModelProvider);
              ref.invalidate(archiveRecoveryStateProvider);
              ref.invalidate(subredditUserMetadataProvider);
              if (context.mounted) {
                showAppSnackBar(context, 'Database cleared successfully');
              }
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  static void showApiCredentialsDialog(BuildContext context) {
    showFrostedDialog(
      context: context,
      builder: (ctx) => const _RedditOAuthDialog(),
    );
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
  bool _isWaitingForDesktopBrowser = false;
  int _authAttemptId = 0;
  int? _desktopAuthSessionId;
  String? _errorMessage;

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
        if (!mounted) return;
        final attemptId = _authAttemptId;
        try {
          final apiService = ref.read(redditApiServiceProvider);
          final userResult = await apiService.fetchMyUsername();
          if (!mounted || attemptId != _authAttemptId) return;
          if (!ref.read(settingsViewModelProvider).isAuthenticatedWithOAuth) {
            return;
          }
          if (userResult.username != null) {
            ref
                .read(settingsViewModelProvider.notifier)
                .setRedditUsername(userResult.username);
          }
        } catch (_) {}
      });
    }
  }

  void _abortPendingAuth() {
    _authAttemptId++;
    final sessionId = _desktopAuthSessionId;
    _desktopAuthSessionId = null;
    if (sessionId != null) {
      unawaited(
        RedditAuthService.cancelPendingDesktopAuth(sessionId: sessionId),
      );
    }
  }

  @override
  void dispose() {
    _abortPendingAuth();
    _clientIdController.dispose();
    _redirectUriController.dispose();
    _userAgentController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    try {
      await ExternalUrlLauncher.launch(Uri.parse(url));
    } catch (_) {}
  }

  Future<void> _handleAuthorize() async {
    if (_isConnecting) return;
    final clientId = _clientIdController.text.trim();
    final redirectUri = _redirectUriController.text.trim();
    final userAgent = _userAgentController.text.trim();

    if (clientId.isEmpty || redirectUri.isEmpty || userAgent.isEmpty) {
      setState(() {
        _errorMessage =
            'Please enter OAuth Client ID, Redirect URI, and User Agent first.';
      });
      return;
    }

    final attemptId = ++_authAttemptId;
    final state = RedditApiService.generateOAuthState();
    final authUrl = RedditApiService.buildAuthorizationUrl(
      clientId: clientId,
      redirectUri: redirectUri,
      state: state,
      compact: RedditAuthService.isAndroid,
    );

    if (RedditAuthService.isAndroid) {
      await _launchAndroidCustomTab(
        authUrl,
        clientId: clientId,
        redirectUri: redirectUri,
        userAgent: userAgent,
        expectedState: state,
        attemptId: attemptId,
      );
    } else if (RedditAuthService.isDesktop) {
      if (RedditAuthService.parseCustomScheme(redirectUri) != null) {
        await _launchDesktopCustomSchemeAuth(
          authUrl,
          clientId: clientId,
          redirectUri: redirectUri,
          userAgent: userAgent,
          expectedState: state,
          attemptId: attemptId,
        );
      } else {
        setState(() {
          _errorMessage = 'Redirect URI must use a valid custom URL scheme.';
        });
      }
    }
  }

  Future<void> _handleAuthCallback(
    String callbackUrl, {
    required String clientId,
    required String redirectUri,
    required String userAgent,
    required String expectedState,
    required int attemptId,
  }) async {
    if (!mounted || attemptId != _authAttemptId) return;
    final callbackUri = Uri.tryParse(callbackUrl.replaceAll('#_', ''));
    final returnedState = callbackUri?.queryParameters['state'];
    if (returnedState != expectedState) {
      setState(() {
        _isConnecting = false;
        _errorMessage = 'OAuth state mismatch. Please try authorizing again.';
      });
      return;
    }

    final error = callbackUri?.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      setState(() {
        _isConnecting = false;
        _errorMessage = error == 'access_denied'
            ? 'Authorization was canceled.'
            : 'Reddit authorization failed ($error).';
      });
      return;
    }

    final code = callbackUri?.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      await _exchangeCode(
        code,
        clientId: clientId,
        redirectUri: redirectUri,
        userAgent: userAgent,
        attemptId: attemptId,
      );
    } else {
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Could not find authorization code in callback URL.';
      });
    }
  }

  Future<void> _launchAndroidCustomTab(
    String authUrl, {
    required String clientId,
    required String redirectUri,
    required String userAgent,
    required String expectedState,
    required int attemptId,
  }) async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
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

      await _handleAuthCallback(
        callbackUrl,
        clientId: clientId,
        redirectUri: redirectUri,
        userAgent: userAgent,
        expectedState: expectedState,
        attemptId: attemptId,
      );
    } on PlatformException catch (e) {
      if (!mounted || attemptId != _authAttemptId) return;
      if (e.code == 'CANCELED' || e.code == 'CANCELLED') {
        setState(() {
          _errorMessage = 'Authorization was canceled.';
          _isConnecting = false;
        });
      } else {
        final detail = (e.message != null && e.message!.trim().isNotEmpty)
            ? ': ${e.message}'
            : '';
        setState(() {
          _errorMessage =
              'Custom Tab failed (${e.code})$detail. Please try again.';
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (!mounted || attemptId != _authAttemptId) return;
      setState(() {
        _errorMessage = 'Custom Tab error: $e';
        _isConnecting = false;
      });
    }
  }

  Future<void> _launchDesktopCustomSchemeAuth(
    String authUrl, {
    required String clientId,
    required String redirectUri,
    required String userAgent,
    required String expectedState,
    required int attemptId,
  }) async {
    if (_isConnecting) return;
    final sessionId = RedditAuthService.allocateDesktopAuthSessionId();
    _desktopAuthSessionId = sessionId;
    setState(() {
      _isConnecting = true;
      _isWaitingForDesktopBrowser = true;
      _errorMessage = null;
    });

    try {
      final callbackUrl =
          await RedditAuthService.authenticateWithDesktopCustomScheme(
            authUrl: authUrl,
            redirectUri: redirectUri,
            sessionId: sessionId,
          );

      if (_desktopAuthSessionId == sessionId) {
        _desktopAuthSessionId = null;
      }
      if (!mounted || attemptId != _authAttemptId) return;
      setState(() => _isWaitingForDesktopBrowser = false);

      await _handleAuthCallback(
        callbackUrl,
        clientId: clientId,
        redirectUri: redirectUri,
        userAgent: userAgent,
        expectedState: expectedState,
        attemptId: attemptId,
      );
    } on PlatformException catch (e) {
      if (_desktopAuthSessionId == sessionId) {
        _desktopAuthSessionId = null;
      }
      if (!mounted || attemptId != _authAttemptId) return;
      setState(() {
        _isWaitingForDesktopBrowser = false;
        _isConnecting = false;
        switch (e.code) {
          case 'CANCELED':
          case 'CANCELLED':
            _errorMessage = 'Authorization was canceled.';
          case 'TIMEOUT':
            _errorMessage = 'Authorization timed out waiting for the browser callback. Please try again.';
          case 'INVALID_REDIRECT_URI':
            _errorMessage = e.message ?? 'Invalid Redirect URI.';
          case 'SCHEME_REGISTER_FAILED':
            _errorMessage =
                e.message ??
                'Could not register the custom URL scheme on this device.';
          case 'BROWSER_LAUNCH_FAILED':
            _errorMessage =
                e.message ?? 'Could not open browser automatically.';
          default:
            _errorMessage = e.message ?? 'Authorization failed (${e.code}).';
        }
      });
    } on MissingPluginException {
      if (_desktopAuthSessionId == sessionId) {
        _desktopAuthSessionId = null;
      }
      if (!mounted || attemptId != _authAttemptId) return;
      setState(() {
        _isWaitingForDesktopBrowser = false;
        _isConnecting = false;
        _errorMessage = 'Desktop handler is not available in this build.';
      });
    } catch (e) {
      if (_desktopAuthSessionId == sessionId) {
        _desktopAuthSessionId = null;
      }
      if (!mounted || attemptId != _authAttemptId) return;
      setState(() {
        _isWaitingForDesktopBrowser = false;
        _isConnecting = false;
        _errorMessage = 'Desktop authorization error: $e';
      });
    }
  }

  void _cancelDesktopAuth() {
    _abortPendingAuth();
    setState(() {
      _isWaitingForDesktopBrowser = false;
      _isConnecting = false;
      _errorMessage = 'Authorization was canceled.';
    });
  }

  Future<void> _exchangeCode(
    String code, {
    required String clientId,
    required String redirectUri,
    required String userAgent,
    required int attemptId,
  }) async {
    if (clientId.isEmpty || redirectUri.isEmpty || userAgent.isEmpty) {
      if (mounted && attemptId == _authAttemptId) {
        setState(() {
          _errorMessage = 'OAuth Client ID, Redirect URI, and User Agent must all be provided.';
          _isConnecting = false;
        });
      }
      return;
    }

    if (!_isConnecting) {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });
    }

    try {
      final apiService = ref.read(redditApiServiceProvider);
      final settingsNotifier = ref.read(settingsViewModelProvider.notifier);
      final tokenResult = await apiService.exchangeAuthorizationCode(
        code: code,
        clientId: clientId,
        redirectUri: redirectUri,
        userAgent: userAgent,
      );

      if (!mounted || attemptId != _authAttemptId) return;

      if (tokenResult != null) {
        final refreshToken = tokenResult.refreshToken?.trim();
        if (refreshToken == null || refreshToken.isEmpty) {
          setState(() {
            _errorMessage = 'Reddit did not return a permanent refresh token. Please try authorizing again.';
          });
          return;
        }

        // Save credentials
        settingsNotifier.updateRedditCredentials(
          clientId: clientId,
          redirectUri: redirectUri,
          userAgent: userAgent,
        );
        if (_clientIdController.text != clientId) {
          _clientIdController.text = clientId;
        }
        if (_redirectUriController.text != redirectUri) {
          _redirectUriController.text = redirectUri;
        }
        if (_userAgentController.text != userAgent) {
          _userAgentController.text = userAgent;
        }

        // Save OAuth tokens
        settingsNotifier.setOAuthTokens(
          accessToken: tokenResult.accessToken,
          refreshToken: refreshToken,
          expiresIn: tokenResult.expiresIn,
        );

        // Fetch and persist username
        try {
          final userResult = await apiService.fetchMyUsername();
          if (!mounted || attemptId != _authAttemptId) return;
          if (userResult.username != null) {
            settingsNotifier.setRedditUsername(userResult.username);
          }
        } catch (_) {}
      } else {
        setState(() {
          _errorMessage = 'Token exchange failed. Please verify that your Client ID matches the app, Redirect URI is identical, and the code was not already used.';
        });
      }
    } catch (e) {
      if (mounted && attemptId == _authAttemptId) {
        setState(() {
          _errorMessage = 'Error during token exchange: $e';
        });
      }
    } finally {
      if (mounted && attemptId == _authAttemptId) {
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
          enabled: !_isConnecting,
          decoration: InputDecoration(
            labelText: 'OAuth Client ID',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            suffixIcon: (_clientIdController.text.isNotEmpty && !_isConnecting)
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
          enabled: !_isConnecting,
          decoration: InputDecoration(
            labelText: 'Redirect URI',
            prefixIcon: const Icon(Icons.link_rounded, size: 20),
            suffixIcon:
                (_redirectUriController.text.isNotEmpty && !_isConnecting)
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
          enabled: !_isConnecting,
          decoration: InputDecoration(
            labelText: 'User Agent',
            prefixIcon: const Icon(Icons.devices_rounded, size: 20),
            suffixIcon: (_userAgentController.text.isNotEmpty && !_isConnecting)
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
        _clientIdController.text.trim() != (settings.redditClientId ?? '') ||
        _redirectUriController.text.trim() !=
            (settings.redditRedirectUri ?? '') ||
        _userAgentController.text.trim() != (settings.userAgent ?? '');

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _abortPendingAuth();
        }
      },
      child: FrostedAlertDialog(
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
                          onPressed: _isConnecting
                              ? null
                              : () {
                                  _authAttemptId++;
                                  ref
                                      .read(settingsViewModelProvider.notifier)
                                      .clearOAuthAuth();
                                  setState(() {
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
                        if ((hasUnsavedChanges || _isConnecting) &&
                            RedditAuthService.isSupported) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isConnecting
                                      ? null
                                      : _handleAuthorize,
                                  icon: _isConnecting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                  label: Text(
                                    _isWaitingForDesktopBrowser
                                        ? 'Waiting for browser...'
                                        : (_isConnecting
                                              ? 'Connecting...'
                                              : 'Authorize again with New Credentials'),
                                  ),
                                ),
                              ),
                              if (_isWaitingForDesktopBrowser) ...[
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _cancelDesktopAuth,
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: 'See ',
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: _InlineLinkText(
                                        label: 'GitHub README',
                                        onTap: () => _launchUrl(
                                          'https://github.com/neon16bit/savedex#where-do-i-get-a-client-id',
                                        ),
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' for how to get your Client ID, Redirect URI, and User Agent.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTextFields(),
                  const SizedBox(height: 16),
                  if (RedditAuthService.isSupported) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                (_clientIdController.text.trim().isEmpty ||
                                    _redirectUriController.text
                                        .trim()
                                        .isEmpty ||
                                    _userAgentController.text.trim().isEmpty ||
                                    _isConnecting)
                                ? null
                                : _handleAuthorize,
                            icon: _isConnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.open_in_browser_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _isWaitingForDesktopBrowser
                                  ? 'Waiting for browser...'
                                  : (_isConnecting
                                        ? 'Connecting...'
                                        : 'Authorize with Reddit'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (_isWaitingForDesktopBrowser) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _cancelDesktopAuth,
                            child: const Text('Cancel'),
                          ),
                        ],
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              (isConnected && !hasUnsavedChanges) || _isConnecting
                  ? 'Close'
                  : 'Cancel',
            ),
          ),
          if (hasUnsavedChanges || !isConnected)
            FilledButton(
              onPressed: _isConnecting ? null : _saveCredentials,
              child: const Text('Save Credentials'),
            ),
        ],
      ),
    );
  }
}

class _InlineLinkText extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InlineLinkText({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      link: true,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              height: 1.35,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageCacheTile extends ConsumerStatefulWidget {
  const _ImageCacheTile();

  @override
  ConsumerState<_ImageCacheTile> createState() => _ImageCacheTileState();
}

class _ImageCacheTileState extends ConsumerState<_ImageCacheTile> {
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

  static Future<int> _computeDirectorySizeInIsolate(String dirPath) async {
    try {
      return await Isolate.run(() => _computeDirectorySizeSync(dirPath));
    } catch (_) {
      return _computeDirectorySizeSync(dirPath);
    }
  }

  Future<void> _loadCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDirPath = p.join(tempDir.path, cacheImageFolderName);
      final size = await _computeDirectorySizeInIsolate(cacheDirPath);
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

    final confirmed = await showFrostedDialog<bool>(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
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
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(tempDir.path, cacheImageFolderName));
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _loadCacheSize();
      if (mounted) {
        showAppSnackBar(context, 'Image cache cleared successfully');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not clear image cache: $e',
          isError: true,
          duration: const Duration(seconds: 3),
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
    ref.listen<int>(selectedShellTabProvider, (previous, next) {
      if (next == 2 && previous != 2) {
        _loadCacheSize();
      }
    });

    final size = _cacheSizeBytes ?? 0;
    final hasCache = size > 0;

    return ListTile(
      leading: const Icon(Icons.image_outlined),
      title: const Text(
        'Image Cache',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
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
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: hasCache ? _confirmClearCache : null,
              child: const Text('Clear'),
            ),
    );
  }
}

class _CheckForUpdatesTile extends ConsumerStatefulWidget {
  const _CheckForUpdatesTile();

  @override
  ConsumerState<_CheckForUpdatesTile> createState() =>
      _CheckForUpdatesTileState();
}

class _CheckForUpdatesTileState extends ConsumerState<_CheckForUpdatesTile> {
  bool _isChecking = false;

  Future<void> _checkUpdate() async {
    if (_isChecking) return;

    final packageInfo = ref.read(packageInfoProvider);
    final version = normalizeVersionString(packageInfo?.version ?? '');
    if (version.isEmpty) {
      showAppSnackBar(
        context,
        'Current app version is unavailable.',
        isError: true,
      );
      return;
    }

    setState(() => _isChecking = true);
    try {
      final result = await GithubUpdateService.checkForUpdate(
        currentVersion: version,
      );
      if (!mounted) return;

      switch (result.status) {
        case UpdateCheckStatus.updateAvailable:
          final update = result.update;
          if (update != null) {
            setState(() => _isChecking = false);
            await showAppUpdateDialog(context, update);
          } else {
            showAppSnackBar(
              context,
              'Could not check for updates. Check your connection.',
              isError: true,
            );
          }
        case UpdateCheckStatus.upToDate:
          showAppSnackBar(context, 'Savedex is up to date (v$version)');
        case UpdateCheckStatus.noReleases:
          showAppSnackBar(context, 'No releases published on GitHub yet.');
        case UpdateCheckStatus.error:
          showAppSnackBar(
            context,
            result.errorMessage ??
                'Could not check for updates. Check your connection.',
            isError: true,
          );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to check for updates.', isError: true);
      }
    } finally {
      if (mounted && _isChecking) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = ref.watch(packageInfoProvider);
    final version = normalizeVersionString(packageInfo?.version ?? '');

    return ListTile(
      leading: const Icon(Icons.system_update_rounded),
      title: const Text(
        'Check for updates',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Text(version.isNotEmpty ? 'v$version (GitHub)' : 'GitHub'),
      trailing: _isChecking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: _isChecking ? null : _checkUpdate,
    );
  }
}
