import 'package:flutter/material.dart';
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

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_rounded, size: iconSize, color: color),
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
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return badge;

    return GestureDetector(onTap: onTap, child: badge);
  }
}

class CollectionBadgeRow extends ConsumerWidget {
  final String itemId;
  final List<Collection> initialCollections;
  final ValueChanged<Collection>? onCollectionTap;
  final bool isInteractive;

  const CollectionBadgeRow({
    super.key,
    required this.itemId,
    this.initialCollections = const [],
    this.onCollectionTap,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(itemCollectionsProvider(itemId));
    final collections = collectionsAsync.asData?.value ?? initialCollections;

    if (collections.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final col in collections) ...[
          const SizedBox(width: 6),
          Flexible(
            child: CollectionBadge(
              collection: col,
              onTap: isInteractive
                  ? () {
                      if (onCollectionTap != null) {
                        onCollectionTap!(col);
                      } else {
                        showCollectionPickerSheet(context, itemId);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}
