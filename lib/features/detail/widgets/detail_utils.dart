import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';
import 'package:savedex/shared/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openRedditUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Could not open invalid Reddit link',
        isError: true,
      );
    }
    return;
  }

  try {
    if (!await ExternalUrlLauncher.launch(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Could not open Reddit link: $e',
          isError: true,
        );
      }
    }
  }
}
