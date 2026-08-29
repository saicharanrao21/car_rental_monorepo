import 'package:flutter/material.dart';
import 'drivego_loading_state.dart';

/// Legacy AppLoader maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoLoadingState.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriveGoLoadingState(variant: DriveGoLoadingVariant.fullPage);
  }
}

/// Legacy ShimmerCard maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoShimmerCard.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriveGoShimmerCard();
  }
}
