import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
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
    if (!mounted || _visitedSubTabs.length == 3) return;
    final animValue =
        _tabController.animation?.value ?? _tabController.index.toDouble();
    final current = _tabController.index;
    int? target;
    if (animValue > current + 0.02) {
      target = (current + 1).clamp(0, 2);
    } else if (animValue < current - 0.02) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Library',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            _TabTitleWithCount(
              tabIndex: 0,
              label: 'Collections',
              icon: Icons.bookmark_rounded,
              isVisited: _visitedSubTabs.contains(0),
            ),
            _TabTitleWithCount(
              tabIndex: 1,
              label: 'Subreddits',
              icon: Icons.tag_rounded,
              isVisited: _visitedSubTabs.contains(1),
            ),
            _TabTitleWithCount(
              tabIndex: 2,
              label: 'Users',
              icon: Icons.person_rounded,
              isVisited: _visitedSubTabs.contains(2),
            ),
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
  final IconData icon;
  final bool isVisited;

  const _TabTitleWithCount({
    required this.tabIndex,
    required this.label,
    required this.icon,
    required this.isVisited,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String text = label;
    if (isVisited) {
      final int? count = switch (tabIndex) {
        0 => ref.watch(
          collectionsWithCountsProvider.select((c) => c.asData?.value.length),
        ),
        1 => ref.watch(
          rawSubredditsWithCountsProvider.select((s) => s.asData?.value.length),
        ),
        2 => ref.watch(
          rawAuthorsWithCountsProvider.select((a) => a.asData?.value.length),
        ),
        _ => null,
      };
      if (count != null) {
        text = '$label ($count)';
      }
    }

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted collection "${col.name}"'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final collectionsAsync = ref.watch(sortedCollectionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return collectionsAsync.when(
      data: (collections) {
        if (collections.isEmpty) {
          return Center(
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
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 104),
          itemCount: collections.length,
          separatorBuilder: (context, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final col = collections[index];
            final colColor = Color(col.colorValue);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              color: colorScheme.surfaceContainerLowest,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) =>
                          ScopedFeedView(args: ScopedFeedArgs.collection(col)),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colColor.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.bookmark_rounded,
                          color: colColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              col.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (col.description != null &&
                                col.description!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                col.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '${col.itemCount} ${col.itemCount == 1 ? 'saved item' : 'saved items'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        tooltip: 'Collection options',
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
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading collections: $err')),
    );
  }
}

class _SubredditsTab extends ConsumerStatefulWidget {
  const _SubredditsTab();

  @override
  ConsumerState<_SubredditsTab> createState() => _SubredditsTabState();
}

class _SubredditsTabState extends ConsumerState<_SubredditsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(rawSubredditsWithCountsProvider)
          .whenData(_maybeEnrichSubreddits);
    });
  }

  void _maybeEnrichSubreddits(List<SubredditInfo> subs) {
    if (ref.read(selectedShellTabProvider) != 1 ||
        ref.read(librarySubTabProvider) != 1) {
      return;
    }
    final unverified = [
      for (final s in subs)
        if (!s.isVerified && !SavedItem.isUserSubreddit(s.name)) s.name,
    ];
    if (unverified.isNotEmpty) {
      Future.microtask(
        () =>
            ref.read(savedItemRepositoryProvider).enrichSubreddits(unverified),
      );
    }
  }

  String _getSubredditInitial(String name) {
    final clean = name.replaceFirst(RegExp(r'^[ru][/_-]'), '').trim();
    if (clean.isEmpty) return 'R';
    return clean[0].toUpperCase();
  }

  Widget _buildSubredditPlaceholder(
    ColorScheme colorScheme,
    bool isUser,
    String subName,
  ) {
    if (isUser) {
      return Icon(
        Icons.person_rounded,
        color: colorScheme.onSecondaryContainer,
        size: 20,
      );
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
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<AsyncValue<List<SubredditInfo>>>(
      rawSubredditsWithCountsProvider,
      (_, next) => next.whenData(_maybeEnrichSubreddits),
    );
    ref.listen<int>(librarySubTabProvider, (_, next) {
      if (next == 1) {
        ref
            .read(rawSubredditsWithCountsProvider)
            .whenData(_maybeEnrichSubreddits);
      }
    });
    ref.listen<int>(selectedShellTabProvider, (_, next) {
      if (next == 1) {
        ref
            .read(rawSubredditsWithCountsProvider)
            .whenData(_maybeEnrichSubreddits);
      }
    });

    final subredditsAsync = ref.watch(filteredSubredditsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return subredditsAsync.when(
      data: (subreddits) {
        if (subreddits.isEmpty) {
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
        }

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 104),
          itemCount: subreddits.length,
          separatorBuilder: (context, _) => Divider(
            height: 1,
            indent: 68,
            endIndent: 14,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          itemBuilder: (context, index) {
            final item = subreddits[index];
            final subName = item.name;
            final isUser = SavedItem.isUserSubreddit(subName);

            return _LibraryEntryTile(
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
              ),
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading subreddits: $err')),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(rawAuthorsWithCountsProvider).whenData(_maybeEnrichAuthors);
    });
  }

  void _maybeEnrichAuthors(List<AuthorInfo> authors) {
    if (ref.read(selectedShellTabProvider) != 1 ||
        ref.read(librarySubTabProvider) != 2) {
      return;
    }
    final unverified = [
      for (final a in authors)
        if (!a.isVerified) a.name,
    ];
    if (unverified.isNotEmpty) {
      Future.microtask(
        () => ref.read(savedItemRepositoryProvider).enrichAuthors(unverified),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<AsyncValue<List<AuthorInfo>>>(
      rawAuthorsWithCountsProvider,
      (_, next) => next.whenData(_maybeEnrichAuthors),
    );
    ref.listen<int>(librarySubTabProvider, (_, next) {
      if (next == 2) {
        ref.read(rawAuthorsWithCountsProvider).whenData(_maybeEnrichAuthors);
      }
    });
    ref.listen<int>(selectedShellTabProvider, (_, next) {
      if (next == 1) {
        ref.read(rawAuthorsWithCountsProvider).whenData(_maybeEnrichAuthors);
      }
    });

    final authorsAsync = ref.watch(filteredAuthorsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return authorsAsync.when(
      data: (authors) {
        if (authors.isEmpty) {
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
        }

        final userPlaceholder = Icon(
          Icons.person_rounded,
          color: colorScheme.onSecondaryContainer,
          size: 20,
        );

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 104),
          itemCount: authors.length,
          separatorBuilder: (context, _) => Divider(
            height: 1,
            indent: 68,
            endIndent: 14,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          itemBuilder: (context, index) {
            final item = authors[index];
            final author = item.name;
            return _LibraryEntryTile(
              title: 'u/$author',
              count: item.count,
              iconUrl: item.iconUrl,
              isNsfw: item.isNsfw,
              avatarBackgroundColor: colorScheme.secondaryContainer,
              placeholder: userPlaceholder,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                ScopedFeedView.openAuthor(context, author);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading users: $err')),
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
        child: ClipOval(
          child: hasIcon
              ? ExtendedImage.network(
                  iconUrl!,
                  width: 40,
                  height: 40,
                  cacheWidth: 120,
                  fit: BoxFit.cover,
                  cache: true,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.completed) {
                      return null;
                    }
                    return placeholder;
                  },
                )
              : placeholder,
        ),
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
