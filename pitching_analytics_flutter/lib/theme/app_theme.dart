import 'package:flutter/material.dart';

/// Colors ported 1:1 from the R Shiny app's PERF_COLORS / UI_BLUE_* / pitch & spray palettes.
/// Keeping these exact hex values is what makes the Flutter app "look like" the Shiny app.
class AppColors {
  // Performance tiers (used to color-code stat boxes / tables)
  static const Color perfExcellent = Color(0xFF15803D);
  static const Color perfGood = Color(0xFF4ADE80);
  static const Color perfAverage = Color(0xFFFACC15);
  static const Color perfBelowAvg = Color(0xFFFB923C);
  static const Color perfPoor = Color(0xFFDC2626);

  // Brand blues
  static const Color blueDark = Color(0xFF1E3A8A);
  static const Color blueMid = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFFEFF6FF);

  // Single orange used for every main-navigation icon, so the sidebar
  // reads as one consistent accent color rather than a rotating palette.
  static const Color navIconOrange = Color(0xFFF97316);

  // Text / borders
  static const Color colText = Color(0xFF111827);
  static const Color colMuted = Color(0xFF6B7280);
  static const Color colBorder = Color(0xFFE5E7EB);
  static const Color colSuccess = Color(0xFF22C55E);
  static const Color colError = Color(0xFFEF4444);

  // Pitch type ring colors
  static const Map<String, Color> pitchColors = {
    'fb': Color(0xFF2563EB),
    'sl': Color(0xFF7C3AED),
    'cv': Color(0xFFDB2777),
    'ch': Color(0xFF14B8A6),
    'other': Color(0xFF6B7280),
  };

  // Spray-chart outcome fill colors
  static const Map<String, Color> sprayOutcomeColors = {
    '1b': Color(0xFF22C55E),
    '2b': Color(0xFF2563EB),
    '3b': Color(0xFF7C3AED),
    'hr': Color(0xFFF97316),
    'go': Color(0xFFDC2626),
    'fo': Color(0xFFDC2626),
    'lo': Color(0xFFDC2626),
    'dp': Color(0xFFDC2626),
    'e': Color(0xFFFACC15),
    'fc': Color(0xFF6B7280),
    'out': Color(0xFFDC2626),
  };

  // Fallback palette for custom/user-defined pitch types (e.g. "KN", "EP")
  // that aren't one of the built-in fb/sl/cv/ch codes. Picked deterministically
  // from the code so the same custom pitch always gets the same color.
  static const List<Color> _customPitchPalette = [
    Color(0xFFEA580C), // orange
    Color(0xFF059669), // emerald
    Color(0xFFCA8A04), // amber
    Color(0xFF9333EA), // purple
    Color(0xFFE11D48), // rose
    Color(0xFF0891B2), // cyan
    Color(0xFF65A30D), // lime
    Color(0xFFBE185D), // pink
  ];

  /// User-chosen colors for custom pitch types (set on Game Input when a
  /// new pitch is created — see [AppSession.addCustomPitchType]), keyed by
  /// the same lowercase, trimmed key used everywhere else a pitch type is
  /// looked up. Checked first so a color picked once is used consistently
  /// everywhere a pitch appears: the pitch button, the spray chart, pitch
  /// history, pitch breakdown, and every other pitch visualization.
  static final Map<String, Color> _customOverrides = {};

  /// Replaces the whole custom-color override table — called once on
  /// login/logout and whenever a custom pitch color is added, changed, or
  /// removed, so every screen reading [pitchColor] picks up the change
  /// immediately without needing its own copy of the data.
  static void setCustomPitchColors(Map<String, Color> colors) {
    _customOverrides
      ..clear()
      ..addAll(colors);
  }

  static Color pitchColor(String? pt) {
    if (pt == null || pt.trim().isEmpty) return pitchColors['other']!;
    final key = pt.toLowerCase().trim();
    if (_customOverrides.containsKey(key)) return _customOverrides[key]!;
    if (pitchColors.containsKey(key)) return pitchColors[key]!;
    final sum = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return _customPitchPalette[sum % _customPitchPalette.length];
  }

  /// Preset swatches offered when creating a new pitch type — deliberately
  /// a fixed palette (no color-wheel dependency) so every custom pitch
  /// still reads as part of the same professional analytics look.
  static const List<Color> pitchColorPresets = [
    Color(0xFFEA580C), // orange
    Color(0xFF059669), // emerald
    Color(0xFFCA8A04), // amber
    Color(0xFF9333EA), // purple
    Color(0xFFE11D48), // rose
    Color(0xFF0891B2), // cyan
    Color(0xFF65A30D), // lime
    Color(0xFFBE185D), // pink
    Color(0xFF2563EB), // blue
    Color(0xFF475569), // slate
    Color(0xFFB45309), // brown
    Color(0xFF0D9488), // teal
  ];

  static Color sprayColor(String? outcome) {
    if (outcome == null) return const Color(0xFFDC2626);
    return sprayOutcomeColors[outcome.toLowerCase().trim()] ??
        const Color(0xFFDC2626);
  }
}

/// The app's ThemeData — deliberately close to the Shiny bslib defaults
/// (white cards, blue-dark headers, rounded corners).
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blueDark,
      primary: AppColors.blueDark,
      secondary: AppColors.blueMid,
    ),
    fontFamily: 'Roboto',
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.colBorder, width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    // Gives dialogs a little more room on phones; no visible change on
    // desktop where dialogs are far narrower than the window.
    dialogTheme: const DialogThemeData(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.blueDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blueDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.colBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.colBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.blueMid, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    // Applies to every hover/long-press tooltip in the app — plain Tooltip
    // widgets AND the `tooltip:` shorthand on IconButton etc. — so every
    // popup shares the same brand-blue background with guaranteed-readable
    // white text, regardless of what's behind it.
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.blueDark.withOpacity(0.96),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.all(8),
      preferBelow: true,
      waitDuration: const Duration(milliseconds: 400),
    ),
  );
}
