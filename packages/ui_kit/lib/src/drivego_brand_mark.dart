import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// Modern DriveGo Aerodynamic Brand Mark
/// Renders the signature aerodynamic wing vector with automotive precision.
class DriveGoBrandMark extends StatelessWidget {
  final double size;
  final bool isVendor;
  final bool showWordmark;
  final Color? wordmarkColor;

  const DriveGoBrandMark({
    super.key,
    this.size = 64.0,
    this.isVendor = false,
    this.showWordmark = false,
    this.wordmarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size(size, size),
      painter: _DriveGoMarkPainter(isVendor: isVendor),
    );

    if (!showWordmark) {
      return mark;
    }

    final effectiveTextColor = wordmarkColor ?? DDSColors.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(height: size * 0.2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Drive',
              style: DDSTypography.headlineLarge.copyWith(
                color: effectiveTextColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Go',
              style: DDSTypography.headlineLarge.copyWith(
                color: DDSColors.primaryBlue,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            if (isVendor) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DDSColors.accentTeal,
                  borderRadius: DDSRadius.smallBorderRadius,
                ),
                child: Text(
                  'PARTNER',
                  style: DDSTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DriveGoMarkPainter extends CustomPainter {
  final bool isVendor;

  _DriveGoMarkPainter({required this.isVendor});

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 108.0;

    canvas.save();
    canvas.scale(scale, scale);

    // Primary Aerodynamic Wing (Electric Blue)
    final bluePaint = Paint()
      ..color = DDSColors.primaryBlue
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bluePath = Path()
      ..moveTo(34, 40)
      ..cubicTo(34, 36.5, 37, 34, 41, 34)
      ..lineTo(62, 34)
      ..cubicTo(71, 34, 77, 39, 77, 47)
      ..cubicTo(77, 53, 72, 57, 65, 58)
      ..lineTo(45, 58)
      ..cubicTo(42, 58, 39.5, 56, 39.5, 53)
      ..cubicTo(39.5, 50, 42, 48, 45, 48)
      ..lineTo(61, 48)
      ..cubicTo(64.5, 48, 67, 46, 67, 43.5)
      ..cubicTo(67, 41, 64.5, 39.5, 61, 39.5)
      ..lineTo(41, 39.5)
      ..cubicTo(37, 39.5, 34, 42, 34, 40)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Aerodynamic Chassis & Speed Contour (Pure White)
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final whitePath = Path()
      ..moveTo(31, 52)
      ..cubicTo(31, 48.5, 34, 46, 38, 46)
      ..lineTo(60, 46)
      ..cubicTo(63, 46, 65, 47.5, 65, 49.5)
      ..cubicTo(65, 51.5, 63, 53, 60, 53)
      ..lineTo(43, 53)
      ..cubicTo(39.5, 53, 37, 55, 37, 58)
      ..cubicTo(37, 63.5, 42, 67.5, 49, 67.5)
      ..lineTo(67, 67.5)
      ..cubicTo(70, 67.5, 72, 69.5, 72, 71.5)
      ..cubicTo(72, 73.5, 70, 75.5, 67, 75.5)
      ..lineTo(47, 75.5)
      ..cubicTo(36.5, 75.5, 29, 67.5, 29, 58)
      ..cubicTo(29, 55.5, 30, 53.5, 31, 52)
      ..close();
    canvas.drawPath(whitePath, whitePaint);

    // Velocity Indicator Accent / Partner Accent
    final accentPaint = Paint()
      ..color = isVendor ? DDSColors.accentTeal : DDSColors.accentAmber
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(const Offset(72, 58.5), 4.5, accentPaint);

    if (isVendor) {
      // Vendor Underline Fleet Speed Line
      final partnerLinePath = Path()
        ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(42, 80, 24, 4),
          const Radius.circular(2),
        ));
      canvas.drawPath(partnerLinePath, accentPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DriveGoMarkPainter oldDelegate) {
    return oldDelegate.isVendor != isVendor;
  }
}
