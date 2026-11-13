import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';

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
    final textTheme = theme.textTheme;
    final bodyMedium = textTheme.bodyMedium;
    final bodyStyle = bodyMedium?.copyWith(
      height: isComment ? 1.45 : 1.55,
      fontSize: isComment ? 13.5 : 14.5,
    );

    return SelectionArea(
      child: MarkdownBody(
        data: data,
        onTapLink: (text, href, title) async {
          if (href == null) return;
          final uri = Uri.tryParse(href.trim());
          if (uri == null || !uri.hasScheme) return;
          try {
            await ExternalUrlLauncher.launch(uri);
          } catch (_) {}
        },
        styleSheet: MarkdownStyleSheet(
          a: const TextStyle(color: Colors.blue),
          p: bodyStyle,
          pPadding: EdgeInsets.zero,
          code: bodyMedium?.copyWith(
            backgroundColor: theme.cardTheme.color,
            fontFamily: 'monospace',
            fontSize: (bodyMedium.fontSize ?? 14.0) * 0.85,
          ),
          h1: textTheme.headlineSmall,
          h1Padding: EdgeInsets.zero,
          h2: textTheme.titleLarge,
          h2Padding: EdgeInsets.zero,
          h3: textTheme.titleMedium,
          h3Padding: EdgeInsets.zero,
          h4: textTheme.bodyLarge,
          h4Padding: EdgeInsets.zero,
          h5: textTheme.bodyLarge,
          h5Padding: EdgeInsets.zero,
          h6: textTheme.bodyLarge,
          h6Padding: EdgeInsets.zero,
          em: const TextStyle(fontStyle: FontStyle.italic),
          strong: const TextStyle(fontWeight: FontWeight.bold),
          del: const TextStyle(decoration: TextDecoration.lineThrough),
          blockquote: bodyStyle?.copyWith(color: colorScheme.onSurfaceVariant),
          img: bodyMedium,
          checkbox: bodyMedium?.copyWith(color: theme.primaryColor),
          blockSpacing: 8.0,
          listIndent: 24.0,
          listBullet: bodyMedium,
          listBulletPadding: const EdgeInsets.only(right: 4),
          tableHead: const TextStyle(fontWeight: FontWeight.w600),
          tableBody: bodyMedium,
          tableHeadAlign: TextAlign.center,
          tablePadding: const EdgeInsets.only(bottom: 4.0),
          tableBorder: TableBorder.all(color: theme.dividerColor),
          tableColumnWidth: const FlexColumnWidth(),
          tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          tableCellsDecoration: const BoxDecoration(),
          blockquotePadding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.6),
                width: 3,
              ),
            ),
          ),
          codeblockPadding: const EdgeInsets.all(8.0),
          codeblockDecoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(2.0),
          ),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(width: 5.0, color: theme.dividerColor),
            ),
          ),
        ),
      ),
    );
  }
}
