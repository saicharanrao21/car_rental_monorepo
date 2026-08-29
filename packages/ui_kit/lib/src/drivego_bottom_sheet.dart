import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';

/// DriveGo Design System (DDS) — Standard Modal Bottom Sheet Utility
class DriveGoBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    Widget? trailingAction,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: DDSColors.surfaceCard,
            borderRadius: DDSRadius.sheetTopRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: DDSColors.borderMedium,
                        borderRadius: DDSRadius.pillBorderRadius,
                      ),
                    ),
                  ),

                  // Header Bar
                  if (title != null || trailingAction != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (title != null)
                            Expanded(
                              child: Text(
                                title,
                                style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (trailingAction != null)
                            trailingAction
                          else
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded, size: 22, color: DDSColors.textSecondary),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: DDSColors.borderLight),
                    const Gap(8),
                  ],

                  // Body Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
