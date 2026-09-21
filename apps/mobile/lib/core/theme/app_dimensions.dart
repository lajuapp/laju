import 'package:flutter/material.dart';

class AppDimensions {
  // Padding & Margins
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Border Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusCircular = 999.0;

  static const BorderRadius roundedSmall = BorderRadius.all(Radius.circular(radiusSmall));
  static const BorderRadius roundedMedium = BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius roundedLarge = BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius roundedXLarge = BorderRadius.all(Radius.circular(radiusXLarge));

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 22.0;
  static const double iconLarge = 28.0;
  static const double iconXLarge = 40.0;

  // Element Heights
  static const double buttonHeight = 50.0;
  static const double inputHeight = 44.0;
  static const double avatarSmall = 20.0;
  static const double avatarMedium = 26.0;
  static const double avatarLarge = 64.0;
}
