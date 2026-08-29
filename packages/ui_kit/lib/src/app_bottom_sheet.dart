import 'package:flutter/material.dart';
import 'drivego_bottom_sheet.dart';

/// Legacy AppBottomSheet maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoBottomSheet.
class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return DriveGoBottomSheet.show<T>(
      context,
      child: child,
      title: title,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }
}
