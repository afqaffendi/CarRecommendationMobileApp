import 'package:flutter/material.dart';

class AppTheme {
  // Dark palette — rose/pink accent
  static const Color warmBackground = Color(0xFF080808);
  static const Color warmSurface    = Color(0xFF161616);
  static const Color accent         = Color(0xFFE8428A);  // vivid rose-pink
  static const Color accentBlue     = Color(0xFF7B6FC0);  // purple (complementary)
  static const Color accentLight    = Color(0xFF1E0A15);  // dark rose tint for containers
  static const Color textPrimary    = Color(0xFFFFFFFF);
  static const Color textSecondary  = Color.fromARGB(255, 223, 223, 223);
  static const Color glassColor     = Color(0x12FFFFFF);  // dark glass
  static const Color glassBorder    = Color(0x14FFFFFF);  // subtle white border
  static const Color cardBorder     = Color(0x14FFFFFF);
  static const Color divider        = Color(0x14FFFFFF);

  // Gradient card colors
  static const List<Color> gradientRose   = [Color(0xFFE8428A), Color(0xFFA01555)];
  static const List<Color> gradientPurple = [Color(0xFF7B6FC0), Color(0xFF3D3080)];
  static const List<Color> gradientPink   = [Color(0xFFD4607A), Color(0xFF8A3048)];
  static const List<Color> gradientWarm   = [Color(0xFFD4A883), Color(0xFF8B6045)];
  static const List<Color> gradientDark   = [Color(0xFF2A2A2A), Color(0xFF141414)];

  static ThemeData get theme => ThemeData(
        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: textPrimary,
          onPrimary: warmBackground,
          secondary: accent,
          onSecondary: textPrimary,
          tertiary: accentBlue,
          surface: warmSurface,
          onSurface: textPrimary,
        ),
        scaffoldBackgroundColor: warmBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: textPrimary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: textPrimary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: textSecondary,
          ),
        ),
        cardTheme: const CardThemeData(
          color: warmSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: warmSurface,
          contentTextStyle: const TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        dividerColor: divider,
        useMaterial3: true,
      );

  // Slide + fade right-to-left page transition
  static Route<T> slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
