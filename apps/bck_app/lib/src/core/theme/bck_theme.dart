import 'package:flutter/material.dart';

enum BckAccentTheme {
  gold('Dourado', Color(0xFFD6A84B)),
  rose('Rosé', Color(0xFFC9828C));

  const BckAccentTheme(this.label, this.accent);
  final String label;
  final Color accent;
}

class BckTheme {
  static const background = Color(0xFF10151D);
  static const surface = Color(0xFF171D27);

  static ThemeData dark(BckAccentTheme accentTheme) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accentTheme.accent,
      brightness: Brightness.dark,
      surface: surface,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
      ),
      useMaterial3: true,
    );
  }
}
