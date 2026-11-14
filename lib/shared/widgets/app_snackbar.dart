import 'package:material_ui/material_ui.dart';

/// Bottom inset margin that positions snackbars clearly above floating dock bars.
const EdgeInsets kFloatingBarSnackBarMargin = EdgeInsets.fromLTRB(
  16,
  6,
  16,
  84,
);

/// Builds a theme-consistent floating [SnackBar] with optional error styling.
SnackBar buildAppSnackBar({
  required String message,
  required ColorScheme colorScheme,
  required bool isDark,
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  return SnackBar(
    content: Text(
      message,
      style: isError
          ? TextStyle(
              color: colorScheme.onErrorContainer,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            )
          : null,
    ),
    backgroundColor: isError ? colorScheme.errorContainer : null,
    shape: isError
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.error.withValues(alpha: isDark ? 0.45 : 0.35),
            ),
          )
        : null,
    behavior: SnackBarBehavior.floating,
    duration: duration,
    action: action,
    persist: false,
  );
}

/// Clears any queued snackbars and displays a themed [SnackBar] for [context].
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  if (!context.mounted) return null;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  final theme = Theme.of(context);
  return showAppSnackBarOnMessenger(
    messenger,
    message: message,
    colorScheme: theme.colorScheme,
    isDark: theme.brightness == Brightness.dark,
    isError: isError,
    duration: duration,
    action: action,
  );
}

/// Clears any queued snackbars and displays a themed [SnackBar] on [messenger].
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
showAppSnackBarOnMessenger(
  ScaffoldMessengerState messenger, {
  required String message,
  ColorScheme? colorScheme,
  bool? isDark,
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  if (!messenger.mounted) return null;
  final theme = (colorScheme == null || isDark == null)
      ? Theme.of(messenger.context)
      : null;
  final resolvedColorScheme = colorScheme ?? theme!.colorScheme;
  final resolvedIsDark = isDark ?? (theme!.brightness == Brightness.dark);
  messenger.clearSnackBars();
  return messenger.showSnackBar(
    buildAppSnackBar(
      message: message,
      colorScheme: resolvedColorScheme,
      isDark: resolvedIsDark,
      isError: isError,
      duration: duration,
      action: action,
    ),
  );
}
