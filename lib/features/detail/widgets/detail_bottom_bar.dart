import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class DetailBottomBar extends ConsumerWidget {
  final SavedItem item;
  final VoidCallback onOpenReddit;
  final void Function(String? currentNote)? onEditNote;

  const DetailBottomBar({
    super.key,
    required this.item,
    required this.onOpenReddit,
    this.onEditNote,
  });

  void _share(BuildContext context) {
    Clipboard.setData(ClipboardData(text: item.fullPermalink));
    showAppSnackBar(context, 'Link copied to clipboard');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enableFrosted = watchFrostedEffects(ref);
    final buttonShadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SizedBox(
          height: 48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [buttonShadow],
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: onOpenReddit,
                    icon: RedditIcon(size: 18, color: colorScheme.onPrimary),
                    label: const Text(
                      'Open on Reddit',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, _) {
                  final collectionsAsync = ref.watch(
                    itemCollectionsProvider(item.id),
                  );
                  final collections =
                      collectionsAsync.asData?.value ?? item.collections;
                  final hasCollections = collections.isNotEmpty;

                  return _FrostedDetailActionButton(
                    enableFrosted: enableFrosted,
                    isDark: isDark,
                    isActive: hasCollections,
                    icon: hasCollections
                        ? Icons.bookmark_added_rounded
                        : Icons.collections_bookmark_outlined,
                    tooltip: hasCollections
                        ? 'Collections (${collections.length})'
                        : 'Add to Collection',
                    onPressed: () =>
                        showCollectionPickerSheet(context, item.id),
                  );
                },
              ),
              const SizedBox(width: 8),
              _FrostedDetailActionButton(
                enableFrosted: enableFrosted,
                isDark: isDark,
                icon: Icons.share_outlined,
                tooltip: 'Share',
                onPressed: () => _share(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrostedDetailActionButton extends StatelessWidget {
  final bool enableFrosted;
  final bool isDark;
  final bool isActive;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FrostedDetailActionButton({
    required this.enableFrosted,
    required this.isDark,
    this.isActive = false,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseSurface = isActive
        ? colorScheme.primaryContainer
        : (isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainerHighest);
    final surfaceColor = enableFrosted
        ? baseSurface.withValues(
            alpha: isDark ? kFrostedDarkAlpha : kFrostedLightAlpha,
          )
        : baseSurface;
    final borderColor = isActive
        ? colorScheme.primary.withValues(
            alpha: enableFrosted ? (isDark ? 0.45 : 0.38) : 0.50,
          )
        : colorScheme.outlineVariant.withValues(
            alpha: isDark
                ? (enableFrosted ? 0.40 : 0.55)
                : (enableFrosted ? 0.35 : 0.45),
          );
    final foregroundColor = isActive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final radius = BorderRadius.circular(16);

    return FrostedSurface(
      width: 48,
      height: 48,
      enableBlur: enableFrosted,
      borderRadius: radius,
      surfaceColor: surfaceColor,
      borderColor: borderColor,
      borderWidth: 1.1,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Center(child: Icon(icon, size: 20, color: foregroundColor)),
          ),
        ),
      ),
    );
  }
}
