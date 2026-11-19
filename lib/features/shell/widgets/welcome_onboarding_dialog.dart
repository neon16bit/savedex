import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';
import 'package:savedex/features/settings/settings_view.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/shared/widgets/widgets.dart';

Future<void> showWelcomeOnboardingDialog(BuildContext context) async {
  final shouldConfigure = await showFrostedDialog<bool>(
    context: context,
    builder: (ctx) => const WelcomeOnboardingDialog(),
  );

  if (shouldConfigure == true && context.mounted) {
    SettingsView.showApiCredentialsDialog(context);
  }
}

class WelcomeOnboardingDialog extends ConsumerWidget {
  const WelcomeOnboardingDialog({super.key});

  Future<void> _launchUrl(String url) async {
    try {
      await ExternalUrlLauncher.launch(Uri.parse(url));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final isApiConfigured =
        settings.isAuthenticatedWithOAuth ||
        (settings.redditClientId != null &&
            settings.redditClientId!.trim().isNotEmpty);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.35,
    );

    return FrostedAlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: SavedexLogo(
              size: 24,
              filled: false,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Welcome to Savedex',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingSection(
                icon: Icons.vpn_key_outlined,
                title: 'Reddit API Setup Required',
                body: Text.rich(
                  TextSpan(
                    style: bodyStyle,
                    children: [
                      const TextSpan(
                        text: 'Configure your Reddit API credentials to use Savedex. See ',
                      ),
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
                      const TextSpan(text: ' for where to get them.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _OnboardingSection(
                icon: Icons.bolt_rounded,
                title: 'Sign in with Reddit',
                body: Text(
                  'Logging in with Reddit speeds up metadata fetching and pulls up to your last 1,000 saves.',
                  style: bodyStyle,
                ),
              ),
              const SizedBox(height: 14),
              _OnboardingSection(
                icon: Icons.folder_zip_outlined,
                title: 'Reddit Takeout',
                body: Text.rich(
                  TextSpan(
                    style: bodyStyle,
                    children: [
                      const TextSpan(
                        text: 'For full history beyond 1,000 saves, request your data at ',
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: _InlineLinkText(
                          label: 'reddit.com/settings/data-request',
                          onTap: () => _launchUrl(
                            'https://www.reddit.com/settings/data-request',
                          ),
                        ),
                      ),
                      const TextSpan(
                        text: ' and import the ZIP/CSV in Import & Sync.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(isApiConfigured ? 'Close' : 'Later'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: Icon(
            isApiConfigured ? Icons.check_rounded : Icons.vpn_key_rounded,
            size: 18,
          ),
          label: Text(
            isApiConfigured ? 'API Configured' : 'Configure Reddit API',
          ),
        ),
      ],
    );
  }
}

class _OnboardingSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;

  const _OnboardingSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        body,
      ],
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
