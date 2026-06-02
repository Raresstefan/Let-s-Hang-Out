import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central theme. A warm, friendly, social palette — coral/orange primary to
/// feel inviting and reduce the "social anxiety" the product targets. The
/// "bold & vibrant social" direction adds expressive typography (Sora display +
/// Inter body), brand gradients, and soft floating shadows.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFFFF6B5E); // warm coral
  static const Color peach = Color(0xFFFF8A5B); // gradient partner
  static const Color accent = Color(0xFF2EC4B6); // teal accent

  /// Signature brand gradient (coral → peach). Used on primary CTAs and the
  /// create button.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [seed, peach],
  );

  /// Soft, large, low-opacity shadow for a premium "floating" feel — replaces
  /// hard Material elevation.
  static List<BoxShadow> softShadow({double opacity = 0.10, double blur = 24}) =>
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity),
          blurRadius: blur,
          offset: const Offset(0, 8),
        ),
      ];

  static const double cardRadius = 24;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(secondary: accent);

    // Expressive headings (Sora) + highly legible body (Inter).
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.sora(fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.sora(fontWeight: FontWeight.w800),
      displaySmall: GoogleFonts.sora(fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w800),
      headlineMedium: GoogleFonts.sora(fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.sora(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.sora(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.sora(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFFBF7F4),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        // Soft shadow is applied per-card via a Container decoration; keep the
        // Material elevation flat so they don't double up.
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
