import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

class CarImageGallery extends StatefulWidget {
  final List<String> photos;
  final String carType;
  final bool isSponsored;
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;
  final VoidCallback onBackPressed;

  const CarImageGallery({
    super.key,
    required this.photos,
    required this.carType,
    required this.isSponsored,
    required this.isWishlisted,
    required this.onWishlistToggle,
    required this.onBackPressed,
  });

  @override
  State<CarImageGallery> createState() => _CarImageGalleryState();
}

class _CarImageGalleryState extends State<CarImageGallery> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMultiplePhotos = widget.photos.length > 1;

    return Stack(
      children: [
        // ── 1. Hero Image / PageView ─────────────────────────────────────────
        Container(
          height: 270,
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          child: widget.photos.isNotEmpty
              ? PageView.builder(
                  controller: _pageController,
                  itemCount: widget.photos.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final photoUrl = widget.photos[index];
                    return Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallback(cs),
                    );
                  },
                )
              : _buildFallback(cs),
        ),

        // ── 2. Top Bar Actions (Floating Back & Wishlist) ───────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Floating Back Button
              Material(
                color: Colors.white.withValues(alpha: 0.88),
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onBackPressed,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),

              // Floating Wishlist Button
              Material(
                color: Colors.white.withValues(alpha: 0.88),
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onWishlistToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      widget.isWishlisted ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: widget.isWishlisted ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 3. Top-Left Sponsored Badge ─────────────────────────────────────
        if (widget.isSponsored)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber[800],
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: Colors.white),
                  Gap(4),
                  Text(
                    'Sponsored',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

        // ── 4. Bottom-Right Vehicle Category Pill ───────────────────────────
        Positioned(
          bottom: 14,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              widget.carType.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        // ── 5. Bottom Page Indicator Dots (if multiple photos) ──────────────
        if (hasMultiplePhotos)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallback(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_filled_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
          ),
          const Gap(8),
          Text(
            'Vehicle Preview Image',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
