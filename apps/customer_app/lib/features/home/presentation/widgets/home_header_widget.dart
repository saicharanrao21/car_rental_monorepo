import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../home_providers.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';
import '../../../../core/providers/location_provider.dart';

/// DriveGo Design System (DDS) — Modern Customer Brand & Location Header
/// Provides an authoritative location selector, contextual time-of-day greeting,
/// and accessible entry points to Wishlist and Notifications.
class HomeHeaderWidget extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback onCityTap;

  const HomeHeaderWidget({
    super.key,
    required this.onCityTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 14);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final locationState = ref.watch(userLocationProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final isLocating = locationState.detectionStatus == LocationDetectionStatus.loading;

    return AppBar(
      elevation: 0,
      backgroundColor: DDSColors.primaryNavy,
      foregroundColor: Colors.white,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getGreeting(),
                style: DDSTypography.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const Gap(4),
              const Text('👋', style: TextStyle(fontSize: 12)),
            ],
          ),
          const Gap(2),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCityTap,
              borderRadius: DDSRadius.smallBorderRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: DDSColors.accentAmber,
                      size: 18,
                    ),
                    const Gap(4),
                    Text(
                      selectedCity.isNotEmpty ? selectedCity : 'Select City',
                      style: DDSTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Gap(2),
                    if (isLocating)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DDSColors.accentAmber,
                        ),
                      )
                    else
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Wishlist / Saved Cars Entry
        IconButton(
          icon: const Icon(Icons.favorite_border_rounded, size: 22),
          tooltip: 'Saved Cars',
          onPressed: () => context.push('/wishlist'),
        ),
        // Notifications Entry with dynamic unread indicator
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, size: 23),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: DDSColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: unreadCount > 1
                        ? Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const Gap(6),
      ],
    );
  }
}
