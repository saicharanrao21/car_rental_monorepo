import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'app_card.dart';

class LocationPreviewCard extends StatelessWidget {
  final String title;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? distanceText;
  final String? etaText;
  final VoidCallback? onNavigate;

  const LocationPreviewCard({
    super.key,
    required this.title,
    required this.address,
    this.latitude,
    this.longitude,
    this.distanceText,
    this.etaText,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = latitude != null && longitude != null;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: Colors.blue, size: 20),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),

          // Map Preview Tile
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Simulated Grid & Road Lines for Map Aesthetic
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SimulatedMapPainter(),
                  ),
                ),
                // Center Map Marker
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_pin, color: Colors.red, size: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasCoordinates
                            ? '${latitude!.toStringAsFixed(3)}, ${longitude!.toStringAsFixed(3)}'
                            : 'GPS Pending',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                // Distance & ETA Badges
                if (distanceText != null || etaText != null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (distanceText != null) ...[
                            const Icon(Icons.directions_car, size: 12, color: Colors.blue),
                            const Gap(4),
                            Text(
                              distanceText!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ],
                          if (distanceText != null && etaText != null)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('•', style: TextStyle(color: Colors.grey)),
                            ),
                          if (etaText != null) ...[
                            const Icon(Icons.access_time, size: 12, color: Colors.green),
                            const Gap(4),
                            Text(
                              etaText!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(12),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasCoordinates ? 'GPS Verified' : 'Manual Address',
                style: TextStyle(
                  fontSize: 11,
                  color: hasCoordinates ? Colors.green[700] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation_outlined, size: 16),
                label: const Text('Open in Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimulatedMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final secondaryPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..cubicTo(size.width * 0.4, size.height * 0.2, size.width * 0.6, size.height * 0.8, size.width, size.height * 0.7);

    final path2 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..lineTo(size.width * 0.8, size.height);

    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path2, secondaryPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
