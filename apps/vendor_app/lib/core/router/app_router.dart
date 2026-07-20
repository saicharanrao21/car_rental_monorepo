import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vendor_session_provider.dart';

import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/phone_entry_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/registration/presentation/pages/registration_stepper_page.dart';
import '../../features/registration/presentation/pages/pending_approval_page.dart';

import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/fleet/presentation/pages/fleet_list_page.dart';
import '../../features/fleet/presentation/pages/fleet_car_detail_page.dart';
import '../../features/fleet/presentation/pages/add_edit_car_page.dart';
import '../../features/bookings/presentation/pages/vendor_bookings_page.dart';
import '../../features/bookings/presentation/pages/vendor_booking_detail_page.dart';
import '../../features/earnings/presentation/pages/earnings_page.dart';
import '../../features/profile/presentation/pages/vendor_profile_page.dart';
import '../widgets/vendor_app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root_vendor');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(vendorSessionProvider, (_, __) {
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
    initialLocation: '/splash',
    navigatorKey: rootNavigatorKey,
    refreshListenable: routerNotifier,
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/auth/phone',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PhoneEntryPage(),
      ),
      GoRoute(
        path: '/auth/otp',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpVerificationPage(phone: phone);
        },
      ),
      GoRoute(
        path: '/registration',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RegistrationStepperPage(),
      ),
      GoRoute(
        path: '/registration/pending',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PendingApprovalPage(),
      ),

      // Stateful Shell Route for Vendor App Shell
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state, navigationShell) {
          return VendorAppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/fleet',
                builder: (context, state) => const FleetListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const VendorBookingsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/earnings',
                builder: (context, state) => const EarningsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const VendorProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // Pushed fullscreen routes
      GoRoute(
        path: '/fleet/add',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddEditCarPage(),
      ),
      GoRoute(
        path: '/fleet/:carId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final carId = state.pathParameters['carId'] ?? '';
          return FleetCarDetailPage(carId: carId);
        },
      ),
      GoRoute(
        path: '/fleet/edit/:carId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final carId = state.pathParameters['carId'] ?? '';
          return AddEditCarPage(carId: carId);
        },
      ),
      GoRoute(
        path: '/bookings/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return VendorBookingDetailPage(bookingId: id);
        },
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(vendorSessionProvider);
      final isAuthenticated = session.isAuthenticated;
      final status = ref.read(vendorApprovalStatusProvider);

      final isPublicRoute = state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/auth/phone' ||
          state.matchedLocation == '/auth/otp' ||
          state.matchedLocation == '/registration';

      if (isAuthenticated) {
        if (status == VendorApprovalStatus.pending) {
          return '/registration/pending';
        } else if (status == VendorApprovalStatus.verified) {
          if (isPublicRoute || state.matchedLocation == '/registration/pending') {
            return '/dashboard';
          }
        }
      } else {
        if (!isPublicRoute) {
          return '/splash';
        }
      }
      return null;
    },
  );
});
