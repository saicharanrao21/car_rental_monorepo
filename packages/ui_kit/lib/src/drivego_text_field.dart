import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// DriveGo Design System (DDS) — Standard Form Input Component
class DriveGoTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final int? maxLines;
  final int? maxLength;
  final FocusNode? focusNode;

  const DriveGoTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: DDSTypography.labelLarge.copyWith(
            color: enabled ? DDSColors.textPrimary : DDSColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          onChanged: onChanged,
          onTap: onTap,
          style: DDSTypography.bodyLarge.copyWith(
            color: enabled ? DDSColors.textPrimary : DDSColors.textMuted,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? DDSColors.surfaceSubtle : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: DDSRadius.mediumBorderRadius,
              borderSide: const BorderSide(color: DDSColors.borderMedium),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DDSRadius.mediumBorderRadius,
              borderSide: const BorderSide(color: DDSColors.borderMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: DDSRadius.mediumBorderRadius,
              borderSide: const BorderSide(color: DDSColors.primaryBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: DDSRadius.mediumBorderRadius,
              borderSide: const BorderSide(color: DDSColors.errorRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: DDSRadius.mediumBorderRadius,
              borderSide: const BorderSide(color: DDSColors.errorRed, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: DDSRadius.mediumBorderRadius,
              borderSide: const BorderSide(color: DDSColors.borderLight),
            ),
          ),
        ),
      ],
    );
  }
}
