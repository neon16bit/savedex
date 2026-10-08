import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class DetailBottomBar extends StatelessWidget {
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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: SizedBox(
          height: 48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: Consumer(
                  builder: (context, ref, _) {
                    final collectionsAsync = ref.watch(
                      itemCollectionsProvider(item.id),
                    );
                    final collections =
                        collectionsAsync.asData?.value ?? item.collections;
                    final hasCollections = collections.isNotEmpty;
                    final colorScheme = Theme.of(context).colorScheme;

                    return IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: hasCollections
                            ? colorScheme.primaryContainer
                            : null,
                        foregroundColor: hasCollections
                            ? colorScheme.onPrimaryContainer
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        hasCollections
                            ? Icons.bookmark_added_rounded
                            : Icons.collections_bookmark_outlined,
                        size: 20,
                      ),
                      tooltip: hasCollections
                          ? 'Collections (${collections.length})'
                          : 'Add to Collection',
                      onPressed: () =>
                          showCollectionPickerSheet(context, item.id),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.share_outlined, size: 20),
                  tooltip: 'Share',
                  onPressed: () => _share(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
