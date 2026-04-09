import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CAppTheme {
  // Primary Color Palette - Clean Blue
  static const Color primaryColor = Color(0xFF4A6CF7);
  static const Color primaryLight = Color(0xFF6B8AFF);
  static const Color primaryDark = Color(0xFF3B5DE7);

  // Secondary Color Palette
  static const Color secondaryColor = Color(0xFF7C8CF8);
  static const Color secondaryLight = Color(0xFFA5B4FC);
  static const Color secondaryDark = Color(0xFF5B6BF0);

  // Accent Colors
  static const Color accentColor = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF38BDF8);

  // Neutral Colors
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // Border Colors
  static const Color borderColor = Color(0xFFE8ECF4);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF7C8293);
  static const Color textTertiary = Color(0xFFADB3C5);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A6CF7), Color(0xFF6B8AFF)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B8AFF), Color(0xFF38BDF8)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF38BDF8)],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFFF6B6B)],
  );

  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF4A6CF7)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4A6CF7), Color(0xFF3B5DE7)],
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF4A6CF7).withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  // Border Radius
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXL = 20;
  static const double radiusRound = 24;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        color: cardColor,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          side: const BorderSide(color: primaryColor, width: 1.5),
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.poppins(color: textTertiary, fontSize: 14),
        prefixIconColor: textSecondary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -1,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.normal, color: textPrimary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.normal, color: textSecondary,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
        ),
      ),
      iconTheme: const IconThemeData(color: textPrimary, size: 24),
      dividerTheme: const DividerThemeData(color: borderColor, thickness: 1, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textTertiary,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F3FF),
        selectedColor: primaryColor,
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        side: BorderSide.none,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryColor,
        labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: const Color(0xFF0F1320),
      colorScheme: ColorScheme.dark(
        primary: primaryLight,
        secondary: secondaryLight,
        tertiary: accentColor,
        surface: const Color(0xFF1A1F36),
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        color: const Color(0xFF1A1F36),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white70,
        ),
      ),
    );
  }
}
