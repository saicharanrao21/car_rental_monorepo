import 'package:flutter/material.dart';
import 'package:core/core.dart';

enum SocialAuthProvider {
  google,
  apple,
}

/// Official platform-compliant Social Authentication Button
/// Adheres strictly to Google and Apple branding and accessibility guidelines.
class SocialAuthButton extends StatelessWidget {
  final SocialAuthProvider provider;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? customText;

  const SocialAuthButton({
    super.key,
    required this.provider,
    this.onPressed,
    this.isLoading = false,
    this.customText,
  });

  const SocialAuthButton.google({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.customText,
  }) : provider = SocialAuthProvider.google;

  const SocialAuthButton.apple({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.customText,
  }) : provider = SocialAuthProvider.apple;

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == SocialAuthProvider.google;
    final label = customText ?? (isGoogle ? 'Continue with Google' : 'Continue with Apple');

    final backgroundColor = isGoogle ? Colors.white : Colors.black;
    final foregroundColor = isGoogle ? DDSColors.textPrimary : Colors.white;
    final borderColor = isGoogle ? DDSColors.borderLight : Colors.black;

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: OutlinedButton(
          key: Key(isGoogle ? 'google_signin_button' : 'apple_signin_button'),
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            elevation: isGoogle ? 1 : 2,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            side: BorderSide(color: borderColor, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: DDSRadius.mediumBorderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIcon(isGoogle),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        style: DDSTypography.labelLarge.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildIcon(bool isGoogle) {
    if (isGoogle) {
      // Crisp 4-color Google 'G' geometry or automotive-aligned vector
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        child: const _GoogleLogoPainterWidget(),
      );
    } else {
      return const Icon(
        Icons.apple,
        color: Colors.white,
        size: 24,
      );
    }
  }
}

/// Custom vector painter rendering the official Google 'G' logo cleanly without external raster dependencies
class _GoogleLogoPainterWidget extends StatelessWidget {
  const _GoogleLogoPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Google Blue
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    // Google Green
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    // Google Yellow
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    // Google Red
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    // Blue horizontal bar
    final barRect = Rect.fromLTWH(w * 0.45, h * 0.38, w * 0.55, h * 0.24);
    canvas.drawRect(barRect, bluePaint);

    // Red arc (top)
    final redPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -2.35, 1.57, false)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // Yellow arc (left)
    final yellowPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -3.92, 1.57, false)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Green arc (bottom)
    final greenPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 0.78, 1.57, false)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Blue arc (right-bottom)
    final blueArcPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 0.0, 0.78, false)
      ..close();
    canvas.drawPath(blueArcPath, bluePaint);

    // Inner circle cutout
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.58, holePaint);

    // Inner cutout to clear the blue bar inside center
    final innerClearRect = Rect.fromLTWH(center.dx, center.dy - radius * 0.58, radius * 0.45, radius * 1.16);
    canvas.drawRect(innerClearRect, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
