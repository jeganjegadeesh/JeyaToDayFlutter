import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum AppButtonType { primary, secondary, danger, success }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 48,
  });

  Color get _backgroundColor {
    switch (type) {
      case AppButtonType.primary:
        return AppColors.primary;
      case AppButtonType.secondary:
        return AppColors.surface;
      case AppButtonType.danger:
        return AppColors.error;
      case AppButtonType.success:
        return AppColors.success;
    }
  }

  Color get _foregroundColor {
    switch (type) {
      case AppButtonType.secondary:
        return AppColors.primary;
      default:
        return AppColors.textWhite;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          foregroundColor: _foregroundColor,
          elevation: type == AppButtonType.secondary ? 0 : 2,
          side: type == AppButtonType.secondary
              ? const BorderSide(color: AppColors.primary)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _foregroundColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}