import 'package:flutter/material.dart';

class AppSpacing {
  // Margins & Padding
  static const double xs = 4;
  static const double s = 8;
  static const double sm = 12;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // BorderRadius
  static const double radiusS = 8;
  static const double radiusM = 16;
  static const double radiusL = 24;
  static const double radiusXL = 32;

  // Icon Sizes
  static const double iconS = 16;
  static const double iconM = 24;
  static const double iconL = 32;

  // EdgeInsets helpers
  static const EdgeInsets edgeInsetsAllS = EdgeInsets.all(s);
  static const EdgeInsets edgeInsetsAllM = EdgeInsets.all(m);
  static const EdgeInsets edgeInsetsAllL = EdgeInsets.all(l);

  static const EdgeInsets edgeInsetsH_S = EdgeInsets.symmetric(horizontal: s);
  static const EdgeInsets edgeInsetsH_M = EdgeInsets.symmetric(horizontal: m);
  static const EdgeInsets edgeInsetsH_L = EdgeInsets.symmetric(horizontal: l);

  const AppSpacing._();
}
