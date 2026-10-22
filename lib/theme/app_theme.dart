import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// SLife design tokens, available through `context.colors`.
///
/// Warm neutral surfaces, one brand accent ([primary]), an emerald/gold pair
/// for the Deen section and a few status colors. Dark mode uses lifted
/// greys rather than pure black so cards stay distinct from the page.
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
    required this.emerald,
    required this.emeraldSoft,
    required this.gold,
    required this.shadow,
  });

  /// Page background.
  final Color paper;

  /// Raised surfaces (cards, sheets, bars).
  final Color card;

  /// Subtle fills (inputs, unselected chips, tracks).
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

  /// Deen section accent (Quran, tasbih).
  final Color emerald;
  final Color emeraldSoft;
  final Color gold;

  /// Soft drop shadow under cards (transparent in dark mode).
  final Color shadow;

  static const light = SLifeColors(
    paper: Color(0xFFF4F3EF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFEDEBE6),
    ink: Color(0xFF16151B),
    muted: Color(0xFF6B6975),
    line: Color(0xFFE6E3DC),
    primary: Color(0xFF5B4FE9),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFECE9FF),
    accent: Color(0xFFFF7A59),
    success: Color(0xFF16A06A),
    danger: Color(0xFFE5484D),
    emerald: Color(0xFF0E8F6E),
    emeraldSoft: Color(0xFFDDF3EA),
    gold: Color(0xFFB98522),
    shadow: Color(0x141B1530),
  );

  static const dark = SLifeColors(
    paper: Color(0xFF111015),
    card: Color(0xFF1D1C23),
    cardAlt: Color(0xFF28272F),
    ink: Color(0xFFF4F3F7),
    muted: Color(0xFFA3A0AE),
    line: Color(0xFF302E38),
    primary: Color(0xFF968DFF),
    onPrimary: Color(0xFF15122E),
    primarySoft: Color(0xFF2B2752),
    accent: Color(0xFFFF8E6E),
    success: Color(0xFF3DD68C),
    danger: Color(0xFFFF6B6B),
    emerald: Color(0xFF45D3A6),
    emeraldSoft: Color(0xFF143B31),
    gold: Color(0xFFE7BE63),
    shadow: Color(0x00000000),
  );

  /// Card shadow for [BoxDecoration.boxShadow].
  List<BoxShadow> get cardShadow => shadow.a == 0
      ? const []
      : [
          BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(
            color: shadow.withValues(alpha: shadow.a * 0.6),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ];

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
    Color? emerald,
    Color? emeraldSoft,
    Color? gold,
    Color? shadow,
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
      emerald: emerald ?? this.emerald,
      emeraldSoft: emeraldSoft ?? this.emeraldSoft,
      gold: gold ?? this.gold,
      shadow: shadow ?? this.shadow,
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
      emerald: mix(emerald, other.emerald),
      emeraldSoft: mix(emeraldSoft, other.emeraldSoft),
      gold: mix(gold, other.gold),
      shadow: mix(shadow, other.shadow),
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

  /// Typeface for Arabic text: Quran and dhikr (Amiri, bundled with the app
  /// so it works offline and never pops in late).
  static TextStyle arabic({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Amiri',
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
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: c.ink,
        height: 1.1,
        letterSpacing: -1.0,
      ),
      headlineMedium: font(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: c.ink,
        height: 1.15,
        letterSpacing: -0.9,
      ),
      headlineSmall: font(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: c.ink,
        height: 1.25,
        letterSpacing: -0.5,
      ),
      titleLarge: font(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: c.ink,
        letterSpacing: -0.3,
      ),
      titleMedium: font(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.ink,
        letterSpacing: -0.15,
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
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
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
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 3,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: text.labelLarge,
      ),
      iconTheme: IconThemeData(color: c.ink),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.cardAlt,
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: rounded16,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.card,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: c.line),
          shape: rounded16,
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.ink),
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
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.primarySoft,
        disabledColor: c.cardAlt,
        checkmarkColor: c.primary,
        deleteIconColor: c.muted,
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(fontSize: 14, color: c.ink),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          fontSize: 14,
          color: c.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        iconTheme: IconThemeData(color: c.muted, size: 18),
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
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.cardAlt,
        thumbColor: c.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.ink,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.muted),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.primarySoft,
        headerForegroundColor: c.primary,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.ink,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : null,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.primary,
        ),
        todayBorder: BorderSide(color: c.primary),
        yearForegroundColor: WidgetStatePropertyAll(c.ink),
        weekdayStyle: text.labelSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.card,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primarySoft : c.cardAlt,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.ink,
        ),
        dialBackgroundColor: c.cardAlt,
        dialHandColor: c.primary,
        dialTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.ink,
        ),
        dayPeriodColor: c.primarySoft,
        dayPeriodTextColor: c.ink,
        entryModeIconColor: c.muted,
        helpTextStyle: text.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        modalBackgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.line,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.cardAlt : c.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: text.bodySmall?.copyWith(
          color: isDark ? c.ink : Colors.white,
        ),
      ),
    );
  }
}
