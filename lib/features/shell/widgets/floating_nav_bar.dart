import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/features/import_export/import_view.dart';
import 'package:savedex/features/library/library_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/search/widgets/compact_filter_sheet.dart';
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

// icon adn label sizes
const double kNavBarTabIconSize = 21.0;
const double kNavBarTabLabelFontSize = 11.0;
const double kNavBarActionIconSize = 22.0;

class FloatingNavBar extends ConsumerWidget {
  const FloatingNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedShellTabProvider).clamp(0, 2);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // only watch providers relevant to the active tab to avoid unnecessary rebuilds
    final List<_ContextActionSpec> contextActions;
    if (selectedTab == 0) {
      final isSavedSearching = ref.watch(isSavedSearchExpandedProvider);
      final hasActiveNonSearchFilters = ref.watch(
        searchFilterViewModelProvider.select(
          (filter) =>
              filter.itemType != null ||
              filter.isStarred != null ||
              filter.selectedSubreddits.isNotEmpty ||
              filter.selectedAuthors.isNotEmpty ||
              filter.selectedFlairs.isNotEmpty ||
              filter.selectedMediaTypes.isNotEmpty ||
              filter.selectedCollectionIds.isNotEmpty ||
              filter.isNsfw != null ||
              filter.enrichmentStatus != null ||
              filter.dateRangeStart != null ||
              filter.dateRangeEnd != null,
        ),
      );

      contextActions = [
        if (isSavedSearching)
          _ContextActionSpec(
            key: 'saved_close_search',
            tooltip: 'Close Search',
            icon: Icons.close_rounded,
            isActive: true,
            onTap: () {
              HapticFeedback.lightImpact();
              ref
                  .read(isSavedSearchExpandedProvider.notifier)
                  .setExpanded(false);
            },
          )
        else
          _ContextActionSpec(
            key: 'saved_open_search',
            tooltip: 'Search Saved',
            icon: Icons.search_rounded,
            isActive: false,
            onTap: () {
              HapticFeedback.lightImpact();
              ref
                  .read(isSavedSearchExpandedProvider.notifier)
                  .setExpanded(true);
            },
          ),
        _ContextActionSpec(
          key: 'saved_filter',
          tooltip: 'Filter Saved Items',
          icon: Icons.tune_rounded,
          isActive: hasActiveNonSearchFilters,
          hasBadge: hasActiveNonSearchFilters,
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => const CompactFilterSheet(),
            );
          },
        ),
      ];
    } else if (selectedTab == 1) {
      final librarySubTab = ref.watch(librarySubTabProvider);
      if (librarySubTab == 0) {
        final collectionSort = ref.watch(collectionSortOptionProvider);
        contextActions = [
          _ContextActionSpec(
            key: 'library_new_collection',
            tooltip: 'New Collection',
            icon: Icons.add_rounded,
            isActive: false,
            onTap: () {
              HapticFeedback.lightImpact();
              showCollectionFormDialog(context);
            },
          ),
          _ContextActionSpec(
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
        final subredditSort = ref.watch(subredditSortOptionProvider);
        final hasSubSearch = ref.watch(
          subredditSearchQueryProvider.select((q) => q.trim().isNotEmpty),
        );
        contextActions = [
          _ContextActionSpec(
            key: 'library_search_subreddits',
            tooltip: 'Search Subreddits',
            icon: Icons.search_rounded,
            isActive: hasSubSearch,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(subredditSearchFocusTriggerProvider.notifier).trigger();
            },
          ),
          _ContextActionSpec(
            key: 'library_sort_subreddits',
            tooltip: 'Sort Subreddits: ${subredditSort.label}',
            icon: Icons.sort_rounded,
            isActive: subredditSort != SubredditSortOption.mostSaved,
            hasBadge: subredditSort != SubredditSortOption.mostSaved,
            onTap: () {
              HapticFeedback.lightImpact();
              _showSubredditSortSheet(context, ref);
            },
          ),
        ];
      }
    } else {
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
        _ContextActionSpec(
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
        _ContextActionSpec(
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

    final Alignment activeAlignment = switch (selectedTab) {
      0 => Alignment.centerLeft,
      1 => Alignment.center,
      _ => Alignment.centerRight,
    };

    // solid surface colors
    //TODO: BackdropFilter offscreen blur
    final dockSurface = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerHighest;
    final dockBorder = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.55 : 0.45,
    );
    final inactiveSlotFill = isDark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainer;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rightSectionWidth = contextActions.isEmpty
                ? 0.0
                : kNavBarIslandsSeparation +
                      (kNavBarActionButtonSize * 2) +
                      actionButtonsGap;

            // subtract rightSectionWidth and the left docks 2x border width
            // so the row never overflows its horizontal constraint
            final availableLeftInnerWidth =
                (constraints.maxWidth -
                        rightSectionWidth -
                        (mainIslandHorizontalPadding * 2) -
                        (kNavBarBorderWidth * 2))
                    .clamp(120.0, constraints.maxWidth);

            final maxEqualTabWidth =
                ((availableLeftInnerWidth - (mainIslandButtonGap * 2)) / 3)
                    .floorToDouble();

            final double effectiveTabWidth;
            if (shouldExpandTabs) {
              effectiveTabWidth = maxEqualTabWidth.clamp(
                44.0,
                kNavBarTabButtonMaxWidthWithLabel,
              );
            } else {
              effectiveTabWidth = maxEqualTabWidth.clamp(
                44.0,
                kNavBarTabButtonWidth,
              );
            }

            final mainTrackWidth =
                (effectiveTabWidth * 3) + (mainIslandButtonGap * 2);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: dockHeight,
                  padding: EdgeInsets.symmetric(
                    horizontal: mainIslandHorizontalPadding,
                    vertical: kNavBarIslandPadding,
                  ),
                  decoration: BoxDecoration(
                    color: dockSurface,
                    borderRadius: BorderRadius.circular(dockRadius),
                    border: Border.all(
                      color: dockBorder,
                      width: kNavBarBorderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.36 : 0.12,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: mainTrackWidth,
                    height: tabButtonHeight,
                    child: Stack(
                      children: [
                        // Unselected Squircle Slot Backgrounds (all 3 same width)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (int i = 0; i < 3; i++)
                              Container(
                                width: effectiveTabWidth,
                                height: tabButtonHeight,
                                decoration: BoxDecoration(
                                  color: inactiveSlotFill,
                                  borderRadius: BorderRadius.circular(
                                    kNavBarButtonRadius,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Sliding Active Squircle Indicator
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutBack,
                          alignment: activeAlignment,
                          child: Container(
                            width: effectiveTabWidth,
                            height: tabButtonHeight,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                kNavBarButtonRadius,
                              ),
                            ),
                          ),
                        ),

                        // Foreground Tab Squircle Buttons (Saved, Library, Settings)
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
                                      .read(
                                        savedScrollToTopTriggerProvider
                                            .notifier,
                                      )
                                      .trigger();
                                } else {
                                  ref
                                      .read(selectedShellTabProvider.notifier)
                                      .setTab(0);
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
                                ref
                                    .read(selectedShellTabProvider.notifier)
                                    .setTab(1);
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
                                ref
                                    .read(selectedShellTabProvider.notifier)
                                    .setTab(2);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (contextActions.isNotEmpty) ...[
                  const SizedBox(width: kNavBarIslandsSeparation),
                  _StandaloneFloatingActionButton(
                    spec: contextActions[0],
                    dockSurface: dockSurface,
                    dockBorder: dockBorder,
                    isDark: isDark,
                  ),
                  SizedBox(width: actionButtonsGap),
                  _StandaloneFloatingActionButton(
                    spec: contextActions[1],
                    dockSurface: dockSurface,
                    dockBorder: dockBorder,
                    isDark: isDark,
                  ),
                ],
              ],
            );
          },
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

  void _showSubredditSortSheet(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(subredditSortOptionProvider);
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
                        'Sort Subreddits',
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
                          ref
                              .read(subredditSortOptionProvider.notifier)
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
}

class _ContextActionSpec {
  final String key;
  final String tooltip;
  final IconData icon;
  final bool isActive;
  final bool hasBadge;
  final VoidCallback onTap;

  const _ContextActionSpec({
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

class _StandaloneFloatingActionButton extends StatelessWidget {
  final _ContextActionSpec spec;
  final Color dockSurface;
  final Color dockBorder;
  final bool isDark;

  const _StandaloneFloatingActionButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: kNavBarActionButtonSize,
        height: kNavBarActionButtonSize,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(kNavBarActionButtonRadius),
          border: Border.all(color: borderColor, width: kNavBarBorderWidth),
          boxShadow: [
            BoxShadow(
              color: spec.isActive
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
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
