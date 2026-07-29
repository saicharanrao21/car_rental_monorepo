import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => _onTabSelected(context, index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: cs.surface,
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, color: cs.onSurfaceVariant),
              activeIcon: Icon(Icons.home, color: cs.primary),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined, color: cs.onSurfaceVariant),
              activeIcon: Icon(Icons.search, color: cs.primary),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined, color: cs.onSurfaceVariant),
              activeIcon: Icon(Icons.directions_car, color: cs.primary),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, color: cs.onSurfaceVariant),
              activeIcon: Icon(Icons.person, color: cs.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _onTabSelected(BuildContext context, int index) {
    // Search tab jumps to a fresh /search page with no filters
    if (index == 1) {
      context.go('/search?city=&tripType=&start=&end=&pickup=&drop=&category=');
      navigationShell.goBranch(1, initialLocation: true);
    } else {
      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
    }
  }
}
