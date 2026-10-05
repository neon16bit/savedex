import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';

class ItemNoteButton extends ConsumerWidget {
  final String itemId;
  final String? initialNote;
  final void Function(String? currentNote) onEditNote;
  final double iconSize;
  final bool showLabel;

  const ItemNoteButton({
    super.key,
    required this.itemId,
    this.initialNote,
    required this.onEditNote,
    this.iconSize = 18,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(
      itemNoteProvider((id: itemId, initialNote: initialNote)),
    );
    final hasNote = note != null && note.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    if (showLabel) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onEditNote(note),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: hasNote
                  ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasNote
                      ? Icons.sticky_note_2_rounded
                      : Icons.note_add_outlined,
                  size: 14,
                  color: hasNote
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  hasNote ? 'Edit Note' : 'Add Note',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasNote
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: hasNote ? 'Edit Note' : 'Add Note',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () => onEditNote(note),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              hasNote ? Icons.sticky_note_2_rounded : Icons.note_add_outlined,
              size: iconSize,
              color: hasNote
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
