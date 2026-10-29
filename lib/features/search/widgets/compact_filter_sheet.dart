import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/search/search_viewmodel.dart';

enum _CompactFilterCategory {
  flags('Flags & Types', Icons.flag_outlined),
  media('Media', Icons.perm_media_outlined),
  subreddits('Subreddits', Icons.tag_rounded),
  authors('Authors', Icons.person_outline_rounded),
  flairs('Flairs', Icons.sell_outlined);

  final String label;
  final IconData icon;
  const _CompactFilterCategory(this.label, this.icon);
}

class CompactFilterSheet extends ConsumerStatefulWidget {
  const CompactFilterSheet({super.key});

  @override
  ConsumerState<CompactFilterSheet> createState() => _CompactFilterSheetState();
}

class _CompactFilterSheetState extends ConsumerState<CompactFilterSheet> {
  static const int _kMaxFilterResults = 15;

  _CompactFilterCategory _currentCategory = _CompactFilterCategory.flags;

  late final TextEditingController _subSearchController;
  late final TextEditingController _authorSearchController;
  late final TextEditingController _flairSearchController;

  String _subSearchQuery = '';
  String _authorSearchQuery = '';
  String _flairSearchQuery = '';

  Timer? _searchDebounce;

  List<(String, int)>? _subResults;
  bool _isLoadingSubs = false;
  String? _loadedSubQuery;

  List<(String, int)>? _authorResults;
  bool _isLoadingAuthors = false;
  String? _loadedAuthorQuery;

  List<(String, int)>? _flairResults;
  bool _isLoadingFlairs = false;
  String? _loadedFlairQuery;

  @override
  void initState() {
    super.initState();
    _subSearchController = TextEditingController()
      ..addListener(_onSubSearchChanged);
    _authorSearchController = TextEditingController()
      ..addListener(_onAuthorSearchChanged);
    _flairSearchController = TextEditingController()
      ..addListener(_onFlairSearchChanged);
  }

  void _onSubSearchChanged() {
    final text = _subSearchController.text;
    if (text == _subSearchQuery) return;
    setState(() => _subSearchQuery = text);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted && _currentCategory == _CompactFilterCategory.subreddits) {
        _loadSubreddits(force: true);
      }
    });
  }

  void _onAuthorSearchChanged() {
    final text = _authorSearchController.text;
    if (text == _authorSearchQuery) return;
    setState(() => _authorSearchQuery = text);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted && _currentCategory == _CompactFilterCategory.authors) {
        _loadAuthors(force: true);
      }
    });
  }

  void _onFlairSearchChanged() {
    final text = _flairSearchController.text;
    if (text == _flairSearchQuery) return;
    setState(() => _flairSearchQuery = text);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted && _currentCategory == _CompactFilterCategory.flairs) {
        _loadFlairs(force: true);
      }
    });
  }

  Future<void> _loadSubreddits({bool force = false}) async {
    final query = _subSearchQuery.trim();
    if (!force && _subResults != null && _loadedSubQuery == query) return;
    setState(() => _isLoadingSubs = true);
    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final results = await repo.searchSubredditsWithCounts(
        query: query,
        limit: _kMaxFilterResults,
      );
      if (!mounted) return;
      setState(() {
        _subResults = results;
        _loadedSubQuery = query;
        _isLoadingSubs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSubs = false);
    }
  }

  Future<void> _loadAuthors({bool force = false}) async {
    final query = _authorSearchQuery.trim();
    if (!force && _authorResults != null && _loadedAuthorQuery == query) return;
    setState(() => _isLoadingAuthors = true);
    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final results = await repo.searchAuthorsWithCounts(
        query: query,
        limit: _kMaxFilterResults,
      );
      if (!mounted) return;
      setState(() {
        _authorResults = results;
        _loadedAuthorQuery = query;
        _isLoadingAuthors = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAuthors = false);
    }
  }

  Future<void> _loadFlairs({bool force = false}) async {
    final query = _flairSearchQuery.trim();
    if (!force && _flairResults != null && _loadedFlairQuery == query) return;
    setState(() => _isLoadingFlairs = true);
    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final results = await repo.searchFlairsWithCounts(
        query: query,
        limit: _kMaxFilterResults,
      );
      if (!mounted) return;
      setState(() {
        _flairResults = results;
        _loadedFlairQuery = query;
        _isLoadingFlairs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFlairs = false);
    }
  }

  void _selectCategory(_CompactFilterCategory cat) {
    if (_currentCategory == cat) return;
    setState(() {
      _currentCategory = cat;
    });
    switch (cat) {
      case _CompactFilterCategory.subreddits:
        _loadSubreddits();
      case _CompactFilterCategory.authors:
        _loadAuthors();
      case _CompactFilterCategory.flairs:
        _loadFlairs();
      case _CompactFilterCategory.flags:
      case _CompactFilterCategory.media:
        break;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _subSearchController.dispose();
    _authorSearchController.dispose();
    _flairSearchController.dispose();
    super.dispose();
  }

  int _getActiveCountForCategory(
    _CompactFilterCategory category,
    FilterCriteria filter,
  ) {
    switch (category) {
      case _CompactFilterCategory.subreddits:
        return filter.selectedSubreddits.length;
      case _CompactFilterCategory.authors:
        return filter.selectedAuthors.length;
      case _CompactFilterCategory.media:
        return filter.selectedMediaTypes.length;
      case _CompactFilterCategory.flags:
        var count = 0;
        if (filter.itemType != null) count++;
        if (filter.isStarred == true) count++;
        if (filter.isNsfw != null) count++;
        return count;
      case _CompactFilterCategory.flairs:
        return filter.selectedFlairs.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(searchFilterViewModelProvider);
    final viewModel = ref.read(searchFilterViewModelProvider.notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Search Filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (filter.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (filter.hasActiveFilters)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => viewModel.clearAllFilters(),
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // active filter chips strip
              if (filter.hasActiveFilters)
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _buildActiveFilterChips(
                      filter,
                      viewModel,
                      colorScheme,
                    ),
                  ),
                ),

              // category Selector Pills Bar
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _CompactFilterCategory.values.map((cat) {
                    final isCurrent = _currentCategory == cat;
                    final count = _getActiveCountForCategory(cat, filter);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          cat.icon,
                          size: 16,
                          color: isCurrent
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.label),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? colorScheme.surface
                                      : colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isCurrent
                                        ? colorScheme.primary
                                        : colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        selected: isCurrent,
                        selectedColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isCurrent
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCurrent
                                ? Colors.transparent
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                        onSelected: (_) => _selectCategory(cat),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              // pinned Content for the Selected Category
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_currentCategory),
                    child: _buildCategoryContent(
                      context,
                      filter,
                      viewModel,
                      colorScheme,
                      scrollController,
                    ),
                  ),
                ),
              ),

              // bottom pinned Done button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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

  Widget _buildCategoryContent(
    BuildContext context,
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    switch (_currentCategory) {
      case _CompactFilterCategory.subreddits:
        return _buildSubredditsSection(
          filter,
          viewModel,
          colorScheme,
          scrollController,
        );
      case _CompactFilterCategory.authors:
        return _buildAuthorsSection(
          filter,
          viewModel,
          colorScheme,
          scrollController,
        );
      case _CompactFilterCategory.media:
        return _buildMediaSection(
          filter,
          viewModel,
          colorScheme,
          scrollController,
        );
      case _CompactFilterCategory.flags:
        return _buildFlagsSection(
          filter,
          viewModel,
          colorScheme,
          scrollController,
        );
      case _CompactFilterCategory.flairs:
        return _buildFlairsSection(
          filter,
          viewModel,
          colorScheme,
          scrollController,
        );
    }
  }

  Widget _buildSubredditsSection(
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    final results = _subResults ?? const <(String, int)>[];
    final resultMap = {for (final s in results) s.$1: s};

    final displayList = <(String, int)>[
      for (final sel in filter.selectedSubreddits) resultMap[sel] ?? (sel, 0),
      for (final s in results)
        if (!filter.selectedSubreddits.contains(s.$1)) s,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: _subSearchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search subreddits (top $_kMaxFilterResults shown)...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _subSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => _subSearchController.clear(),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingSubs && _subResults == null
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : displayList.isEmpty
              ? Center(
                  child: Text(
                    _subSearchQuery.trim().isEmpty
                        ? 'No subreddits available.'
                        : 'No subreddits match "$_subSearchQuery"',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayList.map((s) {
                        final name = s.$1;
                        final count = s.$2;
                        final isSelected = filter.selectedSubreddits.contains(
                          name,
                        );
                        final label = count > 0
                            ? '${SavedItem.formatSubreddit(name)} ($count)'
                            : SavedItem.formatSubreddit(name);
                        return FilterChip(
                          avatar: isSelected
                              ? const Icon(Icons.check_rounded, size: 14)
                              : Icon(
                                  SavedItem.isUserSubreddit(name)
                                      ? Icons.person_rounded
                                      : Icons.tag_rounded,
                                  size: 13,
                                ),
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) => viewModel.toggleSubreddit(name),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),
                    if (results.length >= _kMaxFilterResults)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Showing top $_kMaxFilterResults matches, type above to search more',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAuthorsSection(
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    final results = _authorResults ?? const <(String, int)>[];
    final resultMap = {for (final a in results) a.$1: a};

    final displayList = <(String, int)>[
      for (final sel in filter.selectedAuthors) resultMap[sel] ?? (sel, 0),
      for (final a in results)
        if (!filter.selectedAuthors.contains(a.$1)) a,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: _authorSearchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search authors (top $_kMaxFilterResults shown)...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _authorSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => _authorSearchController.clear(),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingAuthors && _authorResults == null
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : displayList.isEmpty
              ? Center(
                  child: Text(
                    _authorSearchQuery.trim().isEmpty
                        ? 'No authors available.'
                        : 'No authors match "$_authorSearchQuery"',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayList.map((a) {
                        final name = a.$1;
                        final count = a.$2;
                        final isSelected = filter.selectedAuthors.contains(
                          name,
                        );
                        final label = count > 0
                            ? 'u/$name ($count)'
                            : 'u/$name';
                        return FilterChip(
                          avatar: isSelected
                              ? const Icon(Icons.check_rounded, size: 14)
                              : const Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                ),
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) => viewModel.toggleAuthor(name),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),
                    if (results.length >= _kMaxFilterResults)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Showing top $_kMaxFilterResults matches, type above to search more',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMediaSection(
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    final mediaOptions = [
      (MediaType.image, 'Images', Icons.image_outlined),
      (MediaType.video, 'Videos', Icons.videocam_outlined),
      (MediaType.gallery, 'Galleries', Icons.photo_library_outlined),
      (MediaType.text, 'Self-Text', Icons.text_snippet_outlined),
      (MediaType.link, 'Links', Icons.link_rounded),
      (MediaType.gif, 'GIFs', Icons.gif_box_outlined),
    ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: mediaOptions.map((opt) {
            final type = opt.$1;
            final label = opt.$2;
            final icon = opt.$3;
            final isSelected = filter.selectedMediaTypes.contains(type);

            return FilterChip(
              avatar: Icon(isSelected ? Icons.check_rounded : icon, size: 16),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => viewModel.toggleMediaType(type),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFlagsSection(
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text(
          'Post Type',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
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
          onSelectionChanged: (set) => viewModel.setItemType(set.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 20),

        Text(
          'Status & Tags',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: Icon(
                filter.isStarred == true
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: filter.isStarred == true ? Colors.amber : null,
                size: 18,
              ),
              label: const Text('Starred Only'),
              selected: filter.isStarred == true,
              onSelected: (val) => viewModel.toggleStarredOnly(val),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            FilterChip(
              avatar: const Icon(Icons.explicit_outlined, size: 16),
              label: const Text('NSFW Only'),
              selected: filter.isNsfw == true,
              onSelected: (val) => viewModel.setNsfwFilter(val ? true : null),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            FilterChip(
              avatar: const Icon(Icons.shield_outlined, size: 16),
              label: const Text('SFW Only'),
              selected: filter.isNsfw == false,
              onSelected: (val) => viewModel.setNsfwFilter(val ? false : null),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlairsSection(
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    final results = _flairResults ?? const <(String, int)>[];
    final resultMap = {for (final f in results) f.$1: f};

    final displayList = <(String, int)>[
      for (final sel in filter.selectedFlairs) resultMap[sel] ?? (sel, 0),
      for (final f in results)
        if (!filter.selectedFlairs.contains(f.$1)) f,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: _flairSearchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search flairs (top $_kMaxFilterResults shown)...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _flairSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => _flairSearchController.clear(),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingFlairs && _flairResults == null
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : displayList.isEmpty
              ? Center(
                  child: Text(
                    _flairSearchQuery.trim().isEmpty
                        ? 'No flairs available.'
                        : 'No flairs match "$_flairSearchQuery"',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayList.map((f) {
                        final flair = f.$1;
                        final count = f.$2;
                        final isSelected = filter.selectedFlairs.contains(
                          flair,
                        );
                        final label = count > 0 ? '$flair ($count)' : flair;

                        return FilterChip(
                          avatar: isSelected
                              ? const Icon(Icons.check_rounded, size: 14)
                              : const Icon(Icons.sell_outlined, size: 13),
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) => viewModel.toggleFlair(flair),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),
                    if (results.length >= _kMaxFilterResults)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Showing top $_kMaxFilterResults matches, type above to search more',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _buildActiveFilterChips(
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    final chips = <Widget>[];

    if (filter.itemType == ItemType.post) {
      chips.add(
        _activeChip(
          label: 'Posts',
          icon: Icons.article_rounded,
          onDeleted: () => viewModel.setItemType(null),
        ),
      );
    } else if (filter.itemType == ItemType.comment) {
      chips.add(
        _activeChip(
          label: 'Comments',
          icon: Icons.chat_bubble_rounded,
          onDeleted: () => viewModel.setItemType(null),
        ),
      );
    }

    if (filter.isStarred == true) {
      chips.add(
        _activeChip(
          label: 'Starred',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          onDeleted: () => viewModel.toggleStarredOnly(false),
        ),
      );
    }

    if (filter.isNsfw != null) {
      chips.add(
        _activeChip(
          label: filter.isNsfw! ? 'NSFW Only' : 'SFW Only',
          icon: filter.isNsfw! ? Icons.explicit_rounded : Icons.shield_rounded,
          onDeleted: () => viewModel.setNsfwFilter(null),
        ),
      );
    }

    for (final sub in filter.selectedSubreddits) {
      chips.add(
        _activeChip(
          label: SavedItem.formatSubreddit(sub),
          icon: SavedItem.isUserSubreddit(sub)
              ? Icons.person_rounded
              : Icons.tag_rounded,
          onDeleted: () => viewModel.toggleSubreddit(sub),
        ),
      );
    }

    for (final author in filter.selectedAuthors) {
      chips.add(
        _activeChip(
          label: 'u/$author',
          icon: Icons.person_rounded,
          onDeleted: () => viewModel.toggleAuthor(author),
        ),
      );
    }

    for (final type in filter.selectedMediaTypes) {
      chips.add(
        _activeChip(
          label: type.name.toUpperCase(),
          icon: Icons.perm_media_rounded,
          onDeleted: () => viewModel.toggleMediaType(type),
        ),
      );
    }

    for (final flair in filter.selectedFlairs) {
      chips.add(
        _activeChip(
          label: flair,
          icon: Icons.sell_rounded,
          onDeleted: () => viewModel.toggleFlair(flair),
        ),
      );
    }

    return chips;
  }

  Widget _activeChip({
    required String label,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onDeleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 13, color: iconColor),
        label: Text(label, style: const TextStyle(fontSize: 11.5)),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close_rounded, size: 14),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
