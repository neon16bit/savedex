import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class DetailBottomBar extends StatelessWidget {
  final SavedItem item;
  final VoidCallback onOpenReddit;
  final void Function(String? currentNote) onEditNote;

  const DetailBottomBar({
    super.key,
    required this.item,
    required this.onOpenReddit,
    required this.onEditNote,
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
                    final note = ref.watch(
                      itemNoteProvider((
                        id: item.id,
                        initialNote: item.userNote,
                      )),
                    );
                    final hasNote = note != null && note.trim().isNotEmpty;
                    final colorScheme = Theme.of(context).colorScheme;
                    return IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: hasNote
                            ? colorScheme.primaryContainer
                            : null,
                        foregroundColor: hasNote
                            ? colorScheme.onPrimaryContainer
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        hasNote
                            ? Icons.sticky_note_2_rounded
                            : Icons.note_add_outlined,
                        size: 20,
                      ),
                      tooltip: hasNote ? 'Edit Note' : 'Add Note',
                      onPressed: () => onEditNote(note),
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
