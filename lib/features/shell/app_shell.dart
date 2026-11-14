import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/features/library/library_view.dart';
import 'package:savedex/features/saved/saved_view.dart';
import 'package:savedex/features/settings/settings_view.dart';
import 'package:savedex/features/shell/widgets/floating_nav_bar.dart';
import 'package:savedex/shared/widgets/widgets.dart';
export 'package:savedex/features/shell/widgets/floating_nav_bar.dart';

class ShellTabViewModel extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    if (state != index) state = index;
  }
}

final selectedShellTabProvider = NotifierProvider<ShellTabViewModel, int>(
  ShellTabViewModel.new,
);

class SavedSearchExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setExpanded(bool value) {
    if (state != value) state = value;
  }

  void toggle() => state = !state;
}

final isSavedSearchExpandedProvider =
    NotifierProvider<SavedSearchExpandedNotifier, bool>(
      SavedSearchExpandedNotifier.new,
    );

class SavedFilterExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setExpanded(bool value) {
    if (state != value) state = value;
  }

  void toggle() => state = !state;
}

final isSavedFilterExpandedProvider =
    NotifierProvider<SavedFilterExpandedNotifier, bool>(
      SavedFilterExpandedNotifier.new,
    );

class SavedSearchOpenedViaFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpened(bool value) {
    if (state != value) state = value;
  }
}

final isSavedSearchOpenedViaFilterProvider =
    NotifierProvider<SavedSearchOpenedViaFilterNotifier, bool>(
      SavedSearchOpenedViaFilterNotifier.new,
    );

class TriggerCounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final savedScrollToTopTriggerProvider =
    NotifierProvider<TriggerCounterNotifier, int>(TriggerCounterNotifier.new);

final isLibrarySearchExpandedProvider =
    NotifierProvider<SavedSearchExpandedNotifier, bool>(
      SavedSearchExpandedNotifier.new,
    );

class LibrarySubTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setSubTab(int index) {
    if (state != index) {
      state = index;
    }
  }
}

final librarySubTabProvider = NotifierProvider<LibrarySubTabNotifier, int>(
  LibrarySubTabNotifier.new,
);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Set<int> _visitedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedShellTabProvider).clamp(0, 2);
    _visitedTabs.add(selectedIndex);

    final isSavedFilterExpanded =
        selectedIndex == 0 && ref.watch(isSavedFilterExpandedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    void dismissFilter() {
      ref.read(isSavedFilterExpandedProvider.notifier).setExpanded(false);
    }

    return SnackBarTheme(
      data: theme.snackBarTheme.copyWith(
        insetPadding: kFloatingBarSnackBarMargin,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: selectedIndex,
              children: [
                const SavedView(),
                _visitedTabs.contains(1)
                    ? const LibraryView()
                    : const SizedBox.shrink(),
                _visitedTabs.contains(2)
                    ? const SettingsView()
                    : const SizedBox.shrink(),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !isSavedFilterExpanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  opacity: isSavedFilterExpanded ? 1.0 : 0.0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: dismissFilter,
                    onVerticalDragUpdate: (details) {
                      if ((details.primaryDelta ?? 0) > 6) {
                        dismissFilter();
                      }
                    },
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.40 : 0.22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              key: ValueKey('app_shell_floating_nav_bar'),
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(child: FloatingNavBar()),
            ),
          ],
        ),
      ),
    );
  }
}
