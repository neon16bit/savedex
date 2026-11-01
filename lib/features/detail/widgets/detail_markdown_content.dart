import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailMarkdownContent extends StatelessWidget {
  final String data;
  final bool isComment;

  const DetailMarkdownContent({
    super.key,
    required this.data,
    this.isComment = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(
          height: isComment ? 1.45 : 1.55,
          fontSize: isComment ? 13.5 : 14.5,
        ),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: isComment ? 1.45 : 1.55,
          fontSize: isComment ? 13.5 : 14.5,
        ),
        blockquotePadding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.6),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}
