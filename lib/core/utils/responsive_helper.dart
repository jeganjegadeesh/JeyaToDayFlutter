import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppResponsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppConstants.mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppConstants.mobileBreakpoint &&
      MediaQuery.of(context).size.width < AppConstants.desktopBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // Responsive value based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }

  // Responsive padding
  static EdgeInsets padding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.all(32);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(16);
  }

  // Responsive font size
  static double fontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    required double desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }

  // Sidebar width
  static double sidebarWidth(BuildContext context) {
    if (isDesktop(context)) return 260;
    if (isTablet(context)) return 220;
    return 0;
  }

  // Card cross axis count for grid
  static int gridCrossAxisCount(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 2;
    return 1;
  }

  // Content max width
  static double contentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 1200;
    return double.infinity;
  }
}