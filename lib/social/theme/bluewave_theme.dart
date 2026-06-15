import 'package:flutter/material.dart';

/// BlueWave visual identity — wave-inspired accent layered on FBLA navy/gold.
class BlueWaveTheme {
  BlueWaveTheme._();

  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color deep = Color(0xFF0C4A6E);
  static const Color surface = Color(0xFF0F2744);
  static const Color waveGlow = Color(0xFF38BDF8);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C4A6E), Color(0xFF0F2744), Color(0xFF07111F)],
  );

  static const LinearGradient waveAccent = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
  );

  static BoxDecoration cardDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark
            ? primary.withValues(alpha: 0.22)
            : primary.withValues(alpha: 0.14),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
