import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/admin_session_provider.dart';

final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  static const sidebarItems = [
    (label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
    (label: 'Vendors', icon: Icons.storefront_outlined, route: '/vendors'),
    (label: 'Customers', icon: Icons.people_outline, route: '/customers'),
    (label: 'Bookings', icon: Icons.book_online_outlined, route: '/bookings'),
    (label: 'Fleet', icon: Icons.directions_car_outlined, route: '/fleet'),
    (label: 'Commission', icon: Icons.percent_outlined, route: '/commission'),
    (label: 'Revenue', icon: Icons.account_balance_wallet_outlined, route: '/revenue'),
    (label: 'Disputes', icon: Icons.gavel_outlined, route: '/disputes'),
    (label: 'Audit Log', icon: Icons.history_outlined, route: '/audit-log'),
    (label: 'Notifications', icon: Icons.notifications_none_outlined, route: '/notifications'),
    (label: 'Banners', icon: Icons.view_carousel_outlined, route: '/banners'),
    (label: 'Supported Cities', icon: Icons.location_city_outlined, route: '/supported-cities'),
    (label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  ];

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of the admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminSessionProvider.notifier).logout();
              context.go('/login');
            },
            child: Text('Logout', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarExpandedProvider);
    final isTablet = Responsive.isTablet(context);
    // On tablet, sidebar is always collapsed (icon-only)
    final actualExpanded = isExpanded && !isTablet;

    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          // ─── Left Sidebar ───
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: actualExpanded ? 240 : 72,
            color: const Color(0xFF1E293B), // Premium Dark Sidebar background
            child: Column(
              children: [
                // Brand Header
                Container(
                  height: 70,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                  ),
                  child: actualExpanded
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.admin_panel_settings, color: Colors.blue, size: 24),
                            Gap(10),
                            Text(
                              'RENTAL ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                      : const Icon(Icons.admin_panel_settings, color: Colors.blue, size: 28),
                ),

                // Nav Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: sidebarItems.length,
                    itemBuilder: (context, index) {
                      final item = sidebarItems[index];
                      final isSelected = location.startsWith(item.route);

                      return InkWell(
                        onTap: () => context.go(item.route),
                        child: Container(
                          height: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.withValues(alpha: 0.15) : null,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? const Border(left: BorderSide(color: Colors.blue, width: 3))
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: actualExpanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Gap(actualExpanded ? 14 : 0),
                              Icon(
                                item.icon,
                                color: isSelected ? Colors.blue : Colors.grey[400],
                                size: 20,
                              ),
                              if (actualExpanded) ...[
                                const Gap(14),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[300],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Collapse Toggle Button (hide on tablet as it's locked to collapsed anyway)
                if (!isTablet) ...[
                  IconButton(
                    icon: Icon(
                      actualExpanded ? Icons.chevron_left : Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                    onPressed: () {
                      ref.read(sidebarExpandedProvider.notifier).update((state) => !state);
                    },
                  ),
                  const Gap(8),
                ],
              ],
            ),
          ),

          // ─── Right Content Area ───
          Expanded(
            child: Container(
              color: Colors.grey[50], // Soft grey background for material design
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Page Title Header
                        Text(
                          _getPageTitle(location),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        // Admin details & controls
                        Row(
                          children: [
                            const Icon(Icons.notifications_none, color: Colors.grey),
                            const Gap(20),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Text(
                                    'A',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Gap(10),
                                Text(
                                  ref.read(adminSessionProvider).displayName.isNotEmpty
                                      ? ref.read(adminSessionProvider).displayName
                                      : 'Admin User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(20),
                            IconButton(
                              icon: const Icon(Icons.logout_outlined, color: Colors.red),
                              onPressed: () => _handleLogout(context, ref),
                              tooltip: 'Logout',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Main Content child
                  Expanded(
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle(String location) {
    for (final item in sidebarItems) {
      if (location.startsWith(item.route)) {
        return item.label;
      }
    }
    return 'Admin Control Panel';
  }
}
