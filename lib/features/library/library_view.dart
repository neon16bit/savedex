import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/author_info.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/models/subreddit_info.dart';
import 'package:savedex/features/library/library_viewmodel.dart';
import 'package:savedex/features/library/scoped_feed_view.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({super.key});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Set<int> _visitedSubTabs;

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(librarySubTabProvider).clamp(0, 2);
    _visitedSubTabs = {initialTab};
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab,
    );
    _tabController.addListener(_onTabChanged);
    _tabController.animation?.addListener(_onTabAnimation);
  }

  void _onTabChanged() {
    if (!mounted) return;
    final index = _tabController.index;
    if (_visitedSubTabs.add(index)) {
      setState(() {});
      if (_visitedSubTabs.length == 3) {
        _tabController.animation?.removeListener(_onTabAnimation);
      }
    }
    ref.read(librarySubTabProvider.notifier).setSubTab(index);
  }

  void _onTabAnimation() {
    if (!mounted ||
        _visitedSubTabs.length == 3 ||
        _tabController.indexIsChanging) {
      return;
    }
    final animValue =
        _tabController.animation?.value ?? _tabController.index.toDouble();
    final current = _tabController.index;
    int? target;
    if (animValue > current + 0.15) {
      target = (current + 1).clamp(0, 2);
    } else if (animValue < current - 0.15) {
      target = (current - 1).clamp(0, 2);
    }
    if (target != null && _visitedSubTabs.add(target)) {
      setState(() {});
      if (_visitedSubTabs.length == 3) {
        _tabController.animation?.removeListener(_onTabAnimation);
      }
    }
  }

  @override
  void dispose() {
    _tabController.animation?.removeListener(_onTabAnimation);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enableFrosted = watchFrostedEffects(ref);

    return Scaffold(
      extendBodyBehindAppBar: enableFrosted,
      appBar: AppBar(
        backgroundColor: enableFrosted ? Colors.transparent : null,
        elevation: 0,
        scrolledUnderElevation: enableFrosted ? 0 : null,
        surfaceTintColor: enableFrosted ? Colors.transparent : null,
        flexibleSpace: FrostedAppBarBackground(
          enableBlur: enableFrosted,
          showBottomBorder: false,
        ),
        title: const Text(
          'Library',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            _TabTitleWithCount(tabIndex: 0, label: 'Collections'),
            _TabTitleWithCount(tabIndex: 1, label: 'Subreddits'),
            _TabTitleWithCount(tabIndex: 2, label: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _visitedSubTabs.contains(0)
              ? const _CollectionsTab()
              : const SizedBox.shrink(),
          _visitedSubTabs.contains(1)
              ? const _SubredditsTab()
              : const SizedBox.shrink(),
          _visitedSubTabs.contains(2)
              ? const _UsersTab()
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _TabTitleWithCount extends ConsumerWidget {
  final int tabIndex;
  final String label;

  const _TabTitleWithCount({required this.tabIndex, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? count = switch (tabIndex) {
      0 => ref.watch(
        collectionsWithCountsProvider.select((c) => c.asData?.value.length),
      ),
      1 => ref.watch(subredditCountProvider.select((s) => s.asData?.value)),
      2 => ref.watch(authorCountProvider.select((a) => a.asData?.value)),
      _ => null,
    };
    final text = count != null ? '$label ($count)' : label;

    return Tab(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis));
  }
}

class _CollectionsTab extends ConsumerStatefulWidget {
  const _CollectionsTab();

  @override
  ConsumerState<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends ConsumerState<_CollectionsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _deleteCollection(BuildContext context, Collection col) async {
    final confirmed = await showFrostedDialog<bool>(
      context: context,
      builder: (ctx) => FrostedAlertDialog(
        title: Text('Delete "${col.name}"?'),
        content: const Text(
          'This collection will be deleted. None of your saved posts or comments will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(collectionRepositoryProvider).deleteCollection(col.id);
      ref.read(itemCollectionsOverrideProvider.notifier).clear();
      if (context.mounted) {
        showAppSnackBar(context, 'Deleted collection "${col.name}"');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final collectionsAsync = ref.watch(sortedCollectionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topOffset = MediaQuery.paddingOf(context).top;

    return collectionsAsync.when(
      data: (collections) {
        if (collections.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: topOffset),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        size: 52,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Collections Yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create custom collections to categorize and group your favorite Reddit posts and comments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => showCollectionFormDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Collection'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.only(top: topOffset + 6, bottom: 104),
          itemCount: collections.length,
          separatorBuilder: (context, _) => Divider(
            height: 1,
            indent: 68,
            endIndent: 14,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          itemBuilder: (context, index) {
            final col = collections[index];
            final colColor = Color(col.colorValue);
            final hasDescription =
                col.description != null && col.description!.trim().isNotEmpty;

            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) =>
                        ScopedFeedView(args: ScopedFeedArgs.collection(col)),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: hasDescription
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      margin: EdgeInsets.only(top: hasDescription ? 2 : 0),
                      decoration: BoxDecoration(
                        color: colColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colColor.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.bookmark_rounded,
                          color: colColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  col.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${col.itemCount} saved',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (hasDescription) ...[
                            const SizedBox(height: 3),
                            Text(
                              col.description!.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    FrostedPopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Collection options',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (val) {
                        if (val == 'edit') {
                          showCollectionFormDialog(
                            context,
                            initialCollection: col,
                          );
                        } else if (val == 'delete') {
                          _deleteCollection(context, col);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 20),
                              SizedBox(width: 10),
                              Text('Edit Collection'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Delete Collection',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.only(top: topOffset),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(
        padding: EdgeInsets.only(top: topOffset),
        child: Center(child: Text('Error loading collections: $err')),
      ),
    );
  }
}

const int _kLibraryEnrichmentBatchCap = 40;
const int _kLibraryEnrichmentLookaheadRows = 60;
const double _kLibraryEntryEstimatedExtent = 60.0;

void _noopTap() {}

List<String> _collectPrioritizedUnverified<T>(
  List<T> items, {
  required double scrollOffset,
  required bool Function(T item) shouldEnrich,
  required String Function(T item) keyOf,
}) {
  if (items.isEmpty) return const [];
  final approxFirstVisible = (scrollOffset / _kLibraryEntryEstimatedExtent)
      .floor();
  final start = (approxFirstVisible - 5).clamp(0, items.length);
  final end = (start + _kLibraryEnrichmentLookaheadRows).clamp(0, items.length);
  final result = <String>[];

  for (var i = start; i < end; i++) {
    final item = items[i];
    if (shouldEnrich(item)) {
      result.add(keyOf(item));
      if (result.length >= _kLibraryEnrichmentBatchCap) {
        return result;
      }
    }
  }
  return result;
}

class _PagedDirectoryTab<T> extends ConsumerStatefulWidget {
  final AsyncValue<DirectoryPageState<T>> pageAsync;
  final VoidCallback onLoadMore;
  final int librarySubTabIndex;
  final bool Function(T item) shouldEnrich;
  final String Function(T item) keyOf;
  final void Function(List<String> keys) onEnrich;
  final Widget Function(BuildContext context, T item, Widget divider)
  rowBuilder;
  final Widget Function(ColorScheme colorScheme, Widget divider)
  prototypeBuilder;
  final Widget Function(BuildContext context) emptyBuilder;
  final String errorPrefix;

  const _PagedDirectoryTab({
    required this.pageAsync,
    required this.onLoadMore,
    required this.librarySubTabIndex,
    required this.shouldEnrich,
    required this.keyOf,
    required this.onEnrich,
    required this.rowBuilder,
    required this.prototypeBuilder,
    required this.emptyBuilder,
    required this.errorPrefix,
  });

  @override
  ConsumerState<_PagedDirectoryTab<T>> createState() =>
      _PagedDirectoryTabState<T>();
}

class _PagedDirectoryTabState<T> extends ConsumerState<_PagedDirectoryTab<T>>
    with AutomaticKeepAliveClientMixin {
  static const int _kEnrichmentDebounceMs = 350;

  final ScrollController _scrollController = ScrollController();
  final Stopwatch _scrollWatch = Stopwatch()..start();
  int _lastScrollMs = -_kEnrichmentDebounceMs;
  Timer? _enrichmentTimer;
  bool _isResettingScroll = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleEnrichment();
    });
  }

  bool _hasItemKeysChanged(List<T>? oldItems, List<T>? newItems) {
    if (newItems == null || newItems.isEmpty) return false;
    if (oldItems == null || oldItems.length != newItems.length) return true;
    for (var i = 0; i < newItems.length; i++) {
      if (widget.keyOf(oldItems[i]) != widget.keyOf(newItems[i])) {
        return true;
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant _PagedDirectoryTab<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPage = oldWidget.pageAsync.value;
    final newPage = widget.pageAsync.asData?.value;
    final epochChanged =
        oldPage != null &&
        newPage != null &&
        newPage.queryEpoch != oldPage.queryEpoch;
    if (epochChanged &&
        _scrollController.hasClients &&
        _scrollController.offset > 0) {
      _isResettingScroll = true;
      try {
        _scrollController.jumpTo(0);
      } finally {
        _isResettingScroll = false;
      }
    }
    final oldItems = oldPage?.items;
    final newItems = newPage?.items;
    if (!identical(oldItems, newItems) &&
        ((epochChanged && newItems != null && newItems.isNotEmpty) ||
            _hasItemKeysChanged(oldItems, newItems))) {
      _scheduleEnrichment();
    }
  }

  @override
  void dispose() {
    _enrichmentTimer?.cancel();
    _scrollWatch.stop();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isResettingScroll) return;
    _lastScrollMs = _scrollWatch.elapsedMilliseconds;
    if (!(_enrichmentTimer?.isActive ?? false)) {
      _scheduleEnrichment();
    }
    if (!_scrollController.hasClients) return;
    final page = widget.pageAsync.asData?.value;
    if (page == null || !page.hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 500) {
      widget.onLoadMore();
    }
  }

  bool get _isTabActive =>
      mounted &&
      ref.read(selectedShellTabProvider) == 1 &&
      ref.read(librarySubTabProvider) == widget.librarySubTabIndex;

  void _scheduleEnrichment() {
    _enrichmentTimer?.cancel();
    if (!_isTabActive) return;
    _enrichmentTimer = Timer(
      const Duration(milliseconds: _kEnrichmentDebounceMs),
      _onEnrichmentTimerFired,
    );
  }

  void _onEnrichmentTimerFired() {
    if (!_isTabActive) return;
    final sinceLastScrollMs = _scrollWatch.elapsedMilliseconds - _lastScrollMs;
    if (sinceLastScrollMs < _kEnrichmentDebounceMs) {
      _enrichmentTimer = Timer(
        Duration(milliseconds: _kEnrichmentDebounceMs - sinceLastScrollMs),
        _onEnrichmentTimerFired,
      );
      return;
    }
    _runVisibleEnrichment();
  }

  void _runVisibleEnrichment() {
    if (!_isTabActive) return;
    final items = widget.pageAsync.asData?.value.items;
    if (items == null || items.isEmpty) return;

    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final targets = _collectPrioritizedUnverified<T>(
      items,
      scrollOffset: offset,
      shouldEnrich: widget.shouldEnrich,
      keyOf: widget.keyOf,
    );
    if (targets.isNotEmpty) {
      widget.onEnrich(targets);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<int>(librarySubTabProvider, (_, next) {
      if (next == widget.librarySubTabIndex) {
        _scheduleEnrichment();
      } else {
        _enrichmentTimer?.cancel();
      }
    });
    ref.listen<int>(selectedShellTabProvider, (_, next) {
      if (next == 1) {
        _scheduleEnrichment();
      } else {
        _enrichmentTimer?.cancel();
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final topOffset = MediaQuery.paddingOf(context).top;
    return widget.pageAsync.when(
      skipLoadingOnReload: true,
      data: (pageState) {
        final items = pageState.items;
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: topOffset),
            child: widget.emptyBuilder(context),
          );
        }

        final divider = Divider(
          height: 1,
          indent: 68,
          endIndent: 14,
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        );

        return ListView.builder(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(0, topOffset + 8, 0, 104),
          itemCount: items.length + (pageState.hasMore ? 1 : 0),
          prototypeItem: widget.prototypeBuilder(colorScheme, divider),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              );
            }
            return widget.rowBuilder(context, items[index], divider);
          },
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.only(top: topOffset),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(
        padding: EdgeInsets.only(top: topOffset),
        child: Center(child: Text('${widget.errorPrefix}: $err')),
      ),
    );
  }
}

class _SubredditsTab extends ConsumerWidget {
  const _SubredditsTab();

  String _getSubredditInitial(String name) {
    final clean = name.replaceFirst(RegExp(r'^[ru][/_-]'), '').trim();
    if (clean.isEmpty) return 'R';
    return clean[0].toUpperCase();
  }

  Widget _buildSubredditPlaceholder(
    ColorScheme colorScheme,
    bool isUser,
    String subName,
    Widget userPlaceholder,
  ) {
    if (isUser) {
      return userPlaceholder;
    }
    return Center(
      child: Text(
        _getSubredditInitial(subName),
        style: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          color: colorScheme.primary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(subredditsFeedProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userPlaceholder = Icon(
      Icons.person_rounded,
      color: colorScheme.onSecondaryContainer,
      size: 20,
    );

    return _PagedDirectoryTab<SubredditInfo>(
      pageAsync: pageAsync,
      onLoadMore: () => ref.read(subredditsFeedProvider.notifier).loadMore(),
      librarySubTabIndex: 1,
      shouldEnrich: (s) => !s.isVerified && !SavedItem.isUserSubreddit(s.name),
      keyOf: (s) => s.name,
      onEnrich: (targets) =>
          ref.read(savedItemRepositoryProvider).enrichSubreddits(targets),
      errorPrefix: 'Error loading subreddits',
      prototypeBuilder: (cs, divider) => _LibraryEntryRow(
        title: 'r/prototype',
        count: 99,
        iconUrl: null,
        isNsfw: true,
        avatarBackgroundColor: cs.primaryContainer,
        placeholder: const SizedBox.shrink(),
        divider: divider,
        onTap: _noopTap,
      ),
      emptyBuilder: (context) {
        final query = ref.read(subredditSearchQueryProvider).trim();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  query.isNotEmpty
                      ? 'No subreddits matching "$query"'
                      : 'No saved subreddits found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      ref.read(subredditSearchQueryProvider.notifier).clear();
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      rowBuilder: (context, item, divider) {
        final subName = item.name;
        final isUser = SavedItem.isUserSubreddit(subName);
        return _LibraryEntryRow(
          title: SavedItem.formatSubreddit(subName),
          count: item.count,
          iconUrl: item.iconUrl,
          isNsfw: item.isNsfw,
          avatarBackgroundColor: isUser
              ? colorScheme.secondaryContainer
              : colorScheme.primaryContainer.withValues(alpha: 0.5),
          placeholder: _buildSubredditPlaceholder(
            colorScheme,
            isUser,
            subName,
            userPlaceholder,
          ),
          divider: divider,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) =>
                    ScopedFeedView(args: ScopedFeedArgs.subreddit(subName)),
              ),
            );
          },
        );
      },
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(authorsFeedProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userPlaceholder = Icon(
      Icons.person_rounded,
      color: colorScheme.onSecondaryContainer,
      size: 20,
    );

    return _PagedDirectoryTab<AuthorInfo>(
      pageAsync: pageAsync,
      onLoadMore: () => ref.read(authorsFeedProvider.notifier).loadMore(),
      librarySubTabIndex: 2,
      shouldEnrich: (a) => !a.isVerified,
      keyOf: (a) => a.name,
      onEnrich: (targets) =>
          ref.read(savedItemRepositoryProvider).enrichAuthors(targets),
      errorPrefix: 'Error loading users',
      prototypeBuilder: (cs, divider) => _LibraryEntryRow(
        title: 'u/prototype',
        count: 99,
        iconUrl: null,
        isNsfw: true,
        avatarBackgroundColor: cs.secondaryContainer,
        placeholder: userPlaceholder,
        divider: divider,
        onTap: _noopTap,
      ),
      emptyBuilder: (context) {
        final query = ref.read(userSearchQueryProvider).trim();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  query.isNotEmpty
                      ? Icons.search_off_rounded
                      : Icons.person_off_rounded,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  query.isNotEmpty
                      ? 'No users matching "$query"'
                      : 'No saved users found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (query.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Authors of your saved posts and comments will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      ref.read(userSearchQueryProvider.notifier).clear();
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      rowBuilder: (context, item, divider) {
        final author = item.name;
        return _LibraryEntryRow(
          title: 'u/$author',
          count: item.count,
          iconUrl: item.iconUrl,
          isNsfw: item.isNsfw,
          avatarBackgroundColor: colorScheme.secondaryContainer,
          placeholder: userPlaceholder,
          divider: divider,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            ScopedFeedView.openAuthor(context, author);
          },
        );
      },
    );
  }
}

class _LibraryEntryRow extends StatelessWidget {
  final String title;
  final int count;
  final String? iconUrl;
  final bool isNsfw;
  final Color avatarBackgroundColor;
  final Widget placeholder;
  final Widget divider;
  final VoidCallback onTap;

  const _LibraryEntryRow({
    required this.title,
    required this.count,
    required this.iconUrl,
    required this.isNsfw,
    required this.avatarBackgroundColor,
    required this.placeholder,
    required this.divider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LibraryEntryTile(
          title: title,
          count: count,
          iconUrl: iconUrl,
          isNsfw: isNsfw,
          avatarBackgroundColor: avatarBackgroundColor,
          placeholder: placeholder,
          onTap: onTap,
        ),
        divider,
      ],
    );
  }
}

class _LibraryEntryTile extends StatelessWidget {
  final String title;
  final int count;
  final String? iconUrl;
  final bool isNsfw;
  final Color avatarBackgroundColor;
  final Widget placeholder;
  final VoidCallback onTap;

  const _LibraryEntryTile({
    required this.title,
    required this.count,
    required this.iconUrl,
    required this.isNsfw,
    required this.avatarBackgroundColor,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasIcon = iconUrl != null && iconUrl!.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: avatarBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: hasIcon
            ? ClipOval(
                child: ExtendedImage.network(
                  iconUrl!,
                  width: 40,
                  height: 40,
                  cacheWidth: 120,
                  cacheHeight: 120,
                  fit: BoxFit.cover,
                  cache: true,
                  retries: 1,
                  printError: false,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.completed) {
                      return null;
                    }
                    return placeholder;
                  },
                ),
              )
            : placeholder,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          if (isNsfw) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NSFW',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count saved',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
