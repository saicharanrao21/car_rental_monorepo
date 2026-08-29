import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

/// DriveGo Design System (DDS) — Modern Customer App Shell
/// Provides adaptive navigation (Bottom Navigation Bar on mobile, NavigationRail on tablet/desktop)
/// with strict DDS tokens, safe-area ergonomics, and accessible touch targets.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final isTabletOrDesktop = DDSBreakpoints.isTablet(context) || DDSBreakpoints.isDesktop(context);

    if (isTabletOrDesktop) {
      return Scaffold(
        backgroundColor: DDSColors.bgCanvas,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _onTabSelected(context, index),
              backgroundColor: DDSColors.surfaceCard,
              indicatorColor: DDSColors.primaryBlue.withValues(alpha: 0.12),
              selectedIconTheme: const IconThemeData(color: DDSColors.primaryBlue, size: 24),
              unselectedIconTheme: const IconThemeData(color: DDSColors.textSecondary, size: 24),
              selectedLabelTextStyle: DDSTypography.labelSmall.copyWith(
                color: DDSColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: DDSTypography.labelSmall.copyWith(
                color: DDSColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              labelType: NavigationRailLabelType.all,
              destinations: _buildRailDestinations(),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: DDSColors.borderLight),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: DDSColors.bgCanvas,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: DDSColors.surfaceCard,
          border: Border(
            top: BorderSide(color: DDSColors.borderLight, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000), // 4% subtle shadow
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 64,
              backgroundColor: DDSColors.surfaceCard,
              surfaceTintColor: Colors.transparent,
              indicatorColor: DDSColors.primaryBlue.withValues(alpha: 0.12),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: DDSRadius.pillBorderRadius,
              ),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return DDSTypography.labelSmall.copyWith(
                    color: DDSColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  );
                }
                return DDSTypography.labelSmall.copyWith(
                  color: DDSColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: DDSColors.primaryBlue, size: 24);
                }
                return const IconThemeData(color: DDSColors.textSecondary, size: 24);
              }),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _onTabSelected(context, index),
              animationDuration: DDSMotion.fast,
              destinations: _buildBarDestinations(),
            ),
          ),
        ),
      ),
    );
  }

  List<NavigationDestination> _buildBarDestinations() {
    return const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
        tooltip: 'Home marketplace',
      ),
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore_rounded),
        label: 'Search',
        tooltip: 'Explore vehicles',
      ),
      NavigationDestination(
        icon: Icon(Icons.directions_car_outlined),
        selectedIcon: Icon(Icons.directions_car_rounded),
        label: 'Bookings',
        tooltip: 'My trips',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
        tooltip: 'Account & Settings',
      ),
    ];
  }

  List<NavigationRailDestination> _buildRailDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: Text('Home'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore_rounded),
        label: Text('Search'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.directions_car_outlined),
        selectedIcon: Icon(Icons.directions_car_rounded),
        label: Text('Bookings'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: Text('Profile'),
      ),
    ];
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
