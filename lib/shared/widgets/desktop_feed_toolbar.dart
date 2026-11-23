import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/responsive_layout.dart';
import 'package:savedex/shared/widgets/frosted_surface.dart';

class DesktopInlineSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;
  final double maxWidth;

  const DesktopInlineSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    required this.onClear,
    this.maxWidth = 360.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 36),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: onClear,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh.withValues(
                alpha: isDark ? 0.72 : 0.78,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.75),
                  width: 1.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DesktopFeedLayoutSwitcher extends StatelessWidget {
  final FeedLayoutMode currentMode;
  final ValueChanged<FeedLayoutMode> onChanged;

  const DesktopFeedLayoutSwitcher({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(
          alpha: isDark ? 0.75 : 0.85,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in FeedLayoutMode.values)
            _LayoutModeButton(
              mode: mode,
              isSelected: mode == currentMode,
              onTap: () => onChanged(mode),
            ),
        ],
      ),
    );
  }
}

class _LayoutModeButton extends StatelessWidget {
  final FeedLayoutMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutModeButton({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(9);

    return Tooltip(
      message: '${mode.label} view',
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: isSelected ? null : onTap,
          child: SizedBox(
            width: 32,
            height: 30,
            child: Icon(
              mode.icon,
              size: 17,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopFilterToggleButton extends StatelessWidget {
  final bool isOpen;
  final bool hasActiveFilters;
  final bool showLabel;
  final VoidCallback onPressed;

  const DesktopFilterToggleButton({
    super.key,
    required this.isOpen,
    required this.hasActiveFilters,
    this.showLabel = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighlighted = isOpen || hasActiveFilters;
    final bgColor = isOpen
        ? colorScheme.primaryContainer
        : (hasActiveFilters
              ? colorScheme.primaryContainer.withValues(alpha: 0.55)
              : Colors.transparent);
    final fgColor = isHighlighted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final borderRadius = BorderRadius.circular(12);

    return Tooltip(
      message: isOpen ? 'Hide Filters' : 'Filters',
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: isHighlighted
                ? colorScheme.primary.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 11 : 9,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.tune_rounded, size: 19, color: fgColor),
                      if (hasActiveFilters)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: fgColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopFilterPanelHost extends StatefulWidget {
  final bool enabled;
  final bool isOpen;
  final double availableWidth;
  final double topPadding;
  final bool enableFrosted;
  final VoidCallback onClose;
  final Widget feedChild;
  final Widget filterSheetChild;

  const DesktopFilterPanelHost({
    super.key,
    this.enabled = true,
    required this.isOpen,
    required this.availableWidth,
    required this.topPadding,
    required this.enableFrosted,
    required this.onClose,
    required this.feedChild,
    required this.filterSheetChild,
  });

  @override
  State<DesktopFilterPanelHost> createState() => _DesktopFilterPanelHostState();
}

class _DesktopFilterPanelHostState extends State<DesktopFilterPanelHost> {
  final GlobalKey _feedKey = GlobalKey();
  final GlobalKey _filterSheetKey = GlobalKey();
  late bool _keepFilterMounted = widget.isOpen;

  @override
  void didUpdateWidget(covariant DesktopFilterPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDocked = oldWidget.availableWidth >= kDesktopDockedFilterMinWidth;
    final newDocked = widget.availableWidth >= kDesktopDockedFilterMinWidth;
    if (widget.isOpen && !_keepFilterMounted) {
      _keepFilterMounted = true;
    } else if ((!widget.enabled || oldDocked != newDocked) &&
        !widget.isOpen &&
        _keepFilterMounted) {
      _keepFilterMounted = false;
    }
  }

  void _handleCloseEnd() {
    if (mounted && !widget.isOpen && _keepFilterMounted) {
      setState(() => _keepFilterMounted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyedFeed = KeyedSubtree(key: _feedKey, child: widget.feedChild);
    if (!widget.enabled) {
      return keyedFeed;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useDockedPanel =
        widget.availableWidth >= kDesktopDockedFilterMinWidth;
    final showFilterChild = widget.isOpen || _keepFilterMounted;
    final keyedFilterSheet = KeyedSubtree(
      key: _filterSheetKey,
      child: widget.filterSheetChild,
    );

    if (useDockedPanel) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            key: const ValueKey('desktop_filter_host_feed_pane'),
            child: keyedFeed,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            onEnd: _handleCloseEnd,
            width: widget.isOpen ? kDesktopFilterPanelWidth : 0.0,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: showFilterChild
                  ? Border(
                      left: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: isDark ? 0.30 : 0.28,
                        ),
                      ),
                    )
                  : null,
            ),
            child: showFilterChild
                ? ClipRect(
                    child: OverflowBox(
                      minWidth: kDesktopFilterPanelWidth,
                      maxWidth: kDesktopFilterPanelWidth,
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: widget.topPadding),
                        child: keyedFilterSheet,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
    }

    return Stack(
      children: [
        keyedFeed,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.isOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              opacity: widget.isOpen ? 1.0 : 0.0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Container(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.22),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          onEnd: _handleCloseEnd,
          top: widget.topPadding,
          bottom: 0,
          right: widget.isOpen ? 0.0 : -kDesktopFilterPanelWidth,
          width: kDesktopFilterPanelWidth,
          child: IgnorePointer(
            ignoring: !widget.isOpen,
            child: FrostedSurface(
              enableBlur: widget.enableFrosted && showFilterChild,
              surfaceColor: widget.enableFrosted
                  ? colorScheme.surfaceContainerLow.withValues(
                      alpha: isDark ? 0.88 : 0.92,
                    )
                  : colorScheme.surfaceContainerLow,
              border: Border(
                left: BorderSide(
                  color: colorScheme.outlineVariant.withValues(
                    alpha: isDark ? 0.36 : 0.30,
                  ),
                ),
              ),
              boxShadow: showFilterChild
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.38 : 0.14,
                        ),
                        blurRadius: 20,
                        offset: const Offset(-4, 0),
                      ),
                    ]
                  : null,
              child: showFilterChild
                  ? keyedFilterSheet
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
