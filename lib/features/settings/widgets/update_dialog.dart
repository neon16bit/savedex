import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';
import 'package:savedex/data/services/github_update_service.dart';
import 'package:savedex/shared/widgets/widgets.dart';

bool _isUpdateDialogOpen = false;

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo update,
) async {
  if (_isUpdateDialogOpen) return;
  try {
    _isUpdateDialogOpen = true;
    await showFrostedDialog<void>(
      context: context,
      builder: (_) => _AppUpdateDialog(update: update),
    );
  } finally {
    _isUpdateDialogOpen = false;
  }
}

class _AppUpdateDialog extends ConsumerStatefulWidget {
  final AppUpdateInfo update;

  const _AppUpdateDialog({required this.update});

  @override
  ConsumerState<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<_AppUpdateDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static Uri? _parseExternalUri(String? rawUrl, {bool requireHttps = false}) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    final isAllowed = requireHttps
        ? scheme == 'https'
        : (scheme == 'http' || scheme == 'https');
    return isAllowed ? uri : null;
  }

  static Future<void> _launchExternalUri(
    Uri? uri, {
    required ScaffoldMessengerState? messenger,
    required ColorScheme colorScheme,
    required bool isDark,
    String invalidMessage = 'Could not open invalid link',
    String failureMessage = 'Could not open link',
  }) async {
    void showError(String message) {
      if (messenger == null) return;
      showAppSnackBarOnMessenger(
        messenger,
        message: message,
        colorScheme: colorScheme,
        isDark: isDark,
        isError: true,
      );
    }

    if (uri == null) {
      showError(invalidMessage);
      return;
    }

    try {
      final launched = await ExternalUrlLauncher.launch(uri);
      if (!launched) {
        showError(failureMessage);
      }
    } catch (_) {
      showError(failureMessage);
    }
  }

  static MarkdownStyleSheet _buildMarkdownStyleSheet(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final baseBody =
        textTheme.bodyMedium ??
        TextStyle(fontSize: 14, color: colorScheme.onSurface);
    final bodyStyle = baseBody.copyWith(
      color: colorScheme.onSurface,
      fontSize: 13.5,
      height: 1.45,
    );
    final mutedStyle = bodyStyle.copyWith(color: colorScheme.onSurfaceVariant);

    return MarkdownStyleSheet(
      a: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: colorScheme.primary,
      ),
      p: bodyStyle,
      pPadding: EdgeInsets.zero,
      code: baseBody.copyWith(
        color: colorScheme.onSurface,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        fontFamily: 'monospace',
        fontSize: (baseBody.fontSize ?? 14.0) * 0.85,
      ),
      h1: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      h1Padding: const EdgeInsets.only(top: 4, bottom: 2),
      h2: bodyStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      h2Padding: const EdgeInsets.only(top: 4, bottom: 2),
      h3: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      h3Padding: const EdgeInsets.only(top: 2, bottom: 2),
      h4: bodyStyle.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
      h4Padding: EdgeInsets.zero,
      h5: bodyStyle.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
      h5Padding: EdgeInsets.zero,
      h6: mutedStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      h6Padding: EdgeInsets.zero,
      em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
      strong: bodyStyle.copyWith(fontWeight: FontWeight.w700),
      del: bodyStyle.copyWith(decoration: TextDecoration.lineThrough),
      blockquote: mutedStyle,
      img: bodyStyle,
      checkbox: bodyStyle.copyWith(color: colorScheme.primary),
      blockSpacing: 8.0,
      listIndent: 20.0,
      listBullet: bodyStyle,
      listBulletPadding: const EdgeInsets.only(right: 4),
      tableHead: bodyStyle.copyWith(fontWeight: FontWeight.w600),
      tableBody: bodyStyle,
      tableHeadAlign: TextAlign.center,
      tablePadding: const EdgeInsets.only(bottom: 4.0),
      tableBorder: TableBorder.all(color: colorScheme.outlineVariant),
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableCellsPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      tableCellsDecoration: const BoxDecoration(),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(width: 1, color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final changelog = update.changelog?.trim() ?? '';

    return FrostedAlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Update Available: v${update.latestVersion}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              'Current: v${update.currentVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      content: changelog.isEmpty
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 280),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectionArea(
                        child: MarkdownBody(
                          data: changelog,
                          listItemCrossAxisAlignment:
                              MarkdownListItemCrossAxisAlignment.start,
                          styleSheet: _buildMarkdownStyleSheet(theme),
                          imageBuilder: (_, _, alt) =>
                              (alt != null && alt.trim().isNotEmpty)
                              ? Text(
                                  alt.trim(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              : const SizedBox.shrink(),
                          onTapLink: (_, href, _) {
                            _launchExternalUri(
                              _parseExternalUri(href, requireHttps: true),
                              messenger: ScaffoldMessenger.maybeOf(context),
                              colorScheme: colorScheme,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () {
            ref
                .read(sharedPreferencesProvider)
                ?.setString(kLastDismissedUpdateKey, update.latestVersion);
            Navigator.of(context).pop();
          },
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final uri = _parseExternalUri(
              update.releaseUrl,
              requireHttps: true,
            );
            Navigator.of(context).pop();
            await _launchExternalUri(
              uri,
              messenger: messenger,
              colorScheme: colorScheme,
              isDark: isDark,
              invalidMessage: 'Could not open invalid release link',
              failureMessage: 'Could not open release link',
            );
          },
          child: const Text('View Release'),
        ),
      ],
    );
  }
}
