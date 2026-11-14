import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';

class ItemStarButton extends ConsumerWidget {
  final SavedItem item;
  final VoidCallback? onToggle;

  const ItemStarButton({super.key, required this.item, this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap:
            onToggle ??
            () => ref.read(savedViewModelProvider.notifier).toggleStar(item),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            item.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 22,
            color: item.isStarred
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
