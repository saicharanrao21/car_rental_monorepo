import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Application-wide scroll behavior providing controlled, modern scrolling physics.
///
/// On Android, enforces [ClampingScrollPhysics] and subtle edge glow indicator
/// rather than aggressive geometric stretch overscroll distortion.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: AppColors.primary.withValues(alpha: 0.15),
      child: child,
    );
  }
}
