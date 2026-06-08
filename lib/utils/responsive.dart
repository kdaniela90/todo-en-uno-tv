import 'package:flutter/material.dart';

class R {
  static double w(BuildContext ctx) => MediaQuery.of(ctx).size.width;

  static bool isPhone(BuildContext ctx)  => w(ctx) < 700;
  static bool isTablet(BuildContext ctx) => w(ctx) >= 700 && w(ctx) < 1100;
  static bool isTV(BuildContext ctx)     => w(ctx) >= 1100;

  static int gridCols(BuildContext ctx) {
    final width = w(ctx);
    if (width < 600)  return 2;
    if (width < 800)  return 3;
    if (width < 1100) return 4;
    return 5;
  }

  static double catPanelW(BuildContext ctx) {
    final width = w(ctx);
    if (width < 600)  return 130;
    if (width < 1100) return 175;
    return 210;
  }

  static double padding(BuildContext ctx) => isPhone(ctx) ? 10 : 14;
  static double fs(BuildContext ctx, double base) => isPhone(ctx) ? base * 0.85 : base;
}
