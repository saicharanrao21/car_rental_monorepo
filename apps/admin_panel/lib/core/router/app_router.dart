import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_session_provider.dart';
import '../widgets/admin_shell.dart';
import '../../features/auth/presentation/pages/admin_login_page.dart';
import '../../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/vendors/presentation/pages/vendor_management_page.dart';
import '../../features/customers/presentation/pages/customer_management_page.dart';
import '../../features/bookings/presentation/pages/admin_booking_management_page.dart';
import '../../features/fleet/presentation/pages/admin_fleet_overview_page.dart';
import '../../features/commission/presentation/pages/commission_settings_page.dart';
import '../../features/revenue/presentation/pages/revenue_reports_page.dart';
import '../../features/revenue/presentation/pages/admin_invoices_page.dart';
import '../../features/disputes/presentation/pages/admin_disputes_page.dart';
import '../../features/audit_log/presentation/pages/admin_audit_log_page.dart';
import '../../features/notifications/presentation/pages/push_notifications_page.dart';
import '../../features/banners/presentation/pages/banners_promotions_page.dart';
import '../../features/supported_cities/presentation/pages/supported_cities_page.dart';
import '../../features/settings/presentation/pages/platform_settings_page.dart';
import '../../features/support/presentation/pages/admin_support_tickets_page.dart';
import '../../features/emergency/presentation/pages/admin_emergency_dispatch_page.dart';
import '../../features/protection/presentation/pages/admin_protection_packages_page.dart';
import '../../features/referral/presentation/pages/admin_referral_campaigns_page.dart';
import '../../features/loyalty/presentation/pages/admin_loyalty_page.dart';
import '../../features/fraud/presentation/pages/admin_fraud_page.dart';
import '../../features/locations/presentation/pages/operational_map_page.dart';
import '../../features/whatsapp/presentation/pages/admin_whatsapp_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root_admin');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell_admin');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(adminSessionProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    navigatorKey: rootNavigatorKey,
    refreshListenable: routerNotifier,
    routes: [
      // Auth Login Route
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminLoginPage(),
      ),

      // Shell Route for Admin layout
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return AdminShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/vendors',
            builder: (context, state) => const VendorManagementPage(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomerManagementPage(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) => const AdminBookingManagementPage(),
          ),
          GoRoute(
            path: '/fleet',
            builder: (context, state) => const AdminFleetOverviewPage(),
          ),
          GoRoute(
            path: '/commission',
            builder: (context, state) => const CommissionSettingsPage(),
          ),
          GoRoute(
            path: '/revenue',
            builder: (context, state) => const RevenueReportsPage(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const AdminInvoicesPage(),
          ),
          GoRoute(
            path: '/disputes',
            builder: (context, state) => const AdminDisputesPage(),
          ),
          GoRoute(
            path: '/audit-log',
            builder: (context, state) => const AdminAuditLogPage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const PushNotificationsPage(),
          ),
          GoRoute(
            path: '/banners',
            builder: (context, state) => const BannersPromotionsPage(),
          ),
          GoRoute(
            path: '/supported-cities',
            builder: (context, state) => const SupportedCitiesPage(),
          ),
          GoRoute(
            path: '/support-tickets',
            builder: (context, state) => const AdminSupportTicketsPage(),
          ),
          GoRoute(
            path: '/emergency-dispatch',
            builder: (context, state) => const AdminEmergencyDispatchPage(),
          ),
          GoRoute(
            path: '/protection-packages',
            builder: (context, state) => const AdminProtectionPackagesPage(),
          ),
          GoRoute(
            path: '/referrals',
            builder: (context, state) => const AdminReferralCampaignsPage(),
          ),
          GoRoute(
            path: '/loyalty',
            builder: (context, state) => const AdminLoyaltyManagementPage(),
          ),
          GoRoute(
            path: '/fraud',
            builder: (context, state) => const AdminFraudPage(),
          ),
          GoRoute(
            path: '/locations',
            builder: (context, state) => const OperationalMapPage(),
          ),
          GoRoute(
            path: '/whatsapp',
            builder: (context, state) => const AdminWhatsAppPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const PlatformSettingsPage(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(adminSessionProvider);
      final isAuthenticated = session.isAuthenticated;

      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated) {
        return '/login';
      }

      // If authenticated and on login or root, redirect to dashboard
      if (isLoggingIn || state.matchedLocation == '/') {
        return '/dashboard';
      }

      return null;
    },
  );
});
