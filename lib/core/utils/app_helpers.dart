import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class AppHelpers {
  // Format date to display
  static String formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (e) {
      return date;
    }
  }

  // Format currency
  static String formatCurrency(dynamic amount) {
    if (amount == null) return '₹0.00';
    final double value = double.tryParse(amount.toString()) ?? 0.0;
    return '₹${NumberFormat('#,##,##0.00').format(value)}';
  }

  // Format number
  static String formatNumber(dynamic number) {
    if (number == null) return '0';
    return NumberFormat('#,##,##0').format(number);
  }

  // Today date string
  static String todayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // Show snackbar success
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Show snackbar error
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Show loading dialog
  static void showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }

  // Hide loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // Show confirm dialog
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Get initials from name
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // Validate mobile number
  static bool isValidMobile(String mobile) {
    return RegExp(r'^[0-9]{10}$').hasMatch(mobile);
  }
}