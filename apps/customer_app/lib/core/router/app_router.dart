import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../widgets/app_shell.dart';

import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/phone_entry_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/search/presentation/pages/search_results_page.dart';
import '../../features/car_detail/presentation/pages/car_detail_page.dart';
import '../../features/booking/presentation/pages/booking_flow_page.dart';
import '../../features/booking/presentation/pages/booking_confirmation_page.dart';
import '../../features/my_bookings/presentation/pages/booking_detail_page.dart';
import '../../features/my_bookings/presentation/pages/my_bookings_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/wishlist/presentation/pages/wishlist_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(sessionProvider, (_, __) {
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
        path: '/auth/register',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return RegisterPage(phone: phone);
        },
      ),

      // Stateful Shell Route for Bottom Navigation
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) {
                  final city = state.uri.queryParameters['city'] ?? '';
                  final tripType = state.uri.queryParameters['tripType'] ?? '';
                  final start = state.uri.queryParameters['start'] ?? '';
                  final end = state.uri.queryParameters['end'] ?? '';
                  final pickup = state.uri.queryParameters['pickup'] ?? '';
                  final drop = state.uri.queryParameters['drop'] ?? '';
                  final category = state.uri.queryParameters['category'] ?? '';
                  return SearchResultsPage(
                    city: city,
                    tripType: tripType,
                    start: start,
                    end: end,
                    pickup: pickup,
                    drop: drop,
                    category: category,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const MyBookingsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // Pushed Screens overlaying the bottom navigation shell
      GoRoute(
        path: '/car/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CarDetailPage(carId: id);
        },
      ),
      GoRoute(
        path: '/booking/:carId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final carId = state.pathParameters['carId'] ?? '';
          return BookingFlowPage(carId: carId);
        },
      ),
      GoRoute(
        path: '/booking/confirmation/:bookingId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return BookingConfirmationPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/bookings/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BookingDetailPage(bookingId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/wishlist',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WishlistPage(),
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated = ref.read(sessionProvider).isAuthenticated;
      final isLoggingIn = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding';

      if (isAuthenticated) {
        if (isLoggingIn) return '/home';
      } else {
        if (!isLoggingIn) return '/splash';
      }
      return null;
    },
  );
});
