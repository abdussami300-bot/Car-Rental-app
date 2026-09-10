import 'package:flutter/material.dart';

class AppTheme {
  // ================= ELECTRIC CYAN & NEON BLUE PALETTE =================
  static const Color primary = Color(0xFF00B4D8);       // Vibrant Electric Cyan Blue
  static const Color primaryDark = Color(0xFF0077B6);   // Deep Oceanic Blue
  static const Color primaryLight = Color(0xFF48CAE4);  // Radiant Neon Cyan
  static const Color accent = Color(0xFF00E5FF);        // Vibrant Cyan Glow

  // ================= DARK THEME SURFACES =================
  static const Color bgDark = Color(0xFF121212);        // OLED Black Background
  static const Color cardDark = Color(0xFF1E1E1E);      // Surface Card
  static const Color cardBorder = Color(0xFF1E2E38);    // Subtle Cyan-Tinted Border

  // ================= GRADIENTS =================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient hostBannerGradient = LinearGradient(
    colors: [Color(0xFF0D2538), Color(0xFF1E1E1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
