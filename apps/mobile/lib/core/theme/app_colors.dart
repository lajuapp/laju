import 'package:flutter/material.dart';

class AppColors {
  // Brand Teal / Mint (from LAJU logo & design board)
  static const Color primary = Color(0xFF00C896);
  static const Color primaryDark = Color(0xFF009F75);
  static const Color primaryLight = Color(0xFFE5FBF4);
  static const Color primaryGlow = Color(0x3300C896);

  // Dark Mode Theme (Splash, Calls, App Lock, Dark Theme)
  static const Color darkBackground = Color(0xFF0B1015);
  static const Color darkSurface = Color(0xFF131B22);
  static const Color darkSurfaceElevated = Color(0xFF1D2733);
  static const Color darkSurfaceBorder = Color(0xFF263342);

  // Light Mode Theme (Chats, Settings, Welcome, Verification)
  static const Color lightBackground = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceBorder = Color(0xFFE2E8F0);

  // Default theme pointers (Clean light-based WhatsApp-elevated theme matching the board)
  static const Color background = lightBackground;
  static const Color surface = lightSurface;
  static const Color surfaceElevated = lightSurfaceElevated;
  static const Color surfaceBorder = lightSurfaceBorder;

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Dark text colors for dark screens (Calls, App Lock, Splash)
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Chat Bubbles
  static const Color bubbleOutgoing = Color(0xFFD6F8EC);
  static const Color bubbleOutgoingBorder = Color(0xFFC0F0DF);
  static const Color bubbleIncoming = Color(0xFFFFFFFF);
  static const Color bubbleIncomingBorder = Color(0xFFE5E7EB);

  // Status & Accents
  static const Color cyan = Color(0xFF00B4D8);
  static const Color danger = Color(0xFFEF4444);
  static const Color error = danger;
  static const Color warning = Color(0xFFF59E0B);
  static const Color readCheck = Color(0xFF00C896);

  // Gradients
  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF070D12), Color(0xFF0F1A24), Color(0xFF052C28)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
