import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'full_screen_image_viewer.dart';

class CarImageGallery extends StatefulWidget {
  final List<String> photos;
  final String carMake;
  final String carModel;
  final String carType;
  final bool isSponsored;
  final bool isFeatured;
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;
  final VoidCallback onBackPressed;
  final VoidCallback? onShare;

  const CarImageGallery({
    super.key,
    required this.photos,
    required this.carMake,
    required this.carModel,
    required this.carType,
    required this.isSponsored,
    this.isFeatured = false,
    required this.isWishlisted,
    required this.onWishlistToggle,
    required this.onBackPressed,
    this.onShare,
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

  void _openFullScreenViewer() {
    if (widget.photos.isEmpty) return;
    FullScreenImageViewer.show(
      context,
      photos: widget.photos,
      initialIndex: _currentPage,
      carTitle: '${widget.carMake} ${widget.carModel}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiplePhotos = widget.photos.length > 1;

    return Stack(
      children: [
        // ── 1. Hero Image / PageView ─────────────────────────────────────────
        GestureDetector(
          onTap: _openFullScreenViewer,
          child: Container(
            height: 290,
            width: double.infinity,
            color: DDSColors.surfaceSubtle,
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
                        errorBuilder: (_, __, ___) => _buildFallback(),
                      );
                    },
                  )
                : _buildFallback(),
          ),
        ),

        // ── 2. Top Bar Actions (Floating Back, Wishlist & Share) ───────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: DDSSpacing.md,
          right: DDSSpacing.md,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Floating Back Button
              _buildCircleButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: widget.onBackPressed,
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating Share Button
                  if (widget.onShare != null) ...[
                    _buildCircleButton(
                      icon: Icons.share_outlined,
                      tooltip: 'Share',
                      onPressed: widget.onShare!,
                    ),
                    const Gap(8),
                  ],

                  // Floating Wishlist Button
                  _buildCircleButton(
                    icon: widget.isWishlisted
                        ? Icons.favorite
                        : Icons.favorite_border,
                    iconColor: widget.isWishlisted
                        ? DDSColors.errorRed
                        : DDSColors.textPrimary,
                    tooltip: widget.isWishlisted
                        ? 'Remove from wishlist'
                        : 'Add to wishlist',
                    onPressed: widget.onWishlistToggle,
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── 3. Top-Left Badges (Sponsored / Featured) ──────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: DDSSpacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSponsored) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DDSSpacing.xs,
                    vertical: DDSSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: DDSColors.sponsoredGold,
                    borderRadius: BorderRadius.circular(DDSRadius.small),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.white),
                      const Gap(4),
                      Text(
                        'SPONSORED',
                        style: DDSTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(4),
              ],
              if (widget.isFeatured) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DDSSpacing.xs,
                    vertical: DDSSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: DDSColors.primaryBlue,
                    borderRadius: BorderRadius.circular(DDSRadius.small),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 12, color: Colors.white),
                      const Gap(4),
                      Text(
                        'FEATURED',
                        style: DDSTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── 4. Bottom Category Pill & Fullscreen Hint ───────────────────────
        Positioned(
          bottom: 14,
          right: DDSSpacing.md,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.photos.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DDSSpacing.xs,
                    vertical: DDSSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(DDSRadius.small),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fullscreen,
                        size: 14,
                        color: Colors.white,
                      ),
                      const Gap(4),
                      Text(
                        '${_currentPage + 1}/${widget.photos.length}',
                        style: DDSTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DDSSpacing.xs + 2,
                  vertical: DDSSpacing.xxs + 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(DDSRadius.small),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.carType.toUpperCase(),
                  style: DDSTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DDSColors.primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 5. Bottom Page Indicator Dots (if multiple photos) ──────────────
        if (hasMultiplePhotos)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? DDSColors.primaryBlue
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    Color? iconColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(DDSSpacing.xs + 1),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? DDSColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: DDSColors.textMuted,
          ),
        ],
      ),
    );
  }
}
