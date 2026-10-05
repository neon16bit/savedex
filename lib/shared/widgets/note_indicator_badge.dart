import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';

class NoteIndicatorBadge extends ConsumerWidget {
  final String itemId;
  final String? initialNote;

  const NoteIndicatorBadge({super.key, required this.itemId, this.initialNote});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(
      itemNoteProvider((id: itemId, initialNote: initialNote)),
    );
    if (note == null || note.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sticky_note_2_rounded,
              size: 16,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
