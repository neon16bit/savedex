import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/features/import_export/import_view.dart';
import 'package:savedex/features/library/library_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/search/widgets/filter_sheet.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/shared/widgets/widgets.dart';

// icon + title underneath
const bool kShowNavBarLabels = false;

// dock tab buttons equally to fill available horizontal space
const bool kExpandNavBarTabsToAvailableSpace = false;

// height of the inner tab squircles when kShowNavBarLabels == false
const double kNavBarButtonSize = 48.0;

// height of the inner tab squircles when kShowNavBarLabels == true
const double kNavBarButtonHeightWithLabel = 54.0;

// base width of each of the 3 tab squircles when kShowNavBarLabels == false
const double kNavBarTabButtonWidth = 52.0;

// max width of each of the 3 tab squircles when kShowNavBarLabels == true
// expands equally across all 3 tabs using available screen width
const double kNavBarTabButtonMaxWidthWithLabel = 72.0;

// corner radius of each tab squircle inside the main dock
const double kNavBarButtonRadius = 14.0;

// border thickness of the floating dock and action buttons
const double kNavBarBorderWidth = 1.1;

// inner vertical padding of the main floating dock around its 3 tab squircles
const double kNavBarIslandPadding = 5.0;

// conditional horizontal padding inside the main navigation island
const double kNavBarMainIslandHorizontalPaddingIconOnly = 8.0;
const double kNavBarMainIslandHorizontalPaddingWithLabel = 5.0;

// conditional gap between the 3 tab squircle buttons inside the main island
const double kNavBarMainIslandButtonGapIconOnly = 10.0;
const double kNavBarMainIslandButtonGapWithLabel = 5.0;

// Size of each free floating action button
const double kNavBarActionButtonSize = 54.0;

// corner radius of free floating action button
const double kNavBarActionButtonRadius = 17.0;

// separation between two halves
const double kNavBarIslandsSeparation = 14.0;

// conditional gap between the two action buttons
const double kNavBarActionButtonsGapIconOnly = 8.0;
const double kNavBarActionButtonsGapWithLabel = 6.0;

// enable frosted glass blur for dock
const bool kEnableNavBarBlur = true;

// blur sigma for frosted glass
const double kNavBarBlurSigma = 16.0;

// surface opacity for frosted glass
const double kNavBarBlurAlphaDark = 0.82;
const double kNavBarBlurAlphaLight = 0.88;

// horizontal padding inside the expanded search bar
const double kNavBarSearchBarHorizontalPadding = 10.0;

// animation durations for morphing search bar
const Duration kNavBarExpandDuration = Duration(milliseconds: 320);
const Duration kNavBarFadeDuration = Duration(milliseconds: 200);

// height for the blooming filter card
const double kFilterCardCompactHeight = 420.0;

// icon adn label sizes
const double kNavBarTabIconSize = 21.0;
const double kNavBarTabLabelFontSize = 11.0;
const double kNavBarActionIconSize = 22.0;

class FloatingNavBar extends ConsumerStatefulWidget {
  const FloatingNavBar({super.key});

  @override
  ConsumerState<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends ConsumerState<FloatingNavBar> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final TextEditingController _librarySearchController;
  late final FocusNode _librarySearchFocusNode;
  Timer? _debounceTimer;
  bool _morphFromFilter = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode()..addListener(_onSearchFocusChanged);
    _librarySearchController = TextEditingController();
    _librarySearchFocusNode = FocusNode();
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      ref.read(isSavedSearchOpenedViaFilterProvider.notifier).setOpened(false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _librarySearchController.dispose();
    _librarySearchFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    _librarySearchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _closeSearch() {
    _dismissKeyboard();
    ref.read(isSavedSearchOpenedViaFilterProvider.notifier).setOpened(false);
    _debounceTimer?.cancel();
    _searchController.clear();
    ref.read(searchFilterViewModelProvider.notifier).setSearchQuery(null);
    ref.read(isSavedFilterExpandedProvider.notifier).setExpanded(false);
    ref.read(isSavedSearchExpandedProvider.notifier).setExpanded(false);
  }

  void _closeLibrarySearch() {
    if (ref.read(isLibrarySearchExpandedProvider)) {
      ref.read(isLibrarySearchExpandedProvider.notifier).setExpanded(false);
      return;
    }
    _dismissKeyboard();
    if (_librarySearchController.text.isNotEmpty) {
      _librarySearchController.clear();
    }
    ref.read(subredditSearchQueryProvider.notifier).clear();
    ref.read(userSearchQueryProvider.notifier).clear();
  }

  Widget _buildDockTabs({
    required double mainTrackWidth,
    required double tabButtonHeight,
    required double effectiveTabWidth,
    required Color inactiveSlotFill,
    required Alignment activeAlignment,
    required int selectedTab,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: mainTrackWidth,
      height: tabButtonHeight,
      child: Stack(
        children: [
          // background inactive slot fill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < 3; i++)
                Container(
                  width: effectiveTabWidth,
                  height: tabButtonHeight,
                  decoration: BoxDecoration(
                    color: inactiveSlotFill,
                    borderRadius: BorderRadius.circular(kNavBarButtonRadius),
                  ),
                ),
            ],
          ),

          // animated active tab indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            alignment: activeAlignment,
            child: Container(
              width: effectiveTabWidth,
              height: tabButtonHeight,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(kNavBarButtonRadius),
              ),
            ),
          ),

          // foreground tab buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SquircleNavTabButton(
                width: effectiveTabWidth,
                height: tabButtonHeight,
                label: 'Saved',
                tooltip: 'Saved',
                icon: Icons.bookmarks_outlined,
                selectedIcon: Icons.bookmarks_rounded,
                isSelected: selectedTab == 0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (selectedTab == 0) {
                    ref
                        .read(savedScrollToTopTriggerProvider.notifier)
                        .trigger();
                  } else {
                    ref.read(selectedShellTabProvider.notifier).setTab(0);
                  }
                },
              ),
              _SquircleNavTabButton(
                width: effectiveTabWidth,
                height: tabButtonHeight,
                label: 'Library',
                tooltip: 'Library',
                icon: Icons.folder_copy_outlined,
                selectedIcon: Icons.folder_copy_rounded,
                isSelected: selectedTab == 1,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedShellTabProvider.notifier).setTab(1);
                },
              ),
              _SquircleNavTabButton(
                width: effectiveTabWidth,
                height: tabButtonHeight,
                label: 'Settings',
                tooltip: 'Settings',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                isSelected: selectedTab == 2,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedShellTabProvider.notifier).setTab(2);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({
    required ColorScheme colorScheme,
    required bool isDark,
    required bool hasActiveNonSearchFilters,
    required bool isFilterExpanded,
    bool isLibraryMode = false,
    int librarySubTab = 0,
  }) {
    final controller = isLibraryMode
        ? _librarySearchController
        : _searchController;
    final focusNode = isLibraryMode
        ? _librarySearchFocusNode
        : _searchFocusNode;

    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(Icons.search_rounded, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: ValueKey(
              isLibraryMode ? 'library_search_field' : 'saved_search_field',
            ),
            controller: controller,
            focusNode: focusNode,
            onTap: isLibraryMode
                ? null
                : () {
                    ref
                        .read(isSavedSearchOpenedViaFilterProvider.notifier)
                        .setOpened(false);
                  },
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: isLibraryMode
                  ? (librarySubTab == 2
                        ? 'Search saved users...'
                        : 'Search saved subreddits...')
                  : 'Search saved items...',
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: isLibraryMode
                ? (val) {
                    final queryProvider = librarySubTab == 2
                        ? userSearchQueryProvider
                        : subredditSearchQueryProvider;
                    ref.read(queryProvider.notifier).setQuery(val);
                  }
                : (val) {
                    if (val.trim().isNotEmpty) {
                      ref
                          .read(isSavedSearchOpenedViaFilterProvider.notifier)
                          .setOpened(false);
                    }
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 250),
                      () {
                        ref
                            .read(searchFilterViewModelProvider.notifier)
                            .setSearchQuery(val.trim().isEmpty ? null : val);
                      },
                    );
                  },
            onSubmitted: isLibraryMode
                ? (val) {
                    final queryProvider = librarySubTab == 2
                        ? userSearchQueryProvider
                        : subredditSearchQueryProvider;
                    ref.read(queryProvider.notifier).setQuery(val);
                    _librarySearchFocusNode.unfocus();
                  }
                : (val) {
                    _debounceTimer?.cancel();
                    ref
                        .read(searchFilterViewModelProvider.notifier)
                        .setSearchQuery(val.trim().isEmpty ? null : val);
                    _searchFocusNode.unfocus();
                  },
          ),
        ),
        if (!isLibraryMode) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              if (isFilterExpanded) {
                ref
                    .read(isSavedFilterExpandedProvider.notifier)
                    .setExpanded(false);
              } else {
                ref
                    .read(isSavedSearchOpenedViaFilterProvider.notifier)
                    .setOpened(false);
                ref
                    .read(isSavedFilterExpandedProvider.notifier)
                    .setExpanded(true);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: (hasActiveNonSearchFilters || isFilterExpanded)
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  if (hasActiveNonSearchFilters)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
        ] else
          const SizedBox(width: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            if (isLibraryMode) {
              _closeLibrarySearch();
            } else {
              _closeSearch();
            }
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedShellTabProvider).clamp(0, 2);
    final isSavedSearching =
        selectedTab == 0 && ref.watch(isSavedSearchExpandedProvider);
    final isSavedFilterExpanded =
        selectedTab == 0 && ref.watch(isSavedFilterExpandedProvider);
    final librarySubTab = selectedTab == 1
        ? ref.watch(librarySubTabProvider)
        : 0;
    final isLibrarySearching =
        selectedTab == 1 &&
        librarySubTab >= 1 &&
        ref.watch(isLibrarySearchExpandedProvider);
    final isSearchMorphed = isSavedSearching || isLibrarySearching;

    ref.listen<bool>(isSavedSearchExpandedProvider, (prev, next) {
      if (next && (prev == null || !prev)) {
        final openedViaFilter = ref.read(isSavedSearchOpenedViaFilterProvider);
        if (_morphFromFilter != openedViaFilter) {
          setState(() {
            _morphFromFilter = openedViaFilter;
          });
        }
        final currentQuery =
            ref.read(searchFilterViewModelProvider).searchQuery ?? '';
        if (_searchController.text != currentQuery) {
          _searchController.text = currentQuery;
        }
      } else if (!next && prev == true) {
        _dismissKeyboard();
        _debounceTimer?.cancel();
        if (_searchController.text.isNotEmpty) {
          _searchController.clear();
        }
      }
    });

    ref.listen<String?>(
      searchFilterViewModelProvider.select((s) => s.searchQuery),
      (prev, next) {
        if (next == null && _searchController.text.isNotEmpty) {
          _searchController.clear();
          if (mounted) setState(() {});
        }
      },
    );

    ref.listen<bool>(isSavedFilterExpandedProvider, (prev, next) {
      if (prev == true && !next) {
        final openedViaFilter = ref.read(isSavedSearchOpenedViaFilterProvider);
        if (openedViaFilter) {
          _closeSearch();
        }
      }
    });

    ref.listen<bool>(isLibrarySearchExpandedProvider, (prev, next) {
      if (next && (prev == null || !prev)) {
        final activeSubTab = ref.read(librarySubTabProvider);
        final currentQuery = activeSubTab == 2
            ? ref.read(userSearchQueryProvider)
            : ref.read(subredditSearchQueryProvider);
        if (_librarySearchController.text != currentQuery) {
          _librarySearchController.text = currentQuery;
        }
      } else if (!next && prev == true) {
        _dismissKeyboard();
        if (_librarySearchController.text.isNotEmpty) {
          _librarySearchController.clear();
        }
        ref.read(subredditSearchQueryProvider.notifier).clear();
        ref.read(userSearchQueryProvider.notifier).clear();
      }
    });

    ref.listen<String>(subredditSearchQueryProvider, (prev, next) {
      if (ref.read(librarySubTabProvider) == 1 &&
          next.isEmpty &&
          _librarySearchController.text.isNotEmpty) {
        _librarySearchController.clear();
      }
    });
    ref.listen<String>(userSearchQueryProvider, (prev, next) {
      if (ref.read(librarySubTabProvider) == 2 &&
          next.isEmpty &&
          _librarySearchController.text.isNotEmpty) {
        _librarySearchController.clear();
      }
    });

    // queries are per sub-tab; close library search on sub-tab or shell-tab
    // switches so neither list keeps a hidden filter
    ref.listen<int>(librarySubTabProvider, (prev, next) {
      if (prev != next &&
          (ref.read(isLibrarySearchExpandedProvider) ||
              ref.read(subredditSearchQueryProvider).isNotEmpty ||
              ref.read(userSearchQueryProvider).isNotEmpty)) {
        _closeLibrarySearch();
      }
    });
    ref.listen<int>(selectedShellTabProvider, (prev, next) {
      if (prev == 1 &&
          next != 1 &&
          (ref.read(isLibrarySearchExpandedProvider) ||
              ref.read(subredditSearchQueryProvider).isNotEmpty ||
              ref.read(userSearchQueryProvider).isNotEmpty)) {
        _closeLibrarySearch();
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // only watch providers relevant to the active tab to avoid unnecessary rebuilds
    final List<ContextActionSpec> contextActions;
    final bool hasActiveNonSearchFilters;
    if (selectedTab == 0) {
      hasActiveNonSearchFilters = ref.watch(
        searchFilterViewModelProvider.select(
          (filter) => filter.hasActiveNonSearchFilters,
        ),
      );

      contextActions = [
        ContextActionSpec(
          key: 'saved_open_search',
          tooltip: 'Search Saved',
          icon: Icons.search_rounded,
          isActive: isSavedSearching,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _morphFromFilter = false;
            });
            ref
                .read(isSavedSearchOpenedViaFilterProvider.notifier)
                .setOpened(false);
            ref.read(isSavedSearchExpandedProvider.notifier).setExpanded(true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _searchFocusNode.canRequestFocus) {
                _searchFocusNode.requestFocus();
              }
            });
          },
        ),
        ContextActionSpec(
          key: 'saved_filter',
          tooltip: 'Filter Saved Items',
          icon: Icons.tune_rounded,
          isActive: hasActiveNonSearchFilters || isSavedFilterExpanded,
          hasBadge: hasActiveNonSearchFilters,
          onTap: () {
            HapticFeedback.lightImpact();
            if (isSavedFilterExpanded) {
              ref
                  .read(isSavedFilterExpandedProvider.notifier)
                  .setExpanded(false);
              return;
            }
            if (!isSavedSearching) {
              setState(() {
                _morphFromFilter = true;
              });
              ref
                  .read(isSavedSearchOpenedViaFilterProvider.notifier)
                  .setOpened(true);
              ref
                  .read(isSavedSearchExpandedProvider.notifier)
                  .setExpanded(true);
            } else {
              ref
                  .read(isSavedSearchOpenedViaFilterProvider.notifier)
                  .setOpened(false);
            }
            ref.read(isSavedFilterExpandedProvider.notifier).setExpanded(true);
          },
        ),
      ];
    } else if (selectedTab == 1) {
      hasActiveNonSearchFilters = false;
      if (librarySubTab == 0) {
        final collectionSort = ref.watch(collectionSortOptionProvider);
        contextActions = [
          ContextActionSpec(
            key: 'library_new_collection',
            tooltip: 'New Collection',
            icon: Icons.add_rounded,
            isActive: false,
            onTap: () {
              HapticFeedback.lightImpact();
              showCollectionFormDialog(context);
            },
          ),
          ContextActionSpec(
            key: 'library_sort_collections',
            tooltip: 'Sort Collections: ${collectionSort.label}',
            icon: Icons.sort_rounded,
            isActive: collectionSort != CollectionSortOption.newest,
            hasBadge: collectionSort != CollectionSortOption.newest,
            onTap: () {
              HapticFeedback.lightImpact();
              _showCollectionSortSheet(context, ref);
            },
          ),
        ];
      } else {
        final isUsers = librarySubTab == 2;
        final sortProvider = isUsers
            ? userSortOptionProvider
            : subredditSortOptionProvider;
        final listSort = ref.watch(sortProvider);
        final hasListSearch = ref.watch(
          (isUsers ? userSearchQueryProvider : subredditSearchQueryProvider)
              .select((q) => q.trim().isNotEmpty),
        );
        final noun = isUsers ? 'Users' : 'Subreddits';
        contextActions = [
          ContextActionSpec(
            key: 'library_search_${isUsers ? 'users' : 'subreddits'}',
            tooltip: 'Search $noun',
            icon: Icons.search_rounded,
            isActive: isLibrarySearching || hasListSearch,
            onTap: () {
              HapticFeedback.lightImpact();
              if (_morphFromFilter) {
                setState(() {
                  _morphFromFilter = false;
                });
              }
              ref
                  .read(isLibrarySearchExpandedProvider.notifier)
                  .setExpanded(true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _librarySearchFocusNode.canRequestFocus) {
                  _librarySearchFocusNode.requestFocus();
                }
              });
            },
          ),
          ContextActionSpec(
            key: 'library_sort_${isUsers ? 'users' : 'subreddits'}',
            tooltip: 'Sort $noun: ${listSort.label}',
            icon: Icons.sort_rounded,
            isActive: listSort != SubredditSortOption.mostSaved,
            hasBadge: listSort != SubredditSortOption.mostSaved,
            onTap: () {
              HapticFeedback.lightImpact();
              _showLibraryListSortSheet(context, ref, sortProvider, noun);
            },
          ),
        ];
      }
    } else {
      hasActiveNonSearchFilters = false;
      final themeMode = ref.watch(
        settingsViewModelProvider.select((s) => s.themeMode),
      );
      final IconData themeIcon;
      final String themeTooltip;
      switch (themeMode) {
        case ThemeMode.light:
          themeIcon = Icons.light_mode_rounded;
          themeTooltip = 'Theme: Light (Tap to switch)';
          break;
        case ThemeMode.dark:
          themeIcon = Icons.dark_mode_rounded;
          themeTooltip = 'Theme: Dark (Tap to switch)';
          break;
        case ThemeMode.system:
          themeIcon = Icons.brightness_auto_rounded;
          themeTooltip = 'Theme: System (Tap to switch)';
          break;
      }

      contextActions = [
        ContextActionSpec(
          key: 'settings_import_export',
          tooltip: 'Import & Export Data',
          icon: Icons.swap_vert_rounded,
          isActive: false,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ImportView()));
          },
        ),
        ContextActionSpec(
          key: 'settings_cycle_theme_${themeMode.name}',
          tooltip: themeTooltip,
          icon: themeIcon,
          isActive: false,
          onTap: () {
            HapticFeedback.lightImpact();
            final nextMode = switch (themeMode) {
              ThemeMode.system => ThemeMode.dark,
              ThemeMode.dark => ThemeMode.light,
              ThemeMode.light => ThemeMode.system,
            };
            ref.read(settingsViewModelProvider.notifier).setThemeMode(nextMode);
          },
        ),
      ];
    }

    final Alignment activeAlignment = switch (selectedTab) {
      0 => Alignment.centerLeft,
      1 => Alignment.center,
      _ => Alignment.centerRight,
    };

    final baseDockSurface = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerHighest;
    final dockSurface = kEnableNavBarBlur
        ? baseDockSurface.withValues(
            alpha: isDark ? kNavBarBlurAlphaDark : kNavBarBlurAlphaLight,
          )
        : baseDockSurface;
    final dockBorder = colorScheme.outlineVariant.withValues(
      alpha: isDark
          ? (kEnableNavBarBlur ? 0.40 : 0.55)
          : (kEnableNavBarBlur ? 0.35 : 0.45),
    );
    final inactiveSlotFill = isDark
        ? colorScheme.surfaceContainerHighest.withValues(
            alpha: kEnableNavBarBlur ? 0.65 : 1.0,
          )
        : colorScheme.surfaceContainer.withValues(
            alpha: kEnableNavBarBlur ? 0.65 : 1.0,
          );

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    return PopScope(
      canPop: !isSearchMorphed && !isSavedFilterExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isSavedFilterExpanded) {
          ref.read(isSavedFilterExpandedProvider.notifier).setExpanded(false);
        } else if (isSavedSearching) {
          _closeSearch();
        } else if (isLibrarySearching) {
          _closeLibrarySearch();
        }
      },
      child: SafeArea(
        top: false,
        bottom: !isKeyboardOpen,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, isKeyboardOpen ? 8 : 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 0) {
                return const SizedBox.shrink();
              }

              final m = NavBarLayoutMetrics.compute(
                context: context,
                maxAvailableWidth: constraints.maxWidth,
                actionCount: contextActions.length,
                bottomInset: bottomInset,
                isKeyboardOpen: isKeyboardOpen,
              );
              final tabButtonHeight = m.tabButtonHeight;
              final mainIslandHorizontalPadding = m.mainIslandHorizontalPadding;
              final dockHeight = m.dockHeight;
              final dockRadius = m.dockRadius;
              final effectiveTabWidth = m.effectiveTabWidth;
              final mainTrackWidth = m.mainTrackWidth;
              final dockWidth = m.dockWidth;
              final totalBarWidth = m.totalBarWidth;
              final barHeight = m.barHeight;
              final dockTop = m.dockTop;
              final actionButtonTop = m.actionButtonTop;
              final searchLeftNormal = m.searchLeftNormal;
              final filterLeftNormal = m.filterLeftNormal;
              final searchContentWidth = m.searchContentWidth;
              final cardHeight = m.cardHeight;

              return Center(
                child: SizedBox(
                  width: totalBarWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // filter panel morph
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        reverseDuration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return UnclippedSizeTransition(
                            sizeFactor: animation,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          );
                        },
                        child: isSavedFilterExpanded
                            ? Padding(
                                key: const ValueKey('filter_sheet_expanded'),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InteractiveFilterCard(
                                  width: totalBarWidth,
                                  height: cardHeight,
                                  onClose: () {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(
                                          isSavedFilterExpandedProvider
                                              .notifier,
                                        )
                                        .setExpanded(false);
                                  },
                                  child: FrostedNavBarIsland(
                                    width: totalBarWidth,
                                    height: cardHeight,
                                    borderRadius: 24.0,
                                    surfaceColor: dockSurface,
                                    borderColor: dockBorder,
                                    isDark: isDark,
                                    customShadow: const BoxShadow(
                                      color: Colors.transparent,
                                    ),
                                    child: FilterSheet(
                                      isFloatingCard: true,
                                      onClose: () {
                                        HapticFeedback.lightImpact();
                                        ref
                                            .read(
                                              isSavedFilterExpandedProvider
                                                  .notifier,
                                            )
                                            .setExpanded(false);
                                      },
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('filter_sheet_collapsed'),
                              ),
                      ),

                      // search bar stack
                      SizedBox(
                        width: totalBarWidth,
                        height: barHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // main dock
                            Positioned(
                              left: 0,
                              top: dockTop,
                              width: dockWidth,
                              height: dockHeight,
                              child: AnimatedOpacity(
                                duration: kNavBarFadeDuration,
                                curve: Curves.easeOut,
                                opacity: isSearchMorphed ? 0.0 : 1.0,
                                child: IgnorePointer(
                                  ignoring: isSearchMorphed,
                                  child: FrostedNavBarIsland(
                                    width: dockWidth,
                                    height: dockHeight,
                                    borderRadius: dockRadius,
                                    surfaceColor: dockSurface,
                                    borderColor: dockBorder,
                                    isDark: isDark,
                                    enableBlur:
                                        kEnableNavBarBlur && !isSearchMorphed,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: mainIslandHorizontalPadding,
                                      vertical: kNavBarIslandPadding,
                                    ),
                                    child: SizedBox(
                                      height: tabButtonHeight,
                                      child: _buildDockTabs(
                                        mainTrackWidth: mainTrackWidth,
                                        tabButtonHeight: tabButtonHeight,
                                        effectiveTabWidth: effectiveTabWidth,
                                        inactiveSlotFill: inactiveSlotFill,
                                        activeAlignment: activeAlignment,
                                        selectedTab: selectedTab,
                                        colorScheme: colorScheme,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            if (selectedTab == 0 &&
                                _morphFromFilter &&
                                contextActions.length > 1) ...[
                              Positioned(
                                key: const ValueKey('static_search_action'),
                                left: searchLeftNormal,
                                top: actionButtonTop,
                                width: kNavBarActionButtonSize,
                                height: kNavBarActionButtonSize,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  opacity: isSearchMorphed ? 0.0 : 1.0,
                                  child: IgnorePointer(
                                    ignoring: isSearchMorphed,
                                    child: StandaloneFloatingActionButton(
                                      spec: contextActions[0],
                                      dockSurface: dockSurface,
                                      dockBorder: dockBorder,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ),

                              AnimatedPositioned(
                                key: const ValueKey('morph_filter_action'),
                                duration: kNavBarExpandDuration,
                                curve: Curves.fastOutSlowIn,
                                left: isSearchMorphed ? 0.0 : filterLeftNormal,
                                top: isSearchMorphed
                                    ? dockTop
                                    : actionButtonTop,
                                width: isSearchMorphed
                                    ? totalBarWidth
                                    : kNavBarActionButtonSize,
                                height: isSearchMorphed
                                    ? dockHeight
                                    : kNavBarActionButtonSize,
                                child: isSearchMorphed
                                    ? FrostedNavBarIsland(
                                        animate: true,
                                        animationDuration:
                                            kNavBarExpandDuration,
                                        animationCurve: Curves.fastOutSlowIn,
                                        borderRadius: dockRadius,
                                        surfaceColor: dockSurface,
                                        borderColor: dockBorder,
                                        isDark: isDark,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal:
                                              kNavBarSearchBarHorizontalPadding,
                                          vertical: kNavBarIslandPadding,
                                        ),
                                        child: SizedBox(
                                          height: tabButtonHeight,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            child: SizedBox(
                                              width: searchContentWidth,
                                              height: tabButtonHeight,
                                              child: _buildSearchBar(
                                                colorScheme: colorScheme,
                                                isDark: isDark,
                                                hasActiveNonSearchFilters:
                                                    hasActiveNonSearchFilters,
                                                isFilterExpanded:
                                                    isSavedFilterExpanded,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : StandaloneFloatingActionButton(
                                        spec: contextActions[1],
                                        dockSurface: dockSurface,
                                        dockBorder: dockBorder,
                                        isDark: isDark,
                                      ),
                              ),
                            ] else ...[
                              if (contextActions.length > 1)
                                Positioned(
                                  key: const ValueKey('static_filter_action'),
                                  left: filterLeftNormal,
                                  top: actionButtonTop,
                                  width: kNavBarActionButtonSize,
                                  height: kNavBarActionButtonSize,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    opacity: isSearchMorphed ? 0.0 : 1.0,
                                    child: IgnorePointer(
                                      ignoring: isSearchMorphed,
                                      child: StandaloneFloatingActionButton(
                                        spec: contextActions[1],
                                        dockSurface: dockSurface,
                                        dockBorder: dockBorder,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),
                                ),

                              if (contextActions.isNotEmpty)
                                AnimatedPositioned(
                                  key: const ValueKey('morph_search_action'),
                                  duration: kNavBarExpandDuration,
                                  curve: Curves.fastOutSlowIn,
                                  left: isSearchMorphed
                                      ? 0.0
                                      : searchLeftNormal,
                                  top: isSearchMorphed
                                      ? dockTop
                                      : actionButtonTop,
                                  width: isSearchMorphed
                                      ? totalBarWidth
                                      : kNavBarActionButtonSize,
                                  height: isSearchMorphed
                                      ? dockHeight
                                      : kNavBarActionButtonSize,
                                  child: isSearchMorphed
                                      ? FrostedNavBarIsland(
                                          animate: true,
                                          animationDuration:
                                              kNavBarExpandDuration,
                                          animationCurve: Curves.fastOutSlowIn,
                                          borderRadius: dockRadius,
                                          surfaceColor: dockSurface,
                                          borderColor: dockBorder,
                                          isDark: isDark,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                kNavBarSearchBarHorizontalPadding,
                                            vertical: kNavBarIslandPadding,
                                          ),
                                          child: SizedBox(
                                            height: tabButtonHeight,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              child: SizedBox(
                                                width: searchContentWidth,
                                                height: tabButtonHeight,
                                                child: _buildSearchBar(
                                                  colorScheme: colorScheme,
                                                  isDark: isDark,
                                                  hasActiveNonSearchFilters:
                                                      hasActiveNonSearchFilters,
                                                  isFilterExpanded:
                                                      isSavedFilterExpanded,
                                                  isLibraryMode:
                                                      isLibrarySearching,
                                                  librarySubTab: librarySubTab,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : StandaloneFloatingActionButton(
                                          spec: contextActions[0],
                                          dockSurface: dockSurface,
                                          dockBorder: dockBorder,
                                          isDark: isDark,
                                        ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCollectionSortSheet(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(collectionSortOptionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sort Collections',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...CollectionSortOption.values.map((option) {
                  final isSelected = option == currentSort;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          ref
                              .read(collectionSortOptionProvider.notifier)
                              .setSort(option);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
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
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLibraryListSortSheet(
    BuildContext context,
    WidgetRef ref,
    NotifierProvider<SubredditSortNotifier, SubredditSortOption> sortProvider,
    String noun,
  ) {
    final currentSort = ref.read(sortProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sort $noun',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...SubredditSortOption.values.map((option) {
                  final isSelected = option == currentSort;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          ref.read(sortProvider.notifier).setSort(option);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
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
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NavBarLayoutMetrics {
  final double tabButtonHeight;
  final double mainIslandHorizontalPadding;
  final double mainIslandButtonGap;
  final double actionButtonsGap;
  final double dockHeight;
  final double dockRadius;
  final double effectiveTabWidth;
  final double mainTrackWidth;
  final double dockWidth;
  final double totalBarWidth;
  final double barHeight;
  final double dockTop;
  final double actionButtonTop;
  final double searchLeftNormal;
  final double filterLeftNormal;
  final double searchContentWidth;
  final double cardHeight;

  const NavBarLayoutMetrics({
    required this.tabButtonHeight,
    required this.mainIslandHorizontalPadding,
    required this.mainIslandButtonGap,
    required this.actionButtonsGap,
    required this.dockHeight,
    required this.dockRadius,
    required this.effectiveTabWidth,
    required this.mainTrackWidth,
    required this.dockWidth,
    required this.totalBarWidth,
    required this.barHeight,
    required this.dockTop,
    required this.actionButtonTop,
    required this.searchLeftNormal,
    required this.filterLeftNormal,
    required this.searchContentWidth,
    required this.cardHeight,
  });

  factory NavBarLayoutMetrics.compute({
    required BuildContext context,
    required double maxAvailableWidth,
    required int actionCount,
    required double bottomInset,
    required bool isKeyboardOpen,
  }) {
    const shouldExpandTabs =
        kShowNavBarLabels || kExpandNavBarTabsToAvailableSpace;

    final tabButtonHeight = kShowNavBarLabels
        ? kNavBarButtonHeightWithLabel
        : kNavBarButtonSize;
    final mainIslandHorizontalPadding = shouldExpandTabs
        ? kNavBarMainIslandHorizontalPaddingWithLabel
        : kNavBarMainIslandHorizontalPaddingIconOnly;
    final mainIslandButtonGap = shouldExpandTabs
        ? kNavBarMainIslandButtonGapWithLabel
        : kNavBarMainIslandButtonGapIconOnly;
    final actionButtonsGap = shouldExpandTabs
        ? kNavBarActionButtonsGapWithLabel
        : kNavBarActionButtonsGapIconOnly;

    final dockHeight = tabButtonHeight + (kNavBarIslandPadding * 2);
    final dockRadius = kNavBarButtonRadius + kNavBarIslandPadding;

    final rightSectionWidth = actionCount <= 0
        ? 0.0
        : kNavBarIslandsSeparation +
              (kNavBarActionButtonSize * actionCount) +
              (actionButtonsGap * (actionCount - 1));

    final minAllowedWidth = 120.0 > maxAvailableWidth
        ? maxAvailableWidth
        : 120.0;

    final availableLeftInnerWidth =
        (maxAvailableWidth -
                rightSectionWidth -
                (mainIslandHorizontalPadding * 2) -
                (kNavBarBorderWidth * 2))
            .clamp(minAllowedWidth, maxAvailableWidth);

    final maxEqualTabWidth =
        ((availableLeftInnerWidth - (mainIslandButtonGap * 2)) / 3)
            .floorToDouble();

    final targetMaxWidth = shouldExpandTabs
        ? kNavBarTabButtonMaxWidthWithLabel
        : kNavBarTabButtonWidth;
    final minTabWidth = 44.0 > targetMaxWidth ? targetMaxWidth : 44.0;
    final effectiveTabWidth = maxEqualTabWidth.clamp(
      minTabWidth,
      targetMaxWidth,
    );

    final mainTrackWidth = (effectiveTabWidth * 3) + (mainIslandButtonGap * 2);

    final dockWidth =
        mainTrackWidth +
        (mainIslandHorizontalPadding * 2) +
        (kNavBarBorderWidth * 2);

    final totalBarWidth = (dockWidth + rightSectionWidth).clamp(
      minAllowedWidth,
      maxAvailableWidth,
    );

    final barHeight = dockHeight > kNavBarActionButtonSize
        ? dockHeight
        : kNavBarActionButtonSize;
    final dockTop = (barHeight - dockHeight) / 2;
    final actionButtonTop = (barHeight - kNavBarActionButtonSize) / 2;

    final searchLeftNormal = dockWidth + kNavBarIslandsSeparation;
    final filterLeftNormal =
        searchLeftNormal + kNavBarActionButtonSize + actionButtonsGap;

    final searchContentWidth =
        (totalBarWidth - (kNavBarSearchBarHorizontalPadding * 2)).clamp(
          0.0,
          totalBarWidth,
        );

    final screenHeight = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;
    final availableHeightAboveBar =
        screenHeight -
        bottomInset -
        barHeight -
        (isKeyboardOpen ? 12 : 24) -
        topPadding;
    final cardHeight =
        (availableHeightAboveBar - (isKeyboardOpen ? 12.0 : 80.0)).clamp(
          220.0,
          kFilterCardCompactHeight,
        );

    return NavBarLayoutMetrics(
      tabButtonHeight: tabButtonHeight,
      mainIslandHorizontalPadding: mainIslandHorizontalPadding,
      mainIslandButtonGap: mainIslandButtonGap,
      actionButtonsGap: actionButtonsGap,
      dockHeight: dockHeight,
      dockRadius: dockRadius,
      effectiveTabWidth: effectiveTabWidth,
      mainTrackWidth: mainTrackWidth,
      dockWidth: dockWidth,
      totalBarWidth: totalBarWidth,
      barHeight: barHeight,
      dockTop: dockTop,
      actionButtonTop: actionButtonTop,
      searchLeftNormal: searchLeftNormal,
      filterLeftNormal: filterLeftNormal,
      searchContentWidth: searchContentWidth,
      cardHeight: cardHeight,
    );
  }
}

class ContextActionSpec {
  final String key;
  final String tooltip;
  final IconData icon;
  final bool isActive;
  final bool hasBadge;
  final VoidCallback onTap;

  const ContextActionSpec({
    required this.key,
    required this.tooltip,
    required this.icon,
    required this.isActive,
    this.hasBadge = false,
    required this.onTap,
  });
}

class _SquircleNavTabButton extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SquircleNavTabButton({
    required this.width,
    required this.height,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: kShowNavBarLabels
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? selectedIcon : icon,
                          key: ValueKey<bool>(isSelected),
                          size: kNavBarTabIconSize,
                          color: foregroundColor,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: kNavBarTabLabelFontSize,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: foregroundColor,
                            letterSpacing: -0.2,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  )
                : Icon(
                    isSelected ? selectedIcon : icon,
                    key: ValueKey<bool>(isSelected),
                    size: kNavBarTabIconSize,
                    color: foregroundColor,
                  ),
          ),
        ),
      ),
    );
  }
}

class _BottomClipper extends CustomClipper<Rect> {
  static const double _extra = 32.0;
  const _BottomClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(-_extra, 0.0, size.width + _extra, size.height);
  }

  @override
  bool shouldReclip(_BottomClipper oldClipper) => false;
}

class UnclippedSizeTransition extends AnimatedWidget {
  final Widget child;
  final Alignment alignment;

  const UnclippedSizeTransition({
    super.key,
    required Animation<double> sizeFactor,
    this.alignment = Alignment.bottomCenter,
    required this.child,
  }) : super(listenable: sizeFactor);

  Animation<double> get sizeFactor => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: const _BottomClipper(),
      child: Align(
        alignment: alignment,
        heightFactor: sizeFactor.value.clamp(0.0, 1.0),
        child: child,
      ),
    );
  }
}

class InteractiveFilterCard extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback onClose;
  final Widget child;

  const InteractiveFilterCard({
    super.key,
    required this.width,
    required this.height,
    required this.onClose,
    required this.child,
  });

  @override
  State<InteractiveFilterCard> createState() => _InteractiveFilterCardState();
}

class _InteractiveFilterCardState extends State<InteractiveFilterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Animation<double>? _offsetAnim;
  double _dragOffset = 0.0;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
    _animController.addListener(() {
      if (_offsetAnim != null) {
        setState(() {
          _dragOffset = _offsetAnim!.value;
        });
      }
    });
    _animController.addStatusListener((status) {
      if (mounted && status == AnimationStatus.completed && _isDismissing) {
        widget.onClose();
      }
    });
  }

  @override
  void didUpdateWidget(InteractiveFilterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragOffset > widget.height) {
      _dragOffset = widget.height;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleDragStart() {
    if (_isDismissing) return;
    if (_animController.isAnimating) {
      _animController.stop();
    }
  }

  void _handleDragUpdate(double delta) {
    if (_isDismissing) return;
    if (_animController.isAnimating) {
      _animController.stop();
    }

    // delta > 0 is downward motion
    final current = _dragOffset;
    if (current <= 0.0 && delta <= 0.0) return;

    final next = (current + delta).clamp(0.0, widget.height);
    if (next != _dragOffset) {
      setState(() {
        _dragOffset = next;
      });
    }
  }

  void _handleDragEnd(double velocity) {
    if (_isDismissing) return;

    final distanceThreshold = (widget.height * 0.22).clamp(64.0, 96.0);
    final isFlingDown = velocity >= 320.0;
    final isFlingUp = velocity <= -180.0;
    final isPastDistance = _dragOffset >= distanceThreshold;

    final shouldDismiss = (isPastDistance || isFlingDown) && !isFlingUp;

    if (shouldDismiss) {
      _isDismissing = true;
      HapticFeedback.lightImpact();
      _offsetAnim = Tween<double>(begin: _dragOffset, end: widget.height)
          .animate(
            CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            ),
          );
      final remaining = (widget.height - _dragOffset).clamp(0.0, widget.height);
      final durationMs = (remaining / widget.height * 220)
          .clamp(140.0, 220.0)
          .toInt();
      _animController.duration = Duration(milliseconds: durationMs);
      _animController.forward(from: 0.0);
    } else {
      if (_dragOffset > 0.0) {
        HapticFeedback.selectionClick();
        _offsetAnim = Tween<double>(begin: _dragOffset, end: 0.0).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
        );
        _animController.duration = const Duration(milliseconds: 240);
        _animController.forward(from: 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<FilterCardDragNotification>(
      onNotification: (notification) {
        if (notification is FilterCardDragUpdateNotification) {
          _handleDragUpdate(notification.delta);
          return true;
        } else if (notification is FilterCardDragEndNotification) {
          _handleDragEnd(notification.velocity);
          return true;
        } else if (notification is FilterCardDragCancelNotification) {
          _handleDragStart();
          return true;
        }
        return false;
      },
      child: ClipRect(
        clipper: const _BottomClipper(),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class FrostedNavBarIsland extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDark;
  final bool enableBlur;
  final EdgeInsetsGeometry? padding;
  final bool animate;
  final Duration animationDuration;
  final Curve animationCurve;
  final BoxShadow? customShadow;
  final Widget child;

  const FrostedNavBarIsland({
    super.key,
    this.width,
    this.height,
    required this.borderRadius,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDark,
    this.enableBlur = kEnableNavBarBlur,
    this.padding,
    this.animate = false,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.linear,
    this.customShadow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final List<BoxShadow> shadows;
    if (customShadow != null) {
      shadows = customShadow!.color == Colors.transparent
          ? const []
          : [customShadow!];
    } else {
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    }

    final radius = BorderRadius.circular(borderRadius);

    if (!enableBlur) {
      if (animate) {
        return AnimatedContainer(
          duration: animationDuration,
          curve: animationCurve,
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: kNavBarBorderWidth),
            boxShadow: shadows,
          ),
          child: child,
        );
      }
      return Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: kNavBarBorderWidth),
          boxShadow: shadows,
        ),
        child: child,
      );
    }

    if (animate) {
      return AnimatedContainer(
        duration: animationDuration,
        curve: animationCurve,
        width: width,
        height: height,
        decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: kNavBarBlurSigma,
              sigmaY: kNavBarBlurSigma,
            ),
            child: AnimatedContainer(
              duration: animationDuration,
              curve: animationCurve,
              padding: padding,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: radius,
                border: Border.all(
                  color: borderColor,
                  width: kNavBarBorderWidth,
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: kNavBarBlurSigma,
            sigmaY: kNavBarBlurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: kNavBarBorderWidth),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class StandaloneFloatingActionButton extends StatelessWidget {
  final ContextActionSpec spec;
  final Color dockSurface;
  final Color dockBorder;
  final bool isDark;

  const StandaloneFloatingActionButton({
    super.key,
    required this.spec,
    required this.dockSurface,
    required this.dockBorder,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = spec.isActive ? colorScheme.primary : dockSurface;
    final foregroundColor = spec.isActive
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final borderColor = spec.isActive
        ? colorScheme.primary.withValues(alpha: 0.85)
        : dockBorder;

    return Tooltip(
      message: spec.tooltip,
      child: FrostedNavBarIsland(
        width: kNavBarActionButtonSize,
        height: kNavBarActionButtonSize,
        borderRadius: kNavBarActionButtonRadius,
        surfaceColor: fill,
        borderColor: borderColor,
        isDark: isDark,
        enableBlur: kEnableNavBarBlur,
        customShadow: spec.isActive
            ? BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(kNavBarActionButtonRadius),
            onTap: spec.onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.65,
                        end: 1.0,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    spec.icon,
                    key: ValueKey<String>(spec.key),
                    size: kNavBarActionIconSize,
                    color: foregroundColor,
                  ),
                ),
                if (spec.hasBadge)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: spec.isActive
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
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
