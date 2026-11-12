import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/shared/widgets/collection_form_dialog.dart';

const List<int> kCollectionPresetColors = [
  0xFFFF4500, // reddit orange
  0xFFE53935, // crimson
  0xFFFFA000, // amber
  0xFF00C853, // emerald
  0xFF00B4AB, // teal
  0xFF1E88E5, // blue
  0xFF5E35B1, // purple
  0xFFE91E63, // pink
  0xFF607D8B, // grey
];

Future<void> showCollectionPickerSheet(BuildContext context, String itemId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => CollectionPickerSheet(itemId: itemId),
  );
}

class CollectionPickerSheet extends ConsumerWidget {
  final String itemId;

  const CollectionPickerSheet({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allCollectionsAsync = ref.watch(allCollectionsProvider);
    final itemCollectionsAsync = ref.watch(itemCollectionsProvider(itemId));
    final feedNotifier = ref.read(savedFeedPaginationProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.collections_bookmark_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collections',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Organize this item into custom groups',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () =>
                        _openCreateCollectionDialog(context, ref, itemId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: allCollectionsAsync.when(
                data: (allCollections) {
                  if (allCollections.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }

                  final assignedIds =
                      itemCollectionsAsync.asData?.value
                          .map((c) => c.id)
                          .toSet() ??
                      const <int>{};

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: allCollections.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 64, endIndent: 20),
                    itemBuilder: (context, index) {
                      final col = allCollections[index];
                      final isAssigned = assignedIds.contains(col.id);
                      final colColor = Color(col.colorValue);

                      return InkWell(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await feedNotifier.setItemCollectionMembership(
                            itemId: itemId,
                            collectionId: col.id,
                            assign: !isAssigned,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colColor.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.bookmark_rounded,
                                    size: 18,
                                    color: colColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      col.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                    ),
                                    if (col.description != null &&
                                        col.description!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        col.description!.trim(),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              height: 1.3,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: isAssigned,
                                activeColor: colColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (val) async {
                                  HapticFeedback.lightImpact();
                                  await feedNotifier
                                      .setItemCollectionMembership(
                                        itemId: itemId,
                                        collectionId: col.id,
                                        assign: !isAssigned,
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error loading collections: $e')),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.collections_bookmark_outlined,
                size: 38,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No collections yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a collection to group and organize your favorite posts and comments.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  _openCreateCollectionDialog(context, ref, itemId),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Collection'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateCollectionDialog(
    BuildContext context,
    WidgetRef ref,
    String assignItemId,
  ) {
    return showCollectionFormDialog(context, assignItemId: assignItemId);
  }
}
