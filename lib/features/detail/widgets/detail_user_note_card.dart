import 'package:flutter/material.dart';

class DetailUserNoteCard extends StatelessWidget {
  final String note;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const DetailUserNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.05),
          colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sticky_note_2_rounded,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'NOTE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    if (onDelete != null)
                      Tooltip(
                        message: 'Clear note',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: onDelete,
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Edit note',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
