import 'package:flutter/material.dart';

class AppTheme {
  // Warm minimal light palette
  static const Color warmBackground = Color(0xFFF3EDE7); // warm cream
  static const Color warmSurface    = Color(0xFFFFFFFF); // pure white
  static const Color accent         = Color(0xFFE8651A); // warm orange
  static const Color accentBlue     = Color(0xFFC47A4A); // warm amber (secondary)
  static const Color accentLight    = Color(0xFFFFF0E8); // light orange tint
  static const Color textPrimary    = Color(0xFF1C1C1E); // near black
  static const Color textSecondary  = Color(0xFF9E9A96); // warm medium gray
  static const Color glassColor     = Color(0xFFFFFFFF); // white surface
  static const Color glassBorder    = Color(0xFFEDE8E3); // subtle warm border
  static const Color cardBorder     = Color(0xFFEDE8E3); // card border
  static const Color divider        = Color(0xFFEDE8E3); // divider

  // Gradients
  static const List<Color> gradientOrange = [Color(0xFFE8651A), Color(0xFFFF9A5C)];
  static const List<Color> gradientWarm   = [Color(0xFFD4A883), Color(0xFF8B6045)];
  static const List<Color> gradientLight  = [Color(0xFFFFF3EC), Color(0xFFF3EDE7)];
  static const List<Color> gradientDark   = [Color(0xFF1C1C1E), Color(0xFF2C2C2E)];
  // Legacy aliases kept for backward compatibility
  static const List<Color> gradientRose   = gradientOrange;
  static const List<Color> gradientPurple = gradientWarm;
  static const List<Color> gradientPink   = gradientOrange;

  static ThemeData get theme => ThemeData(
        colorScheme: const ColorScheme.light(
          brightness: Brightness.light,
          primary: textPrimary,
          onPrimary: warmBackground,
          secondary: accent,
          onSecondary: Colors.white,
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
            backgroundColor: textPrimary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: textSecondary,
          ),
        ),
        cardTheme: CardThemeData(
          color: warmSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: cardBorder,
          thumbColor: accent,
          overlayColor: accent.withValues(alpha: 0.12),
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
