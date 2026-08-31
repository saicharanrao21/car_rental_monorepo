import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';

/// Customer App Search Car Card — standard DDS vehicle card wrapper
class SearchCarCard extends StatelessWidget {
  final CarModel car;
  final VoidCallback onTap;
  final bool isWishlisted;
  final VoidCallback? onWishlistToggle;
  final String ctaText;

  const SearchCarCard({
    super.key,
    required this.car,
    required this.onTap,
    this.isWishlisted = false,
    this.onWishlistToggle,
    this.ctaText = 'Book Now',
  });

  @override
  Widget build(BuildContext context) {
    return CarCard(
      car: car,
      onTap: onTap,
      isWishlisted: isWishlisted,
      onWishlistToggle: onWishlistToggle,
      imageHeight: 160.0,
      ctaText: ctaText,
    );
  }
}
