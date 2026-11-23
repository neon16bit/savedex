import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:savedex/core/utils/responsive_layout.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

/// Standard backdrop blur radius used across frosted glass UI surfaces.
const double kFrostedBlurSigma = 16.0;

/// Default translucent surface opacities matching the floating dock tokens.
const double kFrostedDarkAlpha = 0.82;
const double kFrostedLightAlpha = 0.88;

/// Default subtle border opacities for frosted containers.
const double kFrostedBorderAlphaDark = 0.38;
const double kFrostedBorderAlphaLight = 0.32;

/// Watches the persisted user preference for frosted glass blur effects.
bool watchFrostedEffects(WidgetRef ref) {
  return ref.watch(
    settingsViewModelProvider.select((s) => s.enableFrostedEffects),
  );
}

/// Reads the persisted frosted glass preference imperatively from [context].
bool readFrostedEffects(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(settingsViewModelProvider.select((s) => s.enableFrostedEffects));
  } on StateError {
    return true;
  }
}

/// Reusable frosted glass surface that omits [BackdropFilter] completely
/// when [enableBlur] is `false`.
class FrostedSurface extends StatelessWidget {
  final bool enableBlur;
  final BorderRadiusGeometry borderRadius;
  final Color surfaceColor;
  final Color? borderColor;
  final BoxBorder? border;
  final double borderWidth;
  final double blurSigma;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Clip clipBehavior;
  final Widget child;

  const FrostedSurface({
    super.key,
    required this.enableBlur,
    this.borderRadius = BorderRadius.zero,
    required this.surfaceColor,
    this.borderColor,
    this.border,
    this.borderWidth = 1.0,
    this.blurSigma = kFrostedBlurSigma,
    this.boxShadow,
    this.padding,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        border ??
        (borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null);

    if (!enableBlur) {
      return Container(
        width: width,
        height: height,
        padding: padding,
        clipBehavior: borderRadius == BorderRadius.zero
            ? Clip.none
            : clipBehavior,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: borderRadius == BorderRadius.zero ? null : borderRadius,
          border: effectiveBorder,
          boxShadow: boxShadow,
        ),
        child: child,
      );
    }

    final filter = ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
    final inner = BackdropFilter(
      filter: filter,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: borderRadius == BorderRadius.zero ? null : borderRadius,
          border: effectiveBorder,
        ),
        child: child,
      ),
    );

    Widget result = borderRadius == BorderRadius.zero
        ? ClipRect(child: inner)
        : ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: clipBehavior,
            child: inner,
          );

    if (boxShadow != null && boxShadow!.isNotEmpty) {
      result = CustomPaint(
        painter: _OuterBoxShadowPainter(
          shadows: boxShadow!,
          borderRadius: borderRadius,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        ),
        child: result,
      );
    }

    if (width == null && height == null) {
      return result;
    }

    return SizedBox(width: width, height: height, child: result);
  }
}

/// Frosted flexibleSpace backdrop for scroll-under Material [AppBar]s.
class FrostedAppBarBackground extends StatelessWidget {
  final bool enableBlur;
  final bool showBottomBorder;
  final Color? surfaceColor;
  final double? darkAlpha;
  final double? lightAlpha;

  const FrostedAppBarBackground({
    super.key,
    required this.enableBlur,
    this.showBottomBorder = true,
    this.surfaceColor,
    this.darkAlpha,
    this.lightAlpha,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableBlur) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = surfaceColor ?? colorScheme.surface;
    final alpha = isDark ? (darkAlpha ?? 0.80) : (lightAlpha ?? 0.86);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: kFrostedBlurSigma,
          sigmaY: kFrostedBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: alpha),
            border: showBottomBorder
                ? Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.28 : 0.25,
                      ),
                    ),
                  )
                : null,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Opens a modal bottom sheet with a transparent Material canvas so a child
/// [FrostedSheetContainer] can render conditional frosted glass without a solid
/// sheet background bleeding through.
Future<T?> showFrostedModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool enableDrag = true,
  bool isDismissible = true,
  bool useRootNavigator = false,
  Color? barrierColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  bool? enableBlur,
}) {
  final blurEnabled = enableBlur ?? readFrostedEffects(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveBarrierColor =
      barrierColor ??
      (blurEnabled
          ? Colors.black.withValues(alpha: isDark ? 0.30 : 0.22)
          : null);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: effectiveBarrierColor,
    elevation: 0,
    shape: shape,
    clipBehavior: clipBehavior ?? Clip.none,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (ctx) {
      return ConstrainedBox(
        constraints: ResponsiveLayout.isDesktop(ctx)
            ? const BoxConstraints(maxWidth: 600)
            : const BoxConstraints(),
        child: builder(ctx),
      );
    },
  );
}

/// Rounded sheet container that applies [BackdropFilter] when frosted effects
/// are enabled and falls back to an opaque container when disabled.
class FrostedSheetContainer extends ConsumerWidget {
  final bool? enableBlur;
  final BorderRadius borderRadius;
  final Color? blurSurfaceColor;
  final Color? solidSurfaceColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const FrostedSheetContainer({
    super.key,
    this.enableBlur,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
    this.blurSurfaceColor,
    this.solidSurfaceColor,
    this.borderColor,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blurEnabled = enableBlur ?? watchFrostedEffects(ref);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final solidBg = solidSurfaceColor ?? colorScheme.surface;
    final blurBase =
        blurSurfaceColor ??
        (isDark ? colorScheme.surfaceContainer : colorScheme.surface);
    final effectiveSurface = blurEnabled
        ? (blurSurfaceColor != null
              ? blurSurfaceColor!
              : blurBase.withValues(alpha: isDark ? 0.84 : 0.90))
        : solidBg;

    final effectiveBorder = blurEnabled
        ? Border(
            top: BorderSide(
              color:
                  borderColor ??
                  colorScheme.outlineVariant.withValues(
                    alpha: isDark ? 0.36 : 0.28,
                  ),
            ),
          )
        : null;

    return FrostedSurface(
      enableBlur: blurEnabled,
      borderRadius: borderRadius,
      surfaceColor: effectiveSurface,
      border: effectiveBorder,
      padding: padding,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Shows a dialog with a lighter translucent scrim when frosted effects are
/// enabled so content behind a [FrostedAlertDialog] remains visible for the
/// backdrop blur, falling back to Material's default barrier when disabled.
Future<T?> showFrostedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool? requestFocus,
  bool? enableBlur,
}) {
  final blurEnabled = enableBlur ?? readFrostedEffects(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveBarrierColor =
      barrierColor ??
      (blurEnabled
          ? Colors.black.withValues(alpha: isDark ? 0.28 : 0.22)
          : null);

  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: effectiveBarrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    requestFocus: requestFocus,
  );
}

/// Material 3 style alert dialog with optional frosted glass backdrop.
/// Falls back to a standard [AlertDialog] when frosted effects are disabled.
class FrostedAlertDialog extends ConsumerWidget {
  final bool? enableBlur;
  final Widget? icon;
  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;
  final Widget? content;
  final EdgeInsetsGeometry? contentPadding;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsets? insetPadding;
  final Color? backgroundColor;
  final bool scrollable;
  final ShapeBorder? shape;

  const FrostedAlertDialog({
    super.key,
    this.enableBlur,
    this.icon,
    this.title,
    this.titlePadding,
    this.content,
    this.contentPadding,
    this.actions,
    this.actionsPadding,
    this.insetPadding,
    this.backgroundColor,
    this.scrollable = false,
    this.shape,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blurEnabled = enableBlur ?? watchFrostedEffects(ref);
    if (!blurEnabled) {
      return AlertDialog(
        icon: icon,
        title: title,
        titlePadding: titlePadding,
        content: content,
        contentPadding: contentPadding,
        actions: actions,
        actionsPadding: actionsPadding,
        insetPadding: insetPadding,
        backgroundColor: backgroundColor,
        scrollable: scrollable,
        shape: shape,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg =
        backgroundColor ??
        theme.dialogTheme.backgroundColor ??
        colorScheme.surfaceContainerHigh;
    final frostedFill = dialogBg.withValues(alpha: isDark ? 0.62 : 0.76);
    final effectiveShape = shape ?? theme.dialogTheme.shape;
    final borderRadius = effectiveShape is RoundedRectangleBorder
        ? effectiveShape.borderRadius
        : BorderRadius.circular(28);

    final titleStyle =
        theme.dialogTheme.titleTextStyle ??
        theme.textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface) ??
        TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        );
    final contentStyle =
        theme.dialogTheme.contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant);

    final belowIsTitle = title != null;
    final belowIsContent = !belowIsTitle && content != null;
    final effectiveIconPadding = EdgeInsets.fromLTRB(
      24,
      24,
      24,
      belowIsTitle
          ? 16
          : belowIsContent
          ? 0
          : 24,
    );
    final effectiveTitlePadding =
        titlePadding ??
        EdgeInsets.fromLTRB(
          24,
          icon == null ? 24 : 0,
          24,
          content == null ? 20 : 0,
        );
    final effectiveContentPadding =
        contentPadding ??
        EdgeInsets.fromLTRB(
          24,
          title == null && icon == null ? 24 : 16,
          24,
          24,
        );
    final effectiveActionsPadding =
        actionsPadding ??
        theme.dialogTheme.actionsPadding ??
        const EdgeInsets.fromLTRB(24, 0, 24, 24);

    final iconWidget = icon == null
        ? null
        : Padding(
            padding: effectiveIconPadding,
            child: IconTheme.merge(
              data: IconThemeData(color: colorScheme.secondary, size: 24),
              child: Center(child: icon!),
            ),
          );

    final titleWidget = title == null
        ? null
        : Padding(
            padding: effectiveTitlePadding,
            child: DefaultTextStyle(
              style: titleStyle,
              textAlign: icon != null ? TextAlign.center : TextAlign.start,
              child: title!,
            ),
          );

    final contentWidget = content == null
        ? null
        : Padding(
            padding: effectiveContentPadding,
            child: DefaultTextStyle(style: contentStyle, child: content!),
          );

    final actionsWidget = (actions == null || actions!.isEmpty)
        ? null
        : Padding(
            padding: effectiveActionsPadding,
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              overflowAlignment: OverflowBarAlignment.end,
              children: actions!,
            ),
          );

    final List<Widget> columnChildren;
    if (scrollable) {
      columnChildren = [
        if (iconWidget != null || titleWidget != null || contentWidget != null)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [?iconWidget, ?titleWidget, ?contentWidget],
              ),
            ),
          ),
        ?actionsWidget,
      ];
    } else {
      columnChildren = [
        ?iconWidget,
        ?titleWidget,
        if (contentWidget != null) Flexible(child: contentWidget),
        ?actionsWidget,
      ];
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          insetPadding ??
          theme.dialogTheme.insetPadding ??
          const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape:
          effectiveShape ?? RoundedRectangleBorder(borderRadius: borderRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        child: FrostedSurface(
          enableBlur: true,
          borderRadius: borderRadius,
          surfaceColor: frostedFill,
          borderColor: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.38 : 0.30,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          child: Material(
            type: MaterialType.transparency,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columnChildren,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [BoxShadow]s strictly outside [borderRadius] so shadows on translucent
/// [FrostedSurface] widgets never fill or darken the area behind [BackdropFilter].
class _OuterBoxShadowPainter extends CustomPainter {
  final List<BoxShadow> shadows;
  final BorderRadiusGeometry borderRadius;
  final TextDirection textDirection;

  const _OuterBoxShadowPainter({
    required this.shadows,
    required this.borderRadius,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || shadows.isEmpty) {
      return;
    }

    final BorderRadius resolvedRadius = borderRadius.resolve(textDirection);
    final Rect bounds = Offset.zero & size;
    final RRect innerRRect = resolvedRadius.toRRect(bounds);

    final double maxExtent = shadows.fold<double>(0.0, (prev, shadow) {
      if (shadow.blurStyle == BlurStyle.inner) {
        return prev;
      }
      final double extent =
          shadow.spreadRadius.abs() +
          shadow.blurRadius * 3.0 +
          shadow.offset.distance;
      return extent > prev ? extent : prev;
    });

    final Rect outerClipRect = bounds.inflate(maxExtent + 8.0);
    final Path clipPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outerClipRect)
      ..addRRect(innerRRect);

    canvas.save();
    canvas.clipPath(clipPath);

    for (final BoxShadow shadow in shadows) {
      if (shadow.blurStyle == BlurStyle.inner) {
        continue;
      }
      final Rect shadowRect = bounds
          .shift(shadow.offset)
          .inflate(shadow.spreadRadius);
      if (shadowRect.width <= 0 || shadowRect.height <= 0) {
        continue;
      }
      final RRect shadowRRect = resolvedRadius == BorderRadius.zero
          ? RRect.fromRectAndRadius(shadowRect, Radius.zero)
          : resolvedRadius.toRRect(shadowRect);
      canvas.drawRRect(shadowRRect, shadow.toPaint());
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OuterBoxShadowPainter oldDelegate) {
    return !listEquals(oldDelegate.shadows, shadows) ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.textDirection != textDirection;
  }
}

const Duration _kFrostedMenuDuration = Duration(milliseconds: 300);
const double _kFrostedMenuCloseIntervalEnd = 2.0 / 3.0;
const double _kFrostedMenuMinWidth = 2.0 * 56.0;
const double _kFrostedMenuMaxWidth = 5.0 * 56.0;
const double _kFrostedMenuWidthStep = 56.0;
const double _kFrostedMenuScreenPadding = 8.0;
const double _kFrostedMenuVerticalPadding = 8.0;

/// Displays a popup menu anchored at [position] that renders a [FrostedSurface]
/// when frosted effects are enabled and falls back to a standard Material 3
/// popup menu surface when disabled.
Future<T?> showFrostedMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  RelativeRect Function(BuildContext context, RelativeRect position)?
  positionBuilder,
  required List<PopupMenuEntry<T>> items,
  T? initialValue,
  double? elevation,
  Color? shadowColor,
  Color? surfaceTintColor,
  String? semanticLabel,
  ShapeBorder? shape,
  EdgeInsetsGeometry? menuPadding,
  Color? color,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  Clip clipBehavior = Clip.none,
  RouteSettings? routeSettings,
  AnimationStyle? popUpAnimationStyle,
  bool? requestFocus,
  bool? enableBlur,
}) {
  assert(items.isNotEmpty);
  assert(debugCheckHasMaterialLocalizations(context));

  final NavigatorState navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  );
  final CapturedThemes capturedThemes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );

  String? label = semanticLabel;
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      break;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      label ??= MaterialLocalizations.of(context).popupMenuLabel;
  }

  return navigator.push<T>(
    _FrostedPopupMenuRoute<T>(
      position: position,
      positionBuilder: positionBuilder,
      items: items,
      initialValue: initialValue,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      semanticLabel: label,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      shape: shape,
      menuPadding: menuPadding,
      color: color,
      capturedThemes: capturedThemes,
      constraints: constraints,
      clipBehavior: clipBehavior,
      settings: routeSettings,
      popUpAnimationStyle: popUpAnimationStyle,
      requestFocus: requestFocus,
      enableBlur: enableBlur,
    ),
  );
}

class _MenuItem extends SingleChildRenderObjectWidget {
  const _MenuItem({super.key, required this.onLayout, required super.child});

  final ValueChanged<Size> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMenuItem(onLayout);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMenuItem renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderMenuItem extends RenderProxyBox {
  _RenderMenuItem(this.onLayout);

  ValueChanged<Size> onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(size);
  }
}

class _FrostedPopupMenuRoute<T> extends PopupRoute<T> {
  _FrostedPopupMenuRoute({
    required this.position,
    this.positionBuilder,
    required this.items,
    this.initialValue,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    required this.barrierLabel,
    this.semanticLabel,
    this.shape,
    this.menuPadding,
    this.color,
    required this.capturedThemes,
    this.constraints,
    required this.clipBehavior,
    super.settings,
    this.popUpAnimationStyle,
    super.requestFocus,
    this.enableBlur,
  }) : itemSizes = List<Size?>.filled(items.length, null),
       itemKeys = List<GlobalKey>.generate(items.length, (_) => GlobalKey()),
       super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final RelativeRect position;
  final RelativeRect Function(BuildContext context, RelativeRect position)?
  positionBuilder;
  final List<PopupMenuEntry<T>> items;
  final List<Size?> itemSizes;
  final List<GlobalKey> itemKeys;
  final T? initialValue;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final String? semanticLabel;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? menuPadding;
  final Color? color;
  final CapturedThemes capturedThemes;
  final BoxConstraints? constraints;
  final Clip clipBehavior;
  final AnimationStyle? popUpAnimationStyle;
  final bool? enableBlur;
  CurvedAnimation? _animation;

  @override
  final String barrierLabel;

  @override
  Duration get transitionDuration {
    if (popUpAnimationStyle == AnimationStyle.noAnimation) {
      return Duration.zero;
    }
    return popUpAnimationStyle?.duration ?? _kFrostedMenuDuration;
  }

  @override
  Duration get reverseTransitionDuration {
    if (popUpAnimationStyle == AnimationStyle.noAnimation) {
      return Duration.zero;
    }
    return popUpAnimationStyle?.reverseDuration ?? _kFrostedMenuDuration;
  }

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }

  @override
  Animation<double> createAnimation() {
    if (popUpAnimationStyle == AnimationStyle.noAnimation) {
      return kAlwaysCompleteAnimation;
    }
    return _animation ??= CurvedAnimation(
      parent: super.createAnimation(),
      curve: popUpAnimationStyle?.curve ?? Curves.linear,
      reverseCurve:
          popUpAnimationStyle?.reverseCurve ??
          const Interval(0.0, _kFrostedMenuCloseIntervalEnd),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final TextDirection textDirection = Directionality.of(context);
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final EdgeInsets resolvedMenuPadding =
        (menuPadding ??
                popupMenuTheme.menuPadding ??
                const EdgeInsets.symmetric(
                  vertical: _kFrostedMenuVerticalPadding,
                ))
            .resolve(textDirection);
    final RelativeRect resolvedPosition =
        positionBuilder?.call(context, position) ?? position;

    final Widget menu = _FrostedPopupMenu<T>(
      route: this,
      position: resolvedPosition,
      semanticLabel: semanticLabel,
      constraints: constraints,
    );

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: CustomSingleChildLayout(
        delegate: _FrostedPopupMenuRouteLayout(
          position: resolvedPosition,
          itemSizes: itemSizes,
          items: items,
          initialValue: initialValue,
          topPadding: resolvedMenuPadding.top,
          textDirection: textDirection,
          padding: mediaQuery.padding,
          avoidBounds: DisplayFeatureSubScreen.avoidBounds(mediaQuery).toSet(),
        ),
        child: capturedThemes.wrap(menu),
      ),
    );
  }
}

class _FrostedPopupMenuRouteLayout<T> extends SingleChildLayoutDelegate {
  _FrostedPopupMenuRouteLayout({
    required this.position,
    required this.itemSizes,
    required this.items,
    required this.initialValue,
    required this.topPadding,
    required this.textDirection,
    required this.padding,
    required this.avoidBounds,
  });

  final RelativeRect position;
  final List<Size?> itemSizes;
  final List<PopupMenuEntry<T>> items;
  final T? initialValue;
  final double topPadding;
  final TextDirection textDirection;
  final EdgeInsets padding;
  final Set<Rect> avoidBounds;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      constraints
          .deflate(const EdgeInsets.all(_kFrostedMenuScreenPadding) + padding)
          .biggest,
    );
  }

  double? _computeSelectedItemOffset() {
    if (initialValue == null) {
      return null;
    }
    int? selectedIndex;
    for (int i = 0; i < items.length; i++) {
      if (items[i].represents(initialValue)) {
        selectedIndex = i;
        break;
      }
    }
    if (selectedIndex == null) {
      return null;
    }
    double offset = topPadding;
    for (int i = 0; i <= selectedIndex; i++) {
      final Size? itemSize = itemSizes[i];
      if (itemSize == null) {
        return null;
      }
      offset += i == selectedIndex ? itemSize.height / 2.0 : itemSize.height;
    }
    return offset;
  }

  Rect _findClosestScreen(Offset point, Size size) {
    final Iterable<Rect> screens = DisplayFeatureSubScreen.subScreensInBounds(
      Offset.zero & size,
      avoidBounds,
    );
    Rect closest = Offset.zero & size;
    double minDistance = double.infinity;
    for (final Rect screen in screens) {
      final double dx = point.dx < screen.left
          ? screen.left - point.dx
          : (point.dx > screen.right ? point.dx - screen.right : 0.0);
      final double dy = point.dy < screen.top
          ? screen.top - point.dy
          : (point.dy > screen.bottom ? point.dy - screen.bottom : 0.0);
      final double distance = dx * dx + dy * dy;
      if (distance < minDistance) {
        closest = screen;
        minDistance = distance;
      }
    }
    return closest;
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double? selectedItemOffset = _computeSelectedItemOffset();
    double y = position.top;
    if (selectedItemOffset != null) {
      y =
          position.top +
          (size.height - position.top - position.bottom) / 2.0 -
          selectedItemOffset;
    }

    double x;
    if (position.left > position.right) {
      x = size.width - position.right - childSize.width;
    } else if (position.left < position.right) {
      x = position.left;
    } else {
      x = switch (textDirection) {
        TextDirection.rtl => size.width - position.right - childSize.width,
        TextDirection.ltr => position.left,
      };
    }

    final Offset wantedPosition = Offset(x, y);
    final Rect screen = _findClosestScreen(wantedPosition, size);

    final double minX = screen.left + padding.left + _kFrostedMenuScreenPadding;
    final double maxX = math.max(
      minX,
      screen.right -
          padding.right -
          _kFrostedMenuScreenPadding -
          childSize.width,
    );
    final double minY = screen.top + padding.top + _kFrostedMenuScreenPadding;
    final double maxY = math.max(
      minY,
      screen.bottom -
          padding.bottom -
          _kFrostedMenuScreenPadding -
          childSize.height,
    );

    x = x.clamp(minX, maxX);
    y = y.clamp(minY, maxY);

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _FrostedPopupMenuRouteLayout<T> oldDelegate) {
    return position != oldDelegate.position ||
        !listEquals(itemSizes, oldDelegate.itemSizes) ||
        initialValue != oldDelegate.initialValue ||
        topPadding != oldDelegate.topPadding ||
        textDirection != oldDelegate.textDirection ||
        padding != oldDelegate.padding ||
        !setEquals(avoidBounds, oldDelegate.avoidBounds);
  }
}

class _FrostedPopupMenu<T> extends ConsumerStatefulWidget {
  const _FrostedPopupMenu({
    required this.route,
    required this.position,
    required this.semanticLabel,
    this.constraints,
  });

  final _FrostedPopupMenuRoute<T> route;
  final RelativeRect position;
  final String? semanticLabel;
  final BoxConstraints? constraints;

  @override
  ConsumerState<_FrostedPopupMenu<T>> createState() =>
      _FrostedPopupMenuState<T>();
}

class _FrostedPopupMenuState<T> extends ConsumerState<_FrostedPopupMenu<T>> {
  List<CurvedAnimation> _opacities = const <CurvedAnimation>[];

  @override
  void initState() {
    super.initState();
    _setOpacities();
    final T? initialValue = widget.route.initialValue;
    if (initialValue != null) {
      int? selectedIndex;
      for (int i = 0; i < widget.route.items.length; i++) {
        if (widget.route.items[i].represents(initialValue)) {
          selectedIndex = i;
          break;
        }
      }
      if (selectedIndex != null) {
        final GlobalKey targetKey = widget.route.itemKeys[selectedIndex];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final BuildContext? itemContext = targetKey.currentContext;
          if (itemContext != null && itemContext.mounted) {
            Scrollable.ensureVisible(itemContext, alignment: 0.5);
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant _FrostedPopupMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.items.length != widget.route.items.length ||
        oldWidget.route.animation != widget.route.animation) {
      _setOpacities();
    }
  }

  void _setOpacities() {
    for (final CurvedAnimation opacity in _opacities) {
      opacity.dispose();
    }
    final List<CurvedAnimation> newOpacities = <CurvedAnimation>[];
    final double unit = 1.0 / (widget.route.items.length + 1.5);
    for (int i = 0; i < widget.route.items.length; i++) {
      final double start = (i + 1) * unit;
      final double end = math.min(start + 1.5 * unit, 1.0);
      newOpacities.add(
        CurvedAnimation(
          parent: widget.route.animation!,
          curve: Interval(start, end),
        ),
      );
    }
    _opacities = newOpacities;
  }

  @override
  void dispose() {
    for (final CurvedAnimation opacity in _opacities) {
      opacity.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _FrostedPopupMenuRoute<T> route = widget.route;
    final bool blurEnabled = route.enableBlur ?? watchFrostedEffects(ref);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final double unit = 1.0 / (route.items.length + 1.5);
    final List<Widget> children = <Widget>[
      for (int i = 0; i < route.items.length; i++)
        _MenuItem(
          key: route.itemKeys[i],
          onLayout: (Size size) {
            route.itemSizes[i] = size;
          },
          child: FadeTransition(
            opacity: _opacities[i],
            child:
                route.initialValue != null &&
                    route.items[i].represents(route.initialValue as T)
                ? ColoredBox(color: theme.highlightColor, child: route.items[i])
                : route.items[i],
          ),
        ),
    ];

    final CurveTween opacity = CurveTween(
      curve: const Interval(0.0, 1.0 / 3.0),
    );
    final CurveTween width = CurveTween(curve: Interval(0.0, unit));
    final CurveTween height = CurveTween(
      curve: Interval(0.0, math.min(unit * route.items.length, 1.0)),
    );

    final EdgeInsetsGeometry effectiveMenuPadding =
        route.menuPadding ??
        popupMenuTheme.menuPadding ??
        const EdgeInsets.symmetric(vertical: _kFrostedMenuVerticalPadding);

    final Widget menuContents = ConstrainedBox(
      constraints:
          widget.constraints ??
          const BoxConstraints(
            minWidth: _kFrostedMenuMinWidth,
            maxWidth: _kFrostedMenuMaxWidth,
          ),
      child: IntrinsicWidth(
        stepWidth: _kFrostedMenuWidthStep,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          role: SemanticsRole.menu,
          label: widget.semanticLabel,
          child: SingleChildScrollView(
            primary: false,
            padding: effectiveMenuPadding,
            child: ListBody(children: children),
          ),
        ),
      ),
    );

    final AlignmentGeometry revealAlignment =
        widget.position.left > widget.position.right
        ? AlignmentDirectional.topEnd
        : AlignmentDirectional.topStart;

    final ShapeBorder? effectiveShape = route.shape ?? popupMenuTheme.shape;
    final BorderRadiusGeometry borderRadius =
        effectiveShape is RoundedRectangleBorder
        ? effectiveShape.borderRadius
        : BorderRadius.circular(16);

    return FadeTransition(
      opacity: opacity.animate(route.animation!),
      child: AnimatedBuilder(
        animation: route.animation!,
        builder: (BuildContext context, Widget? child) {
          final double wFactor = math.max(
            0.0,
            math.min(1.0, width.evaluate(route.animation!)),
          );
          final double hFactor = math.max(
            0.0,
            math.min(1.0, height.evaluate(route.animation!)),
          );
          final Widget alignedChild = Align(
            alignment: revealAlignment,
            widthFactor: wFactor,
            heightFactor: hFactor,
            child: child,
          );

          if (!blurEnabled) {
            return Material(
              shape:
                  effectiveShape ??
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                  ),
              color:
                  route.color ??
                  popupMenuTheme.color ??
                  colorScheme.surfaceContainer,
              elevation: route.elevation ?? popupMenuTheme.elevation ?? 3.0,
              shadowColor: route.shadowColor ?? popupMenuTheme.shadowColor,
              surfaceTintColor:
                  route.surfaceTintColor ??
                  popupMenuTheme.surfaceTintColor ??
                  Colors.transparent,
              clipBehavior: route.clipBehavior,
              type: MaterialType.card,
              child: route.clipBehavior == Clip.none
                  ? ClipRect(child: alignedChild)
                  : alignedChild,
            );
          }

          final Color baseColor =
              route.color ??
              popupMenuTheme.color ??
              (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainer);

          return FrostedSurface(
            enableBlur: true,
            borderRadius: borderRadius,
            surfaceColor: baseColor.withValues(alpha: isDark ? 0.68 : 0.76),
            borderColor: colorScheme.outlineVariant.withValues(
              alpha: isDark
                  ? kFrostedBorderAlphaDark
                  : kFrostedBorderAlphaLight,
            ),
            clipBehavior: route.clipBehavior == Clip.none
                ? Clip.antiAlias
                : route.clipBehavior,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            child: Material(
              type: MaterialType.transparency,
              child: alignedChild,
            ),
          );
        },
        child: menuContents,
      ),
    );
  }
}

/// Drop-in replacement for [PopupMenuButton] whose popup menu uses
/// [showFrostedMenu] so frosted glass follows the app setting.
class FrostedPopupMenuButton<T> extends StatefulWidget {
  const FrostedPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.initialValue,
    this.onOpened,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.padding = const EdgeInsets.all(8.0),
    this.menuPadding,
    this.child,
    this.borderRadius,
    this.splashRadius,
    this.icon,
    this.iconSize,
    this.offset = Offset.zero,
    this.enabled = true,
    this.shape,
    this.color,
    this.iconColor,
    this.enableFeedback,
    this.constraints,
    this.position,
    this.clipBehavior = Clip.none,
    this.useRootNavigator = false,
    this.popUpAnimationStyle,
    this.routeSettings,
    this.style,
    this.requestFocus,
    this.enableBlur,
  }) : assert(
         !(child != null && icon != null),
         'You can only pass [child] or [icon], not both.',
       );

  final PopupMenuItemBuilder<T> itemBuilder;
  final T? initialValue;
  final VoidCallback? onOpened;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? menuPadding;
  final Widget? child;
  final BorderRadius? borderRadius;
  final double? splashRadius;
  final Widget? icon;
  final Offset offset;
  final bool enabled;
  final ShapeBorder? shape;
  final Color? color;
  final Color? iconColor;
  final bool? enableFeedback;
  final double? iconSize;
  final BoxConstraints? constraints;
  final PopupMenuPosition? position;
  final Clip clipBehavior;
  final bool useRootNavigator;
  final AnimationStyle? popUpAnimationStyle;
  final RouteSettings? routeSettings;
  final ButtonStyle? style;
  final bool? requestFocus;
  final bool? enableBlur;

  @override
  FrostedPopupMenuButtonState<T> createState() =>
      FrostedPopupMenuButtonState<T>();
}

/// State for [FrostedPopupMenuButton], exposing [showButtonMenu] so callers
/// with a [GlobalKey] can open the menu programmatically.
class FrostedPopupMenuButtonState<T> extends State<FrostedPopupMenuButton<T>> {
  bool _isMenuExpanded = false;

  RelativeRect _computeMenuPosition({
    required RenderBox button,
    required RenderBox overlay,
    required PopupMenuPosition popupMenuPosition,
  }) {
    late Offset offset;
    switch (popupMenuPosition) {
      case PopupMenuPosition.over:
        offset = widget.offset;
      case PopupMenuPosition.under:
        offset = Offset(0.0, button.size.height) + widget.offset;
        if (widget.child == null) {
          offset -= Offset(0.0, widget.padding.vertical / 2);
        }
    }
    return RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(offset, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + offset,
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
  }

  /// Opens the popup menu using [showFrostedMenu].
  void showButtonMenu() {
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(
              context,
              rootNavigator: widget.useRootNavigator,
            ).overlay!.context.findRenderObject()!
            as RenderBox;
    final PopupMenuPosition popupMenuPosition =
        widget.position ?? popupMenuTheme.position ?? PopupMenuPosition.over;
    final RelativeRect initialPosition = _computeMenuPosition(
      button: button,
      overlay: overlay,
      popupMenuPosition: popupMenuPosition,
    );
    final List<PopupMenuEntry<T>> items = widget.itemBuilder(context);
    if (items.isNotEmpty) {
      setState(() {
        _isMenuExpanded = true;
      });
      showFrostedMenu<T?>(
            context: context,
            elevation: widget.elevation ?? popupMenuTheme.elevation,
            shadowColor: widget.shadowColor ?? popupMenuTheme.shadowColor,
            surfaceTintColor:
                widget.surfaceTintColor ?? popupMenuTheme.surfaceTintColor,
            items: items,
            initialValue: widget.initialValue,
            position: initialPosition,
            positionBuilder: (BuildContext _, RelativeRect fallback) {
              if (!mounted || !button.attached || !overlay.attached) {
                return fallback;
              }
              return _computeMenuPosition(
                button: button,
                overlay: overlay,
                popupMenuPosition: popupMenuPosition,
              );
            },
            shape: widget.shape ?? popupMenuTheme.shape,
            menuPadding: widget.menuPadding ?? popupMenuTheme.menuPadding,
            color: widget.color ?? popupMenuTheme.color,
            constraints: widget.constraints,
            clipBehavior: widget.clipBehavior,
            useRootNavigator: widget.useRootNavigator,
            popUpAnimationStyle: widget.popUpAnimationStyle,
            routeSettings: widget.routeSettings,
            requestFocus: widget.requestFocus,
            enableBlur: widget.enableBlur,
          )
          .then<void>((T? newValue) {
            if (!mounted) {
              return;
            }
            if (newValue == null) {
              widget.onCanceled?.call();
              return;
            }
            widget.onSelected?.call(newValue);
          })
          .whenComplete(() {
            if (mounted) {
              setState(() {
                _isMenuExpanded = false;
              });
            }
          });
      widget.onOpened?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PopupMenuThemeData popupMenuTheme = PopupMenuTheme.of(context);
    final bool enableFeedback =
        widget.enableFeedback ?? popupMenuTheme.enableFeedback ?? true;

    assert(debugCheckHasMaterialLocalizations(context));

    final Widget trigger;
    if (widget.child != null) {
      trigger = Tooltip(
        message:
            widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        child: InkWell(
          onTap: widget.enabled ? showButtonMenu : null,
          canRequestFocus: widget.enabled,
          radius: widget.splashRadius,
          borderRadius: widget.borderRadius,
          enableFeedback: enableFeedback,
          child: widget.child,
        ),
      );
    } else {
      trigger = IconButton(
        icon: widget.icon ?? Icon(Icons.adaptive.more),
        padding: widget.padding,
        splashRadius: widget.splashRadius,
        iconSize: widget.iconSize ?? popupMenuTheme.iconSize,
        color: widget.iconColor ?? popupMenuTheme.iconColor,
        style: widget.style,
        tooltip:
            widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        onPressed: widget.enabled ? showButtonMenu : null,
        enableFeedback: enableFeedback,
      );
    }

    return Semantics(expanded: _isMenuExpanded, child: trigger);
  }
}
