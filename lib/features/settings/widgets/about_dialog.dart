import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';
import 'package:savedex/shared/widgets/widgets.dart';

Future<void> showAboutSavedexDialog(
  BuildContext context, {
  required String version,
}) {
  return showFrostedDialog<void>(
    context: context,
    builder: (_) => _AboutSavedexDialog(version: version),
  );
}

class _AboutSavedexDialog extends StatelessWidget {
  static const String _applicationLegalese =
      'Licensed under the GPL-3.0 License';

  final String version;

  const _AboutSavedexDialog({required this.version});

  static Widget _buildAppIcon(ColorScheme colorScheme) {
    return SavedexLogo(size: 48, color: colorScheme.primary);
  }

  static Future<void> _openRepo(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    void showError() {
      if (messenger == null) return;
      showAppSnackBarOnMessenger(
        messenger,
        message: 'Could not open link',
        colorScheme: colorScheme,
        isDark: isDark,
        isError: true,
      );
    }

    try {
      final launched = await ExternalUrlLauncher.launch(
        Uri.parse(AppConstants.githubRepoUrl),
      );
      if (!launched) showError();
    } catch (_) {
      showError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FrostedAlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppIcon(colorScheme),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (version.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Version $version',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        _applicationLegalese,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Reddit saved library manager for browsing, organizing, searching, and backing up your saved posts and comments locally.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: SvgPicture.asset(
                  'assets/icons/github.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                label: const Text('github.com/neon16bit/savedex'),
                onPressed: () => _openRepo(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: AppConstants.appName,
            applicationVersion: version.isNotEmpty ? 'Version $version' : null,
            applicationIcon: _buildAppIcon(colorScheme),
            applicationLegalese: _applicationLegalese,
          ),
          child: const Text('View licenses'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
