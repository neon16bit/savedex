import 'package:flutter/material.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';

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
      onSave: (note) => actions.updateNote(itemId, note),
    ),
  );
}

void showConfirmDeleteDialog(
  BuildContext context,
  ItemDetailActions actions,
  String itemId, {
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
            await actions.deleteItem(itemId);
            if (context.mounted) {
              if (onDeletedSelf != null) {
                onDeletedSelf();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isComment
                          ? 'Comment removed from saved items'
                          : 'Item removed from saved items',
                    ),
                    behavior: SnackBarBehavior.floating,
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

class _NoteDialog extends StatefulWidget {
  final String? initialNote;
  final ValueChanged<String> onSave;

  const _NoteDialog({this.initialNote, required this.onSave});

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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Personal Note',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Add personal notes or reminders about this post...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            widget.onSave(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
