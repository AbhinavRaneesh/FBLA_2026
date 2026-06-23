import 'package:flutter/material.dart';

import '../main.dart' show AppState, fblaLightPrimaryText;

ThemeData applyAccessibilityTheme(ThemeData theme, AppState app) {
  var result = theme;

  if (app.accessibilityHighContrast) {
    final isDark = theme.brightness == Brightness.dark;
    result = result.copyWith(
      colorScheme: result.colorScheme.copyWith(
        onSurface: isDark ? Colors.white : Colors.black,
        onPrimary: isDark ? Colors.white : Colors.black,
        outline: isDark ? Colors.white70 : Colors.black87,
      ),
      dividerColor: isDark ? Colors.white60 : Colors.black87,
      textTheme: result.textTheme.apply(
        bodyColor: isDark ? Colors.white : fblaLightPrimaryText,
        displayColor: isDark ? Colors.white : fblaLightPrimaryText,
      ),
    );
  }

  if (app.accessibilityLargeTapTargets) {
    result = result.copyWith(
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  return result;
}
