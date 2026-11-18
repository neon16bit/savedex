import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:savedex/data/repositories/settings_repository.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class RateLimitsView extends ConsumerWidget {
  const RateLimitsView({super.key});

  Future<void> _confirmReset(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showFrostedDialog<bool>(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset Rate Limits?'),
        content: const Text(
          'Restore all concurrency and request delay settings back to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      viewModel.resetRateLimitsToDefaults();
      showAppSnackBar(context, 'Rate limits reset to defaults');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Limits & Concurrency'),
        elevation: 0,
        scrolledUnderElevation: 2,
        actions: [
          TextButton(
            onPressed: () => _confirmReset(context, viewModel),
            child: const Text('Reset'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _buildSectionHeader('Reddit Metadata', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _RateLimitSliderTile(
                  icon: Icons.bolt_rounded,
                  title: 'OAuth Parallel Workers',
                  subtitle: 'Concurrent workers when downloading metadata while signed in with Reddit',
                  value: settings.oauthEnrichmentWorkers,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  formatValue: (v) => '$v ${v == 1 ? 'worker' : 'workers'}',
                  onCommit: viewModel.setOauthEnrichmentWorkers,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _RateLimitSliderTile(
                  icon: Icons.timer_outlined,
                  title: 'OAuth Request Delay',
                  subtitle: 'Pause per worker between authenticated Reddit metadata requests',
                  value: settings.oauthEnrichmentDelayMs,
                  min: 0,
                  max: 1000,
                  divisions: 40,
                  formatValue: (v) => '$v ms',
                  onCommit: viewModel.setOauthEnrichmentDelayMs,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _RateLimitSliderTile(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'Anonymous Request Delay',
                  subtitle: 'Delay between metadata requests without user OAuth login',
                  value: settings.anonymousRequestDelayMs,
                  min: 200,
                  max: 3000,
                  divisions: 28,
                  formatValue: (v) => '$v ms',
                  onCommit: viewModel.setAnonymousRequestDelayMs,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _RateLimitSliderTile(
                  icon: Icons.tune_rounded,
                  title: 'Subreddit & User Metadata Delay',
                  subtitle: 'Delay between subreddit and author profile info requests',
                  value: settings.subredditMetadataDelayMs,
                  min: 0,
                  max: 2000,
                  divisions: 40,
                  formatValue: (v) => '$v ms',
                  onCommit: viewModel.setSubredditMetadataDelayMs,
                ),
              ],
            ),
          ),
          _buildSectionHeader('Archive Recovery', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _RateLimitSliderTile(
                  icon: Icons.pause_circle_outline_rounded,
                  title: 'Archive Batch Cooldown',
                  subtitle: 'Cooldown between 10-item batches when recovering removed items',
                  value: settings.archiveBatchDelayMs,
                  min: 0,
                  max: 5000,
                  divisions: 50,
                  formatValue: (v) => '$v ms',
                  onCommit: viewModel.setArchiveBatchDelayMs,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _RateLimitSliderTile(
                  icon: Icons.archive_outlined,
                  title: 'PullPush Request Delay',
                  subtitle: 'Delay between requests to PullPush archive API',
                  value: settings.pullPushRequestDelayMs,
                  min: 0,
                  max: 3000,
                  divisions: 60,
                  formatValue: (v) => '$v ms',
                  onCommit: viewModel.setPullPushRequestDelayMs,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _RateLimitSliderTile(
                  icon: Icons.ac_unit_rounded,
                  title: 'Arctic Shift Request Delay',
                  subtitle:
                      'Delay between requests to Arctic Shift archive API',
                  value: settings.arcticShiftRequestDelayMs,
                  min: 0,
                  max: 3000,
                  divisions: 60,
                  formatValue: (v) => '$v ms',
                  onCommit: viewModel.setArcticShiftRequestDelayMs,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Lower delays speed up fetching but increase the chance of HTTP 429 rate-limit throttling. Defaults: ${UserSettings.defaultOauthEnrichmentWorkers} workers, ${UserSettings.defaultOauthEnrichmentDelayMs}ms OAuth, ${UserSettings.defaultAnonymousRequestDelayMs}ms anonymous, ${UserSettings.defaultArchiveBatchDelayMs}ms batch cooldown.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.35),
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
}

class _RateLimitSliderTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final String Function(int value) formatValue;
  final void Function(int value) onCommit;

  const _RateLimitSliderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onCommit,
  });

  @override
  State<_RateLimitSliderTile> createState() => _RateLimitSliderTileState();
}

class _RateLimitSliderTileState extends State<_RateLimitSliderTile> {
  double? _dragValue;

  @override
  void didUpdateWidget(covariant _RateLimitSliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _dragValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentDouble = (_dragValue ?? widget.value.toDouble()).clamp(
      widget.min.toDouble(),
      widget.max.toDouble(),
    );
    final displayInt = currentDouble.round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(widget.icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.65,
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            widget.formatValue(displayInt),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: currentDouble,
            min: widget.min.toDouble(),
            max: widget.max.toDouble(),
            divisions: widget.divisions,
            label: widget.formatValue(displayInt),
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              final rounded = val.round().clamp(widget.min, widget.max);
              setState(() {
                _dragValue = null;
              });
              widget.onCommit(rounded);
            },
          ),
        ],
      ),
    );
  }
}
