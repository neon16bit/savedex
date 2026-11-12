import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/shared/widgets/collection_picker_sheet.dart';

class CollectionBadge extends StatelessWidget {
  final Collection collection;
  final VoidCallback? onTap;
  final double fontSize;
  final double iconSize;

  const CollectionBadge({
    super.key,
    required this.collection,
    this.onTap,
    this.fontSize = 10,
    this.iconSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(collection.colorValue);
    final textColor = color.computeLuminance() > 0.55
        ? Colors.black87
        : Colors.white;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_rounded, size: iconSize, color: textColor),
          const SizedBox(width: 3.5),
          Flexible(
            child: Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return badge;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: badge,
      ),
    );
  }
}

class CollectionBadgeRow extends ConsumerWidget {
  final String itemId;
  final List<Collection> initialCollections;
  final ValueChanged<Collection>? onCollectionTap;
  final bool isInteractive;
  final bool leadingSpacing;
  final int maxBadges;

  const CollectionBadgeRow({
    super.key,
    required this.itemId,
    this.initialCollections = const [],
    this.onCollectionTap,
    this.isInteractive = true,
    this.leadingSpacing = true,
    this.maxBadges = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overrideCollections = ref.watch(
      itemCollectionsOverrideProvider.select((m) => m[itemId]),
    );
    final collections = overrideCollections ?? initialCollections;

    if (collections.isEmpty) return const SizedBox.shrink();

    final visibleCount = collections.length > maxBadges
        ? maxBadges
        : collections.length;
    final extraCount = collections.length - visibleCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visibleCount; i++) ...[
          if (i > 0 || leadingSpacing) const SizedBox(width: 6),
          Flexible(
            child: CollectionBadge(
              collection: collections[i],
              onTap: isInteractive
                  ? () {
                      if (onCollectionTap != null) {
                        onCollectionTap!(collections[i]);
                      } else {
                        showCollectionPickerSheet(context, itemId);
                      }
                    }
                  : null,
            ),
          ),
        ],
        if (extraCount > 0) ...[
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: isInteractive
                  ? () {
                      if (onCollectionTap != null) {
                        onCollectionTap!(collections.first);
                      } else {
                        showCollectionPickerSheet(context, itemId);
                      }
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
