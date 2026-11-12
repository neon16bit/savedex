import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/features/search/search_viewmodel.dart';

class SortSheet extends ConsumerWidget {
  final SortOption? currentSort;
  final ValueChanged<SortOption>? onSortSelected;
  final Set<SortOption> excludedOptions;

  const SortSheet({
    super.key,
    this.currentSort,
    this.onSortSelected,
    this.excludedOptions = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSort =
        currentSort ??
        ref.watch(searchFilterViewModelProvider.select((f) => f.sortOption));
    final options = SortOption.values
        .where((o) => !excludedOptions.contains(o))
        .toList();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Sort Saved Items',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = selectedSort == option;

                    return Material(
                      color: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (onSortSelected != null) {
                            onSortSelected!(option);
                          } else {
                            ref
                                .read(searchFilterViewModelProvider.notifier)
                                .setSortOption(option);
                          }
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getSortIcon(option),
                                size: 20,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.savedOrderDesc:
      case SortOption.savedOrderAsc:
        return Icons.bookmark_added_rounded;
      case SortOption.createdDateDesc:
      case SortOption.createdDateAsc:
        return Icons.access_time_rounded;
      case SortOption.scoreDesc:
      case SortOption.scoreAsc:
        return Icons.arrow_upward_rounded;
      case SortOption.commentsDesc:
        return Icons.chat_bubble_outline_rounded;
      case SortOption.subredditAsc:
      case SortOption.subredditDesc:
        return Icons.forum_outlined;
      case SortOption.authorAsc:
      case SortOption.authorDesc:
        return Icons.person_outline_rounded;
      case SortOption.titleAsc:
        return Icons.sort_by_alpha_rounded;
    }
  }
}
