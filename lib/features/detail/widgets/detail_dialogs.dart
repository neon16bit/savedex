import 'package:flutter/material.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';

void showNoteSnackBar(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;
  controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      action: onUndo != null
          ? SnackBarAction(
              label: 'Undo',
              onPressed: () {
                controller.close();
                onUndo();
              },
            )
          : null,
    ),
  );

  Future.delayed(duration, () {
    try {
      controller.close();
    } catch (_) {}
  });
}

void showEditNoteDialog(
  BuildContext context,
  ItemDetailActions actions,
  String itemId,
  String? currentNote,
) {
  showDialog(
    context: context,
    builder: (ctx) => _NoteDialog(
      initialNote: currentNote,
      onSave: (note) async {
        final cleanNote = (note == null || note.trim().isEmpty)
            ? null
            : note.trim();
        await actions.updateNote(itemId, cleanNote);
        if (context.mounted) {
          final isRemoved = cleanNote == null;
          showNoteSnackBar(
            context,
            message: isRemoved ? 'Note removed' : 'Note saved',
            onUndo:
                isRemoved &&
                    currentNote != null &&
                    currentNote.trim().isNotEmpty
                ? () => actions.updateNote(itemId, currentNote)
                : null,
          );
        }
      },
      onDelete: () async {
        await actions.updateNote(itemId, null);
        if (context.mounted) {
          showNoteSnackBar(
            context,
            message: 'Note removed',
            onUndo: currentNote != null && currentNote.trim().isNotEmpty
                ? () => actions.updateNote(itemId, currentNote)
                : null,
          );
        }
      },
    ),
  );
}

void showConfirmDeleteDialog(
  BuildContext context,
  ItemDetailActions? actions,
  String? itemId, {
  Future<void> Function()? onConfirmDelete,
  bool isComment = false,
  VoidCallback? onDeletedSelf,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(isComment ? 'Delete Comment?' : 'Delete Item?'),
      content: Text(
        isComment
            ? 'This will remove the comment from your Savedex library.'
            : 'This will remove the item from your Savedex library.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            if (actions != null && itemId != null) {
              await actions.deleteItem(itemId);
            } else if (onConfirmDelete != null) {
              await onConfirmDelete();
            }
            if (context.mounted) {
              if (onDeletedSelf != null) {
                onDeletedSelf();
              } else {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        isComment
                            ? 'Comment removed from saved items'
                            : 'Item removed from saved items',
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
              }
            }
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

Future<bool> showArchiveRefreshWarningDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Refresh archived item?'),
      content: const Text(
        'This item was recovered from the archive. Refreshing it may replace '
        'the recovered metadata with Reddit\'s current response, including '
        'deleted or removed content.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Refresh'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _NoteDialog extends StatefulWidget {
  final String? initialNote;
  final ValueChanged<String?> onSave;
  final VoidCallback? onDelete;

  const _NoteDialog({this.initialNote, required this.onSave, this.onDelete});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing =
        widget.initialNote != null && widget.initialNote!.trim().isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sticky_note_2_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Personal Note' : 'Add Personal Note',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 7,
          autofocus: true,
          style: const TextStyle(fontSize: 13.5, height: 1.45),
          decoration: InputDecoration(
            hintText: 'Write personal thoughts, key takeaways, or reminders...',
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
              fontSize: 13,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            if (isEditing)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete Note'),
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onDelete != null) {
                    widget.onDelete!();
                  } else {
                    widget.onSave(null);
                  }
                },
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                final trimmed = _controller.text.trim();
                Navigator.pop(context);
                widget.onSave(trimmed.isEmpty ? null : trimmed);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
