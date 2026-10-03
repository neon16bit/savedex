import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/search/search_viewmodel.dart';

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterViewModelProvider);
    final viewModel = ref.read(searchFilterViewModelProvider.notifier);
    final subredditsAsync = ref.watch(availableSubredditsProvider);
    final authorsAsync = ref.watch(availableAuthorsWithCountsProvider);
    final flairsAsync = ref.watch(availableFlairsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Library',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (filter.hasActiveFilters)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => viewModel.clearAllFilters(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Reset All',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _buildSectionTitle('Type', colorScheme),
                    SegmentedButton<ItemType?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('All')),
                        ButtonSegment(
                          value: ItemType.post,
                          label: Text('Posts'),
                          icon: Icon(Icons.article_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ItemType.comment,
                          label: Text('Comments'),
                          icon: Icon(Icons.chat_bubble_outline, size: 16),
                        ),
                      ],
                      selected: {filter.itemType},
                      onSelectionChanged: (set) =>
                          viewModel.setItemType(set.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Status & Flags', colorScheme),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          avatar: Icon(
                            filter.isStarred == true
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: filter.isStarred == true
                                ? Colors.amber
                                : null,
                            size: 18,
                          ),
                          label: const Text('Starred Only'),
                          selected: filter.isStarred == true,
                          onSelected: (val) => viewModel.toggleStarredOnly(val),
                        ),
                        FilterChip(
                          label: const Text('NSFW Only'),
                          selected: filter.isNsfw == true,
                          onSelected: (val) =>
                              viewModel.setNsfwFilter(val ? true : null),
                        ),
                        FilterChip(
                          label: const Text('SFW Only'),
                          selected: filter.isNsfw == false,
                          onSelected: (val) =>
                              viewModel.setNsfwFilter(val ? false : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Media Format', colorScheme),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMediaChip(
                          MediaType.image,
                          'Images',
                          Icons.image_outlined,
                          filter,
                          viewModel,
                        ),
                        _buildMediaChip(
                          MediaType.video,
                          'Videos',
                          Icons.videocam_outlined,
                          filter,
                          viewModel,
                        ),
                        _buildMediaChip(
                          MediaType.gallery,
                          'Galleries',
                          Icons.photo_library_outlined,
                          filter,
                          viewModel,
                        ),
                        _buildMediaChip(
                          MediaType.text,
                          'Self-Text',
                          Icons.text_snippet_outlined,
                          filter,
                          viewModel,
                        ),
                        _buildMediaChip(
                          MediaType.link,
                          'Links',
                          Icons.link_rounded,
                          filter,
                          viewModel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Creation Date Range', colorScheme),
                    _buildDatePresets(context, filter, viewModel, colorScheme),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Subreddits', colorScheme),
                    subredditsAsync.when(
                      data: (subreddits) {
                        if (subreddits.isEmpty) {
                          return Text(
                            'No subreddits available.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: subreddits.take(25).map((tuple) {
                            final name = tuple.$1;
                            final count = tuple.$2;
                            final isSelected = filter.selectedSubreddits
                                .contains(name);

                            return FilterChip(
                              label: Text('r/$name ($count)'),
                              selected: isSelected,
                              onSelected: (_) =>
                                  viewModel.toggleSubreddit(name),
                            );
                          }).toList(),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Authors', colorScheme),
                    authorsAsync.when(
                      data: (authors) {
                        if (authors.isEmpty) {
                          return Text(
                            'No authors available.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: authors.take(20).map((tuple) {
                            final author = tuple.$1;
                            final count = tuple.$2;
                            final isSelected = filter.selectedAuthors.contains(
                              author,
                            );

                            return FilterChip(
                              avatar: const Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                              ),
                              label: Text('u/$author ($count)'),
                              selected: isSelected,
                              onSelected: (_) => viewModel.toggleAuthor(author),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle('Flairs', colorScheme),
                    flairsAsync.when(
                      data: (flairs) {
                        if (flairs.isEmpty) {
                          return Text(
                            'No flairs available yet. Enrich posts to extract flairs.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: flairs.take(20).map((tuple) {
                            final flair = tuple.$1;
                            final count = tuple.$2;
                            final isSelected = filter.selectedFlairs.contains(
                              flair,
                            );

                            return FilterChip(
                              avatar: const Icon(Icons.sell_outlined, size: 14),
                              label: Text('$flair ($count)'),
                              selected: isSelected,
                              onSelected: (_) => viewModel.toggleFlair(flair),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMediaChip(
    MediaType type,
    String label,
    IconData icon,
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
  ) {
    final isSelected = filter.selectedMediaTypes.contains(type);
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => viewModel.toggleMediaType(type),
    );
  }

  Widget _buildDatePresets(
    BuildContext context,
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    final now = DateTime.now();
    final hasCustomRange =
        filter.dateRangeStart != null || filter.dateRangeEnd != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          label: const Text('Past 7 Days'),
          onPressed: () {
            viewModel.setDateRange(now.subtract(const Duration(days: 7)), now);
          },
        ),
        ActionChip(
          label: const Text('Past 30 Days'),
          onPressed: () {
            viewModel.setDateRange(now.subtract(const Duration(days: 30)), now);
          },
        ),
        ActionChip(
          label: const Text('Past 1 Year'),
          onPressed: () {
            viewModel.setDateRange(
              now.subtract(const Duration(days: 365)),
              now,
            );
          },
        ),
        FilterChip(
          label: Text(
            hasCustomRange
                ? '${filter.dateRangeStart != null ? "${filter.dateRangeStart!.month}/${filter.dateRangeStart!.day}/${filter.dateRangeStart!.year}" : "Start"} - ${filter.dateRangeEnd != null ? "${filter.dateRangeEnd!.month}/${filter.dateRangeEnd!.day}/${filter.dateRangeEnd!.year}" : "End"}'
                : 'Custom Range...',
          ),
          selected: hasCustomRange,
          onSelected: (_) async {
            final now = DateTime.now();
            final lastDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2005),
              lastDate: lastDate,
              initialDateRange: hasCustomRange
                  ? DateTimeRange(
                      start:
                          filter.dateRangeStart != null &&
                              !filter.dateRangeStart!.isAfter(lastDate)
                          ? filter.dateRangeStart!
                          : now.subtract(const Duration(days: 30)),
                      end:
                          filter.dateRangeEnd != null &&
                              !filter.dateRangeEnd!.isAfter(lastDate)
                          ? filter.dateRangeEnd!
                          : lastDate,
                    )
                  : null,
            );
            if (picked != null) {
              viewModel.setDateRange(picked.start, picked.end);
            }
          },
        ),
        if (hasCustomRange)
          ActionChip(
            avatar: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear Date'),
            onPressed: () => viewModel.clearDateRange(),
          ),
      ],
    );
  }
}
