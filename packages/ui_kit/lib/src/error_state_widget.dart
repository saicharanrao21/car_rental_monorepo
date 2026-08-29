import 'package:flutter/material.dart';
import 'drivego_error_state.dart';

/// Legacy ErrorStateWidget maintained for backward compatibility.
/// Forwards directly to DriveGo Design System (DDS) DriveGoErrorState.
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return DriveGoErrorState(
      message: message,
      onRetry: onRetry,
    );
  }
}
