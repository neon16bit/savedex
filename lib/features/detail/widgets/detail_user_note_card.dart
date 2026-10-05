import 'package:flutter/material.dart';

class DetailUserNoteCard extends StatelessWidget {
  final String note;
  final VoidCallback onTap;
  final bool isCompact;

  const DetailUserNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 12,
            vertical: isCompact ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(
              alpha: isCompact ? 0.2 : 0.18,
            ),
            borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
            border: Border(
              left: BorderSide(
                color: colorScheme.primary,
                width: isCompact ? 3 : 3.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.sticky_note_2_rounded,
                  size: isCompact ? 13 : 16,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(width: isCompact ? 6 : 8),
              Expanded(
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13,
                    fontStyle: FontStyle.italic,
                    height: isCompact ? 1.3 : 1.35,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: isCompact ? 13 : 16,
                color: colorScheme.primary.withValues(
                  alpha: isCompact ? 0.7 : 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
