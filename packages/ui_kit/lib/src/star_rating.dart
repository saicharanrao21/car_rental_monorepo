import 'package:flutter/material.dart';
import 'package:core/core.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final ValueChanged<double>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 20.0,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        final IconData icon;

        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        final starWidget = Icon(
          icon,
          size: size,
          color: AppColors.accent,
        );

        if (onRatingChanged != null) {
          return GestureDetector(
            onTap: () => onRatingChanged!(starValue),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: starWidget,
            ),
          );
        }

        return starWidget;
      }),
    );
  }
}
