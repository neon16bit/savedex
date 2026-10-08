import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/features/library/library_view.dart';
import 'package:savedex/features/saved/saved_view.dart';
import 'package:savedex/features/settings/settings_view.dart';

class ShellTabViewModel extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final selectedShellTabProvider = NotifierProvider<ShellTabViewModel, int>(
  () => ShellTabViewModel(),
);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedShellTabProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final screens = const [SavedView(), LibraryView(), SettingsView()];

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex.clamp(0, screens.length - 1),
          onDestinationSelected: (index) {
            ref.read(selectedShellTabProvider.notifier).setTab(index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks_rounded),
              label: 'Saved',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
