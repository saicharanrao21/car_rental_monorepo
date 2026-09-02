import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../providers/admin_session_provider.dart';

final sidebarExpandedProvider = StateProvider<bool>((ref) => true);
final selectedDomainFilterProvider = StateProvider<String?>((ref) => null);

class AdminDomainGroup {
  final String domainId;
  final String domainName;
  final IconData icon;
  final List<AdminNavItem> items;

  const AdminDomainGroup({
    required this.domainId,
    required this.domainName,
    required this.icon,
    required this.items,
  });
}

class AdminNavItem {
  final String label;
  final IconData icon;
  final String route;
  final String? badgeText;
  final Color? badgeColor;

  const AdminNavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.badgeText,
    this.badgeColor,
  });
}

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  static const List<AdminDomainGroup> domainGroups = [
    AdminDomainGroup(
      domainId: 'executive',
      domainName: 'Executive',
      icon: Icons.space_dashboard_rounded,
      items: [
        AdminNavItem(label: 'Command Center', icon: Icons.space_dashboard_rounded, route: '/dashboard'),
        AdminNavItem(label: 'Revenue & Reports', icon: Icons.account_balance_wallet_outlined, route: '/revenue'),
      ],
    ),
    AdminDomainGroup(
      domainId: 'operations',
      domainName: 'Operations & Fleet',
      icon: Icons.local_shipping_outlined,
      items: [
        AdminNavItem(label: 'Location Governance', icon: Icons.share_location_outlined, route: '/locations/governance'),
        AdminNavItem(label: 'Live Operations Map', icon: Icons.map_outlined, route: '/locations'),
        AdminNavItem(label: 'Bookings Management', icon: Icons.book_online_outlined, route: '/bookings'),
        AdminNavItem(label: 'Fleet Inventory', icon: Icons.directions_car_outlined, route: '/fleet'),
        AdminNavItem(label: 'Vendor Partners', icon: Icons.storefront_outlined, route: '/vendors'),
        AdminNavItem(label: 'Supported Cities', icon: Icons.location_city_outlined, route: '/supported-cities'),
      ],
    ),
    AdminDomainGroup(
      domainId: 'customer_care',
      domainName: 'Customer Care',
      icon: Icons.support_agent_outlined,
      items: [
        AdminNavItem(label: 'Customer Accounts', icon: Icons.people_outline, route: '/customers'),
        AdminNavItem(label: 'Support Tickets', icon: Icons.support_agent_outlined, route: '/support-tickets'),
        AdminNavItem(label: 'Emergency SOS', icon: Icons.emergency_outlined, route: '/emergency-dispatch', badgeText: 'SOS', badgeColor: Colors.red),
        AdminNavItem(label: 'Disputes & Claims', icon: Icons.gavel_outlined, route: '/disputes'),
      ],
    ),
    AdminDomainGroup(
      domainId: 'finance',
      domainName: 'Finance & Settlements',
      icon: Icons.payments_outlined,
      items: [
        AdminNavItem(label: 'Commission Settings', icon: Icons.percent_outlined, route: '/commission'),
        AdminNavItem(label: 'Invoices & Billing', icon: Icons.receipt_long_outlined, route: '/invoices'),
        AdminNavItem(label: 'Protection Packages', icon: Icons.shield_outlined, route: '/protection-packages'),
      ],
    ),
    AdminDomainGroup(
      domainId: 'growth',
      domainName: 'Growth & Marketing',
      icon: Icons.trending_up_outlined,
      items: [
        AdminNavItem(label: 'Banners & Promotions', icon: Icons.view_carousel_outlined, route: '/banners'),
        AdminNavItem(label: 'Referral Campaigns', icon: Icons.card_giftcard_outlined, route: '/referrals'),
        AdminNavItem(label: 'Loyalty Program', icon: Icons.stars_outlined, route: '/loyalty'),
        AdminNavItem(label: 'Push Notifications', icon: Icons.notifications_none_outlined, route: '/notifications'),
        AdminNavItem(label: 'WhatsApp Messaging', icon: Icons.chat_outlined, route: '/whatsapp'),
      ],
    ),
    AdminDomainGroup(
      domainId: 'governance',
      domainName: 'Security & Governance',
      icon: Icons.security_outlined,
      items: [
        AdminNavItem(label: 'Audit Log', icon: Icons.history_outlined, route: '/audit-log'),
        AdminNavItem(label: 'Fraud & Risk', icon: Icons.security_outlined, route: '/fraud'),
        AdminNavItem(label: 'Platform Settings', icon: Icons.settings_outlined, route: '/settings'),
      ],
    ),
  ];

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to log out of DriveGo Admin Control Tower?'),
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
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarExpandedProvider);
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    // On tablet, sidebar is icon-only (collapsed). On mobile, it uses Drawer.
    final actualExpanded = isDesktop && isExpanded;
    final location = GoRouterState.of(context).matchedLocation;
    final breadcrumbs = _getBreadcrumbInfo(location);

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF0F172A)),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Text(
            breadcrumbs.itemLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () => _handleLogout(context, ref),
            ),
          ],
        ),
        drawer: Drawer(
          child: Container(
            color: const Color(0xFF0F172A),
            child: Column(
              children: [
                _buildSidebarBrand(true),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: domainGroups.map((group) {
                      return _buildDomainAccordion(
                        context,
                        group: group,
                        currentLocation: location,
                        isExpanded: true,
                        onNavigate: () => Navigator.of(context).pop(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // ─── Left Sidebar Navigation ───
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: actualExpanded ? 260 : 72,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A), // Premium Deep Slate Dark
              border: Border(
                right: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Brand Header
                _buildSidebarBrand(actualExpanded),

                // Domain Navigation Groups List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: domainGroups.map((group) {
                      return _buildDomainAccordion(
                        context,
                        group: group,
                        currentLocation: location,
                        isExpanded: actualExpanded,
                      );
                    }).toList(),
                  ),
                ),

                // Collapse/Expand Toggle (Desktop only)
                if (isDesktop) ...[
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  InkWell(
                    onTap: () {
                      ref.read(sidebarExpandedProvider.notifier).update((v) => !v);
                    },
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: actualExpanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            actualExpanded ? Icons.chevron_left : Icons.chevron_right,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          if (actualExpanded) ...[
                            const Gap(10),
                            const Flexible(
                              child: Text(
                                'Collapse Sidebar',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Main Content Canvas ───
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  // Top Command Center Header
                  Container(
                    height: 64,
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
                        // Breadcrumb Navigation
                        Row(
                          children: [
                            Text(
                              breadcrumbs.domainName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Gap(8),
                            Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                            const Gap(8),
                            Text(
                              breadcrumbs.itemLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),

                        // System Health & Admin Controls
                        Row(
                          children: [
                            // Operational Health Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF10B981)),
                                  Gap(6),
                                  Text(
                                    'CONTROL TOWER LIVE',
                                    style: TextStyle(
                                      color: Color(0xFF065F46),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(20),

                            // Admin Profile Avatar & Name
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  child: const Text(
                                    'A',
                                    style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
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
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(16),

                            // Logout Button
                            IconButton(
                              icon: const Icon(Icons.logout_outlined, color: Colors.red, size: 20),
                              onPressed: () => _handleLogout(context, ref),
                              tooltip: 'Logout',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Main View Child
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

  Widget _buildSidebarBrand(bool isExpanded) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: isExpanded
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_moon_rounded, color: Color(0xFF38BDF8), size: 22),
                Gap(10),
                Text(
                  'DRIVEGO CONTROL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            )
          : const Icon(Icons.shield_moon_rounded, color: Color(0xFF38BDF8), size: 24),
    );
  }

  Widget _buildDomainAccordion(
    BuildContext context, {
    required AdminDomainGroup group,
    required String currentLocation,
    required bool isExpanded,
    VoidCallback? onNavigate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              group.domainName.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          )
        else
          const Divider(color: Color(0xFF1E293B), height: 16),
        ...group.items.map((item) {
          final isSelected = _isRouteSelected(currentLocation, item.route);

          final navButton = InkWell(
            onTap: () {
              context.go(item.route);
              onNavigate?.call();
            },
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.2) : null,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? const Border(left: BorderSide(color: Color(0xFF38BDF8), width: 3))
                    : null,
              ),
              child: Row(
                mainAxisAlignment:
                    isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Gap(isExpanded ? 12 : 0),
                  Icon(
                    item.icon,
                    color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  if (isExpanded) ...[
                    const Gap(12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.badgeText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.badgeColor ?? Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const Gap(8),
                    ],
                  ],
                ],
              ),
            ),
          );

          if (!isExpanded) {
            return Tooltip(
              message: '${group.domainName}: ${item.label}',
              preferBelow: false,
              child: navButton,
            );
          }

          return navButton;
        }),
      ],
    );
  }

  bool _isRouteSelected(String currentLocation, String targetRoute) {
    if (targetRoute == '/locations') {
      return currentLocation == '/locations';
    }
    return currentLocation.startsWith(targetRoute);
  }

  ({String domainName, String itemLabel}) _getBreadcrumbInfo(String location) {
    for (final group in domainGroups) {
      for (final item in group.items) {
        if (_isRouteSelected(location, item.route)) {
          return (domainName: group.domainName, itemLabel: item.label);
        }
      }
    }
    return (domainName: 'Control Tower', itemLabel: 'Overview');
  }
}
