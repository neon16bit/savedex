import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/search/search_viewmodel.dart';

enum _CompactEntityCategory {
  subreddits('Subreddits'),
  authors('Authors'),
  flairs('Flairs');

  final String label;
  const _CompactEntityCategory(this.label);
}

abstract class FilterCardDragNotification extends Notification {
  const FilterCardDragNotification();
}

class FilterCardDragUpdateNotification extends FilterCardDragNotification {
  final double delta;
  const FilterCardDragUpdateNotification(this.delta);
}

class FilterCardDragEndNotification extends FilterCardDragNotification {
  final double velocity;
  const FilterCardDragEndNotification(this.velocity);
}

class FilterCardDragCancelNotification extends FilterCardDragNotification {
  const FilterCardDragCancelNotification();
}

class FilterSheet extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final bool isFloatingCard;

  const FilterSheet({super.key, this.onClose, this.isFloatingCard = false});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  static const int _kMaxFilterResults = 15;

  _CompactEntityCategory _currentEntity = _CompactEntityCategory.subreddits;

  late final ScrollController _cardScrollController;
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
    _cardScrollController = ScrollController();
    _subSearchController = TextEditingController()
      ..addListener(_onSubSearchChanged);
    _authorSearchController = TextEditingController()
      ..addListener(_onAuthorSearchChanged);
    _flairSearchController = TextEditingController()
      ..addListener(_onFlairSearchChanged);

    _loadSubreddits();
    _loadAuthors();
    _loadFlairs();
  }

  void _onSubSearchChanged() {
    final text = _subSearchController.text;
    if (text == _subSearchQuery) return;
    setState(() => _subSearchQuery = text);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted && _currentEntity == _CompactEntityCategory.subreddits) {
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
      if (mounted && _currentEntity == _CompactEntityCategory.authors) {
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
      if (mounted && _currentEntity == _CompactEntityCategory.flairs) {
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

  void _selectEntity(_CompactEntityCategory cat) {
    if (_currentEntity == cat) return;
    setState(() {
      _currentEntity = cat;
    });
    switch (cat) {
      case _CompactEntityCategory.subreddits:
        _loadSubreddits();
      case _CompactEntityCategory.authors:
        _loadAuthors();
      case _CompactEntityCategory.flairs:
        _loadFlairs();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cardScrollController.dispose();
    _subSearchController.removeListener(_onSubSearchChanged);
    _subSearchController.dispose();
    _authorSearchController.removeListener(_onAuthorSearchChanged);
    _authorSearchController.dispose();
    _flairSearchController.removeListener(_onFlairSearchChanged);
    _flairSearchController.dispose();
    super.dispose();
  }

  void _triggerClose() {
    HapticFeedback.lightImpact();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (widget.isFloatingCard) {
      const FilterCardDragCancelNotification().dispatch(context);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.isFloatingCard) {
      FilterCardDragUpdateNotification(details.primaryDelta ?? 0.0)
          .dispatch(context);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (widget.isFloatingCard) {
      FilterCardDragEndNotification(details.primaryVelocity ?? 0.0)
          .dispatch(context);
    }
  }

  void _onVerticalDragCancel() {
    if (widget.isFloatingCard) {
      const FilterCardDragCancelNotification().dispatch(context);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.isFloatingCard) return false;

    if (notification is ScrollStartNotification) {
      const FilterCardDragCancelNotification().dispatch(context);
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        // Downward pull
        FilterCardDragUpdateNotification(notification.overscroll.abs())
            .dispatch(context);
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.scrollDelta != null && notification.scrollDelta! > 0) {
        // upward drag
        FilterCardDragUpdateNotification(-notification.scrollDelta!)
            .dispatch(context);
      }
    } else if (notification is ScrollEndNotification) {
      final velocity = notification.dragDetails?.primaryVelocity ?? 0.0;
      FilterCardDragEndNotification(velocity).dispatch(context);
    }
    return false;
  }

  Widget _buildEmptyStateOrLoading({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onVerticalDragCancel: _onVerticalDragCancel,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(searchFilterViewModelProvider);
    final viewModel = ref.read(searchFilterViewModelProvider.notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.isFloatingCard) {
      return _buildSheetBody(
        context,
        _cardScrollController,
        colorScheme,
        theme,
        viewModel,
        filter,
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return _buildSheetBody(
          context,
          scrollController,
          colorScheme,
          theme,
          viewModel,
          filter,
        );
      },
    );
  }

  Widget _buildSheetBody(
    BuildContext context,
    ScrollController scrollController,
    ColorScheme colorScheme,
    ThemeData theme,
    SearchFilterViewModel viewModel,
    FilterCriteria filter,
  ) {
    final isFloating = widget.isFloatingCard;

    return Container(
      decoration: BoxDecoration(
        color: isFloating ? Colors.transparent : colorScheme.surface,
        borderRadius: isFloating
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onVerticalDragCancel: _onVerticalDragCancel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag pill handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 10, 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Filters',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const Spacer(),
                      if (filter.hasActiveFilters)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            viewModel.clearAllFilters();
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: _triggerClose,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _buildCompactChoiceChip(
                            label: 'All',
                            isSelected: filter.itemType == null,
                            onSelected: () => viewModel.setItemType(null),
                            colorScheme: colorScheme,
                          ),
                          _buildCompactChoiceChip(
                            label: 'Posts',
                            isSelected: filter.itemType == ItemType.post,
                            onSelected: () => viewModel.setItemType(
                              filter.itemType == ItemType.post
                                  ? null
                                  : ItemType.post,
                            ),
                            colorScheme: colorScheme,
                          ),
                          _buildCompactChoiceChip(
                            label: 'Comments',
                            isSelected: filter.itemType == ItemType.comment,
                            onSelected: () => viewModel.setItemType(
                              filter.itemType == ItemType.comment
                                  ? null
                                  : ItemType.comment,
                            ),
                            colorScheme: colorScheme,
                          ),
                          _buildCompactChoiceChip(
                            label: 'Starred',
                            isSelected: filter.isStarred == true,
                            onSelected: () => viewModel.toggleStarredOnly(
                              filter.isStarred != true,
                            ),
                            colorScheme: colorScheme,
                          ),
                          _buildCompactChoiceChip(
                            label: 'NSFW',
                            isSelected: filter.isNsfw == true,
                            onSelected: () => viewModel.setNsfwFilter(
                              filter.isNsfw == true ? null : true,
                            ),
                            colorScheme: colorScheme,
                          ),
                          _buildCompactChoiceChip(
                            label: 'SFW',
                            isSelected: filter.isNsfw == false,
                            onSelected: () => viewModel.setNsfwFilter(
                              filter.isNsfw == false ? null : false,
                            ),
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children:
                            [
                              (MediaType.image, 'Images'),
                              (MediaType.video, 'Videos'),
                              (MediaType.gallery, 'Galleries'),
                              (MediaType.text, 'Text'),
                              (MediaType.link, 'Links'),
                              (MediaType.gif, 'GIFs'),
                            ].map((opt) {
                              final isSelected = filter.selectedMediaTypes
                                  .contains(opt.$1);
                              return _buildCompactChoiceChip(
                                label: opt.$2,
                                isSelected: isSelected,
                                onSelected: () =>
                                    viewModel.toggleMediaType(opt.$1),
                                colorScheme: colorScheme,
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                  child: Row(
                    children: [
                      _buildEntityTab(
                        label: 'Subreddits',
                        count: filter.selectedSubreddits.length,
                        isSelected:
                            _currentEntity == _CompactEntityCategory.subreddits,
                        onTap: () =>
                            _selectEntity(_CompactEntityCategory.subreddits),
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 6),
                      _buildEntityTab(
                        label: 'Authors',
                        count: filter.selectedAuthors.length,
                        isSelected:
                            _currentEntity == _CompactEntityCategory.authors,
                        onTap: () =>
                            _selectEntity(_CompactEntityCategory.authors),
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 6),
                      _buildEntityTab(
                        label: 'Flairs',
                        count: filter.selectedFlairs.length,
                        isSelected:
                            _currentEntity == _CompactEntityCategory.flairs,
                        onTap: () =>
                            _selectEntity(_CompactEntityCategory.flairs),
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // search bar current entity
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: _buildEntitySearchBar(colorScheme),
          ),

          // scrollable chip result
          Expanded(
            child: _buildEntityChipList(
              filter,
              viewModel,
              colorScheme,
              scrollController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntitySearchBar(ColorScheme colorScheme) {
    final TextEditingController controller;
    final String hintText;
    final String query;

    switch (_currentEntity) {
      case _CompactEntityCategory.subreddits:
        controller = _subSearchController;
        hintText = 'Search subreddits...';
        query = _subSearchQuery;
        break;
      case _CompactEntityCategory.authors:
        controller = _authorSearchController;
        hintText = 'Search authors...';
        query = _authorSearchQuery;
        break;
      case _CompactEntityCategory.flairs:
        controller = _flairSearchController;
        hintText = 'Search flairs...';
        query = _flairSearchQuery;
        break;
    }

    return SizedBox(
      height: 32,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 11.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 15,
            color: colorScheme.primary,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
          suffixIcon: query.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.clear();
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 26,
            minHeight: 26,
          ),
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildEntityChipList(
    FilterCriteria filter,
    SearchFilterViewModel viewModel,
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    switch (_currentEntity) {
      case _CompactEntityCategory.subreddits:
        final results = _subResults ?? const <(String, int)>[];
        final resultMap = {for (final s in results) s.$1: s};
        final displayList = <(String, int)>[
          for (final sel in filter.selectedSubreddits)
            resultMap[sel] ?? (sel, 0),
          for (final s in results)
            if (!filter.selectedSubreddits.contains(s.$1)) s,
        ];

        if (_isLoadingSubs && _subResults == null) {
          return _buildEmptyStateOrLoading(
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (displayList.isEmpty) {
          return _buildEmptyStateOrLoading(
            child: Center(
              child: Text(
                _subSearchQuery.trim().isEmpty
                    ? 'No subreddits available.'
                    : 'No subreddits match "$_subSearchQuery"',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final listPhysics = widget.isFloatingCard
            ? const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              )
            : const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              );

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView(
            controller: scrollController,
            physics: listPhysics,
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: displayList.map((s) {
                  final name = s.$1;
                  final count = s.$2;
                  final isSelected = filter.selectedSubreddits.contains(name);
                  final label = count > 0
                      ? '${SavedItem.formatSubreddit(name)} ($count)'
                      : SavedItem.formatSubreddit(name);
                  return _buildEntityChip(
                    label: label,
                    isSelected: isSelected,
                    onSelected: () => viewModel.toggleSubreddit(name),
                    colorScheme: colorScheme,
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case _CompactEntityCategory.authors:
        final results = _authorResults ?? const <(String, int)>[];
        final resultMap = {for (final a in results) a.$1: a};
        final displayList = <(String, int)>[
          for (final sel in filter.selectedAuthors) resultMap[sel] ?? (sel, 0),
          for (final a in results)
            if (!filter.selectedAuthors.contains(a.$1)) a,
        ];

        if (_isLoadingAuthors && _authorResults == null) {
          return _buildEmptyStateOrLoading(
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (displayList.isEmpty) {
          return _buildEmptyStateOrLoading(
            child: Center(
              child: Text(
                _authorSearchQuery.trim().isEmpty
                    ? 'No authors available.'
                    : 'No authors match "$_authorSearchQuery"',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final listPhysics = widget.isFloatingCard
            ? const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              )
            : const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              );

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView(
            controller: scrollController,
            physics: listPhysics,
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: displayList.map((a) {
                  final name = a.$1;
                  final count = a.$2;
                  final isSelected = filter.selectedAuthors.contains(name);
                  final label = count > 0 ? 'u/$name ($count)' : 'u/$name';
                  return _buildEntityChip(
                    label: label,
                    isSelected: isSelected,
                    onSelected: () => viewModel.toggleAuthor(name),
                    colorScheme: colorScheme,
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case _CompactEntityCategory.flairs:
        final results = _flairResults ?? const <(String, int)>[];
        final resultMap = {for (final f in results) f.$1: f};
        final displayList = <(String, int)>[
          for (final sel in filter.selectedFlairs) resultMap[sel] ?? (sel, 0),
          for (final f in results)
            if (!filter.selectedFlairs.contains(f.$1)) f,
        ];

        if (_isLoadingFlairs && _flairResults == null) {
          return _buildEmptyStateOrLoading(
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (displayList.isEmpty) {
          return _buildEmptyStateOrLoading(
            child: Center(
              child: Text(
                _flairSearchQuery.trim().isEmpty
                    ? 'No flairs available.'
                    : 'No flairs match "$_flairSearchQuery"',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final listPhysics = widget.isFloatingCard
            ? const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              )
            : const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              );

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView(
            controller: scrollController,
            physics: listPhysics,
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: displayList.map((f) {
                  final flair = f.$1;
                  final count = f.$2;
                  final isSelected = filter.selectedFlairs.contains(flair);
                  final label = count > 0 ? '$flair ($count)' : flair;
                  return _buildEntityChip(
                    label: label,
                    isSelected: isSelected,
                    onSelected: () => viewModel.toggleFlair(flair),
                    colorScheme: colorScheme,
                  );
                }).toList(),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildCompactChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildEntityTab({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.65)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : Colors.transparent,
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntityChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
