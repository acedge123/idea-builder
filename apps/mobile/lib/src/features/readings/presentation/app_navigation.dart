import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class AppNavigation extends StatelessWidget {
  const AppNavigation({this.index = 0, this.onNavigate, super.key});
  final int index;
  final ValueChanged<String>? onNavigate;
  @override
  Widget build(BuildContext context) => NavigationBar(
    backgroundColor: AppTheme.background,
    selectedIndex: index,
    onDestinationSelected: (i) =>
        (onNavigate ?? context.go)(const ['/', '/readings', '/auth'][i]),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.library_books_outlined),
        selectedIcon: Icon(Icons.library_books),
        label: 'My readings',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Account',
      ),
    ],
  );
}
