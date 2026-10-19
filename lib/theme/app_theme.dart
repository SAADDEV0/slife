import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// SLife design tokens, available through `context.colors`.
///
/// The palette is intentionally small: neutral surfaces, one accent
/// ([primary]) and a few status colors.
@immutable
class SLifeColors extends ThemeExtension<SLifeColors> {
  const SLifeColors({
    required this.paper,
    required this.card,
    required this.cardAlt,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.success,
    required this.danger,
  });

  /// Page background.
  final Color paper;

  /// Raised surfaces (cards, sheets, bars).
  final Color card;

  /// Subtle fills (inputs, unselected chips).
  final Color cardAlt;
  final Color ink;
  final Color muted;
  final Color line;
  final Color primary;

  /// Text and icons drawn on [primary].
  final Color onPrimary;

  /// Tinted background for selected / tonal elements.
  final Color primarySoft;

  /// Warm highlight, used sparingly (streaks).
  final Color accent;
  final Color success;
  final Color danger;

  static const light = SLifeColors(
    paper: Color(0xFFF6F6F8),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF0F0F3),
    ink: Color(0xFF16161A),
    muted: Color(0xFF6E6E78),
    line: Color(0xFFE6E6EB),
    primary: Color(0xFF5B4FE9),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEDEBFE),
    accent: Color(0xFFFF7A59),
    success: Color(0xFF1F9D63),
    danger: Color(0xFFE5484D),
  );

  static const dark = SLifeColors(
    paper: Color(0xFF0E0E11),
    card: Color(0xFF18181D),
    cardAlt: Color(0xFF222228),
    ink: Color(0xFFF2F2F5),
    muted: Color(0xFF9C9CA8),
    line: Color(0xFF2A2A31),
    primary: Color(0xFF8E85FF),
    onPrimary: Color(0xFF14112B),
    primarySoft: Color(0xFF26234A),
    accent: Color(0xFFFF8E6E),
    success: Color(0xFF3DD68C),
    danger: Color(0xFFFF6B6B),
  );

  @override
  SLifeColors copyWith({
    Color? paper,
    Color? card,
    Color? cardAlt,
    Color? ink,
    Color? muted,
    Color? line,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? accent,
    Color? success,
    Color? danger,
  }) {
    return SLifeColors(
      paper: paper ?? this.paper,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  SLifeColors lerp(SLifeColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return SLifeColors(
      paper: mix(paper, other.paper),
      card: mix(card, other.card),
      cardAlt: mix(cardAlt, other.cardAlt),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primarySoft: mix(primarySoft, other.primarySoft),
      accent: mix(accent, other.accent),
      success: mix(success, other.success),
      danger: mix(danger, other.danger),
    );
  }
}

extension SLifeThemeContext on BuildContext {
  SLifeColors get colors => Theme.of(this).extension<SLifeColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  AppTheme._();

  /// Tests switch this off so no fonts are fetched over the network.
  static bool useGoogleFonts = true;

  /// The single UI typeface (Inter).
  static TextStyle font({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    if (!useGoogleFonts) {
      return TextStyle(
        fontFamily: 'SLifeSans',
        fontFamilyFallback: const ['SLifeEmoji'],
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Typeface for Arabic text: Quran and dhikr (Amiri).
  static TextStyle arabic({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) {
    if (!useGoogleFonts) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
    return GoogleFonts.amiri(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static ThemeData light() => _build(Brightness.light, SLifeColors.light);
  static ThemeData dark() => _build(Brightness.dark, SLifeColors.dark);

  static ThemeData _build(Brightness brightness, SLifeColors c) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: brightness,
        ).copyWith(
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryContainer: c.primarySoft,
          onPrimaryContainer: c.primary,
          secondary: c.primary,
          onSecondary: c.onPrimary,
          secondaryContainer: c.primarySoft,
          onSecondaryContainer: c.primary,
          tertiary: c.accent,
          surface: c.card,
          onSurface: c.ink,
          onSurfaceVariant: c.muted,
          surfaceContainerLowest: c.card,
          surfaceContainerLow: c.card,
          surfaceContainer: c.card,
          surfaceContainerHigh: c.card,
          surfaceContainerHighest: c.cardAlt,
          outline: c.line,
          outlineVariant: c.line,
          error: c.danger,
          surfaceTint: Colors.transparent,
        );

    final text = TextTheme(
      displaySmall: font(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: c.ink,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      headlineMedium: font(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: c.ink,
        height: 1.2,
        letterSpacing: -0.6,
      ),
      headlineSmall: font(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: c.ink,
        height: 1.25,
        letterSpacing: -0.4,
      ),
      titleLarge: font(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: c.ink,
        letterSpacing: -0.2,
      ),
      titleMedium: font(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.ink,
        letterSpacing: -0.1,
      ),
      titleSmall: font(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink),
      bodyLarge: font(fontSize: 16.5, color: c.ink, height: 1.6),
      bodyMedium: font(fontSize: 14.5, color: c.ink, height: 1.45),
      bodySmall: font(fontSize: 13, color: c.muted, height: 1.35),
      labelLarge: font(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink),
      labelMedium: font(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: c.muted,
      ),
      labelSmall: font(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.muted,
        letterSpacing: 0.2,
      ),
    );

    final overlay =
        (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
            );
    final rounded14 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      textTheme: text,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: c.ink),
        actionsIconTheme: IconThemeData(color: c.ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => font(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.ink : c.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? c.primary : c.muted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: text.labelLarge,
      ),
      iconTheme: IconThemeData(color: c.ink),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.cardAlt,
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.22),
        selectionHandleColor: c.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: rounded14,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: c.line),
          shape: rounded14,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(0, 44),
          shape: rounded14,
          textStyle: text.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          textStyle: WidgetStatePropertyAll(
            text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primarySoft : c.card,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.ink,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c.line)),
          shape: WidgetStatePropertyAll(rounded14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.cardAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.line,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        titleTextStyle: text.bodyLarge?.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? c.cardAlt : c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: isDark ? c.ink : Colors.white,
        ),
        actionTextColor: isDark ? c.primary : const Color(0xFFB7B0FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.line),
        ),
        textStyle: text.bodyMedium,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: c.primary,
        textColor: c.onPrimary,
        textStyle: font(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.primarySoft,
        circularTrackColor: c.primarySoft,
      ),
    );
  }
}
