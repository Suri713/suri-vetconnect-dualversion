import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArtDecoTheme {
  static const Color backgroundStart = Color(0xFFD22A1F);
  static const Color backgroundEnd = Color(0xFF13183B);
  static const Color foreground = Color(0xFFF2E6E4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceMuted = Color(0xFF5C5C5C);
  static const Color accent = Color(0xFFF8F6F0);
  static const Color muted = Color(0xFFD8CFC9);
  static const Color fieldFill = Color(0xFFF2F0EC);
  static const double pillRadius = 30;

  static TextTheme onSurfaceTextTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(color: onSurface),
      headlineMedium: base.headlineMedium?.copyWith(color: onSurface),
      titleLarge: base.titleLarge?.copyWith(color: onSurface),
      titleMedium: base.titleMedium?.copyWith(color: onSurface),
      bodyLarge: base.bodyLarge?.copyWith(color: onSurface),
      bodyMedium: base.bodyMedium?.copyWith(color: onSurface, height: 1.6),
      bodySmall: base.bodySmall?.copyWith(color: onSurfaceMuted, height: 1.6),
      labelLarge: base.labelLarge?.copyWith(color: onSurface),
      labelMedium: base.labelMedium?.copyWith(color: onSurface),
    );
  }

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: accent,
        secondary: foreground,
        surface: surface,
        onPrimary: onSurface,
        onSurface: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: accent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.quicksand(
          color: accent,
          fontSize: 22,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: _textTheme(base.textTheme),
      inputDecorationTheme: _inputDecorationTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _filledButtonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlineButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle()),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: Color(0x33000000), width: 1),
        ),
      ),
      dividerColor: const Color(0x33F8F6F0),
      datePickerTheme: _datePickerTheme(),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: onSurface,
        unselectedItemColor: onSurfaceMuted,
        selectedLabelStyle: GoogleFonts.quicksand(
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.quicksand(
          letterSpacing: 0.2,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  static DatePickerThemeData _datePickerTheme() {
    Color dayForeground(Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) return surface;
      if (states.contains(WidgetState.disabled)) return onSurfaceMuted;
      return onSurface;
    }

    Color? dayBackground(Set<WidgetState> states) {
      return states.contains(WidgetState.selected) ? onSurface : null;
    }

    return DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: surface,
      headerForegroundColor: onSurface,
      weekdayStyle: GoogleFonts.quicksand(color: onSurfaceMuted),
      dayForegroundColor: WidgetStateProperty.resolveWith(dayForeground),
      dayBackgroundColor: WidgetStateProperty.resolveWith(dayBackground),
      todayForegroundColor: WidgetStateProperty.resolveWith(dayForeground),
      todayBackgroundColor: WidgetStateProperty.resolveWith(dayBackground),
      todayBorder: const BorderSide(color: onSurface, width: 1),
      yearForegroundColor: WidgetStateProperty.resolveWith(dayForeground),
      yearBackgroundColor: WidgetStateProperty.resolveWith(dayBackground),
      dividerColor: const Color(0x33000000),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: GoogleFonts.quicksand(
        color: accent,
        fontSize: 44,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.quicksand(
        color: accent,
        fontSize: 30,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.quicksand(
        color: accent,
        fontSize: 23,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.quicksand(
        color: foreground,
        fontSize: 18,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.quicksand(
        color: foreground,
        fontSize: 18,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.quicksand(
        color: foreground,
        fontSize: 16,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.quicksand(color: muted, fontSize: 14, height: 1.4),
      labelLarge: GoogleFonts.quicksand(
        color: accent,
        fontSize: 14,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: GoogleFonts.quicksand(
        color: accent,
        fontSize: 11,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static InputDecorationTheme _pillInputDecorationTheme({
    required Color fillColor,
    required Color labelColor,
    required Color hintColor,
    required Color borderColor,
  }) {
    final radius = BorderRadius.circular(pillRadius);
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      labelStyle: GoogleFonts.quicksand(
        color: labelColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: GoogleFonts.quicksand(
        color: borderColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: GoogleFonts.quicksand(color: hintColor, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme() {
    return _pillInputDecorationTheme(
      fillColor: const Color(0x1AF8F6F0),
      labelColor: accent,
      hintColor: muted,
      borderColor: accent,
    );
  }

  static InputDecorationTheme onSurfaceInputDecorationTheme() {
    return _pillInputDecorationTheme(
      fillColor: fieldFill,
      labelColor: onSurfaceMuted,
      hintColor: onSurfaceMuted,
      borderColor: onSurface,
    );
  }

  static TextStyle _pillTextStyle() {
    return GoogleFonts.quicksand(
      fontSize: 15,
      letterSpacing: 0.3,
      fontWeight: FontWeight.w600,
    );
  }

  static ButtonStyle _filledButtonStyle() {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
      ),
      textStyle: WidgetStatePropertyAll(_pillTextStyle()),
      foregroundColor: const WidgetStatePropertyAll(onSurface),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return Colors.white;
        }
        return accent;
      }),
      overlayColor: const WidgetStatePropertyAll(Color(0x33FFFFFF)),
      side: const WidgetStatePropertyAll(BorderSide(color: accent, width: 2)),
    );
  }

  static ButtonStyle _outlineButtonStyle() {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
      ),
      textStyle: WidgetStatePropertyAll(_pillTextStyle()),
      foregroundColor: const WidgetStatePropertyAll(accent),
      side: const WidgetStatePropertyAll(BorderSide(color: accent, width: 1.5)),
      overlayColor: const WidgetStatePropertyAll(Color(0x22F8F6F0)),
    );
  }

  static ButtonStyle _textButtonStyle() {
    return ButtonStyle(
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      foregroundColor: const WidgetStatePropertyAll(accent),
    );
  }

  static ButtonStyle onSurfaceOutlineButtonStyle() {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
      ),
      textStyle: WidgetStatePropertyAll(_pillTextStyle()),
      foregroundColor: const WidgetStatePropertyAll(onSurface),
      side: const WidgetStatePropertyAll(
        BorderSide(color: onSurface, width: 1.5),
      ),
      overlayColor: const WidgetStatePropertyAll(Color(0x22000000)),
    );
  }

  static ButtonStyle onSurfaceTextButtonStyle() {
    return ButtonStyle(
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      foregroundColor: const WidgetStatePropertyAll(onSurface),
    );
  }
}
