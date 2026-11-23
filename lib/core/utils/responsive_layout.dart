import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const double kDesktopBreakpoint = 840.0;
const double kWideDesktopBreakpoint = 1200.0;
const double kDesktopDockedFilterMinWidth = 960.0;

const double kDesktopSidebarExpandedWidth = 228.0;
const double kDesktopSidebarRailWidth = 74.0;
const double kDesktopFilterPanelWidth = 328.0;
const double kDesktopSnackBarMaxWidth = 460.0;

const double kFeedCardMaxWidth = 720.0;
const double kFeedCompactMaxWidth = 860.0;
const double kPostDetailMaxWidth = 820.0;
const double kLibraryMaxWidth = 900.0;
const double kSettingsMaxWidth = 800.0;
const double kGalleryMaxCrossAxisExtent = 250.0;

enum _ResponsiveAspect { isDesktop, isWideDesktop }

/// Caches desktop breakpoint flags so descendant screens only rebuild when a
/// breakpoint is crossed rather than on every pixel of a window resize.
class ResponsiveScope extends StatelessWidget {
  final Widget child;

  const ResponsiveScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return _ResponsiveModel(
      isDesktop: width >= kDesktopBreakpoint,
      isWideDesktop: width >= kWideDesktopBreakpoint,
      child: child,
    );
  }
}

class _ResponsiveModel extends InheritedModel<_ResponsiveAspect> {
  final bool isDesktop;
  final bool isWideDesktop;

  const _ResponsiveModel({
    required this.isDesktop,
    required this.isWideDesktop,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ResponsiveModel oldWidget) =>
      isDesktop != oldWidget.isDesktop ||
      isWideDesktop != oldWidget.isWideDesktop;

  @override
  bool updateShouldNotifyDependent(
    _ResponsiveModel oldWidget,
    Set<_ResponsiveAspect> dependencies,
  ) {
    if (dependencies.contains(_ResponsiveAspect.isDesktop) &&
        isDesktop != oldWidget.isDesktop) {
      return true;
    }
    if (dependencies.contains(_ResponsiveAspect.isWideDesktop) &&
        isWideDesktop != oldWidget.isWideDesktop) {
      return true;
    }
    return false;
  }
}

/// width based responsive layout
class ResponsiveLayout {
  const ResponsiveLayout._();

  static bool isDesktop(BuildContext context) {
    final model = InheritedModel.inheritFrom<_ResponsiveModel>(
      context,
      aspect: _ResponsiveAspect.isDesktop,
    );
    if (model != null) return model.isDesktop;
    return MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
  }

  static bool isWideDesktop(BuildContext context) {
    final model = InheritedModel.inheritFrom<_ResponsiveModel>(
      context,
      aspect: _ResponsiveAspect.isWideDesktop,
    );
    if (model != null) return model.isWideDesktop;
    return MediaQuery.sizeOf(context).width >= kWideDesktopBreakpoint;
  }

  static String shortcutModifierLabel() =>
      defaultTargetPlatform == TargetPlatform.macOS ? 'Cmd' : 'Ctrl';

  static bool isEditableTextFocused([FocusNode? node]) {
    final target = node ?? FocusManager.instance.primaryFocus;
    final ctx = target?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  static void unfocusEditableText() {
    final primary = FocusManager.instance.primaryFocus;
    if (isEditableTextFocused(primary)) {
      primary!.unfocus();
    }
  }

  static double feedBottomPadding(BuildContext context) =>
      isDesktop(context) ? 28.0 : 104.0;

  static double centeredHorizontalPadding(
    double availableWidth, {
    required double maxContentWidth,
    double minPadding = 16.0,
  }) {
    final remaining = availableWidth - maxContentWidth;
    if (remaining <= minPadding * 2) {
      return minPadding;
    }
    return remaining / 2;
  }
}
