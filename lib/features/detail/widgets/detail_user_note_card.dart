import 'package:material_ui/material_ui.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class DetailUserNoteCard extends StatelessWidget {
  final String note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const DetailUserNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onDelete,
  });

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showFrostedDialog<bool>(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Clear note?'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 2.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Clear note',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _confirmClear(context),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
