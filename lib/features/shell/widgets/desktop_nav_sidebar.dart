import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/utils/responsive_layout.dart';
import 'package:savedex/features/import_export/import_view.dart';
import 'package:savedex/features/settings/settings_view.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class DesktopNavSidebar extends ConsumerWidget {
  final bool extended;
  final VoidCallback onToggleExtended;

  const DesktopNavSidebar({
    super.key,
    required this.extended,
    required this.onToggleExtended,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedShellTabProvider).clamp(0, 2);
    final (isRedditConnected, redditUsername) = ref.watch(
      settingsViewModelProvider.select(
        (s) => (s.isAuthenticatedWithOAuth, s.redditUsername),
      ),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hasRedditUsername =
        redditUsername != null && redditUsername.isNotEmpty;
    final redditLabel = isRedditConnected && hasRedditUsername
        ? 'u/$redditUsername'
        : 'Reddit Account';
    final redditTooltip = isRedditConnected
        ? (hasRedditUsername
              ? 'Reddit Account (u/$redditUsername)'
              : 'Reddit Account (Connected)')
        : 'Reddit Account';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: extended ? kDesktopSidebarExpandedWidth : kDesktopSidebarRailWidth,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.30 : 0.28,
            ),
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = extended && constraints.maxWidth >= 156.0;
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: CustomScrollView(
                primary: false,
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SidebarHeaderLogoToggle(
                            isExtended: showLabels,
                            onToggle: onToggleExtended,
                          ),
                          const SizedBox(height: 18),
                          _SidebarNavItem(
                            label: 'Saved',
                            showLabel: showLabels,
                            isSelected: selectedTab == 0,
                            iconBuilder: (fg) => SavedexLogo(
                              size: 20,
                              filled: selectedTab == 0,
                              color: fg,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (selectedTab == 0) {
                                ref
                                    .read(
                                      savedScrollToTopTriggerProvider.notifier,
                                    )
                                    .trigger();
                              } else {
                                ref
                                    .read(selectedShellTabProvider.notifier)
                                    .setTab(0);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _SidebarNavItem(
                            label: 'Library',
                            showLabel: showLabels,
                            isSelected: selectedTab == 1,
                            iconBuilder: (fg) => Icon(
                              selectedTab == 1
                                  ? Icons.folder_copy_rounded
                                  : Icons.folder_copy_outlined,
                              size: 20,
                              color: fg,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(selectedShellTabProvider.notifier)
                                  .setTab(1);
                            },
                          ),
                          const Spacer(),
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SidebarUtilityItem(
                            label: 'Import & Sync',
                            tooltip: 'Import & Sync Data',
                            showLabel: showLabels,
                            icon: Icons.swap_vert_rounded,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ImportView(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _SidebarUtilityItem(
                            label: redditLabel,
                            tooltip: redditTooltip,
                            showLabel: showLabels,
                            icon: isRedditConnected
                                ? Icons.verified_user_outlined
                                : Icons.vpn_key_outlined,
                            iconColor: isRedditConnected
                                ? colorScheme.primary
                                : null,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              SettingsView.showApiCredentialsDialog(context);
                            },
                          ),
                          const SizedBox(height: 8),
                          _SidebarNavItem(
                            label: 'Settings',
                            showLabel: showLabels,
                            isSelected: selectedTab == 2,
                            iconBuilder: (fg) => Icon(
                              selectedTab == 2
                                  ? Icons.settings_rounded
                                  : Icons.settings_outlined,
                              size: 20,
                              color: fg,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(selectedShellTabProvider.notifier)
                                  .setTab(2);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SidebarHeaderLogoToggle extends StatefulWidget {
  final bool isExtended;
  final VoidCallback onToggle;

  const _SidebarHeaderLogoToggle({
    required this.isExtended,
    required this.onToggle,
  });

  @override
  State<_SidebarHeaderLogoToggle> createState() =>
      _SidebarHeaderLogoToggleState();
}

class _SidebarHeaderLogoToggleState extends State<_SidebarHeaderLogoToggle> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(covariant _SidebarHeaderLogoToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExtended != widget.isExtended) {
      _isHovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.isExtended) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 44,
              child: Center(
                child: SavedexLogo(
                  key: const ValueKey('sidebar_logo'),
                  size: 26,
                  filled: true,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Savedex',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.view_sidebar_outlined, size: 20),
              tooltip: 'Collapse sidebar',
              visualDensity: VisualDensity.compact,
              color: colorScheme.onSurfaceVariant,
              onPressed: widget.onToggle,
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Expand sidebar',
        child: Tooltip(
          message: 'Expand sidebar',
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 300),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
              onTap: widget.onToggle,
              onHover: (hovered) {
                if (mounted && _isHovered != hovered) {
                  setState(() => _isHovered = hovered);
                }
              },
              child: SizedBox(
                width: 48,
                height: 44,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.85,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isHovered
                        ? Icon(
                            Icons.view_sidebar_rounded,
                            key: const ValueKey('sidebar_expand_icon'),
                            size: 22,
                            color: colorScheme.primary,
                          )
                        : SavedexLogo(
                            key: const ValueKey('sidebar_logo'),
                            size: 26,
                            filled: true,
                            color: colorScheme.primary,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final String label;
  final bool showLabel;
  final bool isSelected;
  final Widget Function(Color foreground) iconBuilder;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.label,
    required this.showLabel,
    required this.isSelected,
    required this.iconBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fgColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final bgColor = isSelected
        ? colorScheme.primary
        : colorScheme.surfaceContainerLow;
    final borderRadius = BorderRadius.circular(14);

    final button = Material(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        hoverColor: isSelected
            ? colorScheme.onPrimary.withValues(alpha: 0.08)
            : colorScheme.onSurface.withValues(alpha: 0.06),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 44,
                child: Center(child: iconBuilder(fgColor)),
              ),
              if (showLabel)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: fgColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      child: Tooltip(
        message: showLabel ? '' : label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: button,
      ),
    );
  }
}

class _SidebarUtilityItem extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool showLabel;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SidebarUtilityItem({
    required this.label,
    required this.tooltip,
    required this.showLabel,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.onSurfaceVariant;
    final borderRadius = BorderRadius.circular(12);

    final button = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 42,
                child: Center(
                  child: Icon(icon, size: 20, color: effectiveIconColor),
                ),
              ),
              if (showLabel)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final resolvedTooltip = (showLabel && tooltip == label) ? '' : tooltip;
    return Semantics(
      container: true,
      button: true,
      child: Tooltip(
        message: resolvedTooltip,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: button,
      ),
    );
  }
}
