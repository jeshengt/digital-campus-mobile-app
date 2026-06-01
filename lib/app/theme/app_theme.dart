import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light =>
      _buildTheme(brightness: Brightness.light, colors: UtmThemeColors.light);

  static ThemeData get dark =>
      _buildTheme(brightness: Brightness.dark, colors: UtmThemeColors.dark);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required UtmThemeColors colors,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.utmMaroon,
      brightness: brightness,
      primary: colors.brandMaroon,
      secondary: colors.brandGold,
      surface: colors.surface,
      error: colors.error,
    );

    final baseTextTheme = _textTheme(colors);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      visualDensity: VisualDensity.standard,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.brandMaroon,
        scaffoldBackgroundColor: colors.background,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(color: colors.textPrimary),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.glass,
          fixedSize: const Size.square(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            side: BorderSide(color: colors.glassBorder),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.glassStrong,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brandMaroon,
          foregroundColor: colors.onBrand,
          disabledBackgroundColor: colors.mutedSurface,
          disabledForegroundColor: colors.textTertiary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brandMaroon,
          foregroundColor: colors.onBrand,
          disabledBackgroundColor: colors.mutedSurface,
          disabledForegroundColor: colors.textTertiary,
          minimumSize: const Size(76, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.brandMaroon,
          side: BorderSide(color: colors.glassBorder),
          minimumSize: const Size(72, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.brandMaroon,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.glass,
        prefixIconColor: colors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMedium,
          vertical: AppDimensions.spacingMedium,
        ),
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: colors.brandMaroon,
          fontWeight: FontWeight.w700,
        ),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: colors.brandMaroon, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: colors.error),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.glassBorder,
        thickness: 1,
        space: 1,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.glass,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        showDragHandle: true,
        dragHandleColor: colors.textTertiary.withValues(alpha: 0.38),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusExtraLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? colors.glassStrong : colors.textPrimary,
        contentTextStyle: TextStyle(
          color: isDark ? colors.textPrimary : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          side: BorderSide(
            color: isDark ? colors.glassBorder : Colors.transparent,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.onBrand;
          }
          return colors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.brandMaroon;
          }
          return colors.mutedSurface;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.brandMaroon,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.brandMaroon,
        selectionColor: colors.brandMaroon.withValues(alpha: 0.18),
        selectionHandleColor: colors.brandMaroon,
      ),
      textTheme: baseTextTheme,
    );
  }

  static TextTheme _textTheme(UtmThemeColors colors) {
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.12,
        color: colors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.18,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.24,
        color: colors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.45,
        letterSpacing: 0,
        color: colors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        letterSpacing: 0,
        color: colors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.35,
        letterSpacing: 0,
        color: colors.textTertiary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: colors.textPrimary,
      ),
    );
  }
}

@immutable
class UtmThemeColors extends ThemeExtension<UtmThemeColors> {
  const UtmThemeColors({
    required this.brandMaroon,
    required this.brandMaroonSoft,
    required this.brandGold,
    required this.brandGoldSoft,
    required this.onBrand,
    required this.background,
    required this.surface,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.mutedSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.shadow,
    required this.success,
    required this.warning,
    required this.error,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.onHeroMuted,
  });

  final Color brandMaroon;
  final Color brandMaroonSoft;
  final Color brandGold;
  final Color brandGoldSoft;
  final Color onBrand;
  final Color background;
  final Color surface;
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;
  final Color mutedSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color shadow;
  final Color success;
  final Color warning;
  final Color error;
  final Color heroStart;
  final Color heroEnd;
  final Color onHero;
  final Color onHeroMuted;

  static const light = UtmThemeColors(
    brandMaroon: AppColors.utmMaroon,
    brandMaroonSoft: AppColors.utmMaroonTint,
    brandGold: AppColors.utmGold,
    brandGoldSoft: AppColors.utmGoldTint,
    onBrand: Colors.white,
    background: Color(0xFFF4F4F6),
    surface: Colors.white,
    glass: Color(0xA6FFFFFF),
    glassStrong: Color(0xD9FFFFFF),
    glassBorder: Color(0xAAD7DADE),
    mutedSurface: Color(0xFFEDEEF2),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF5D626B),
    textTertiary: Color(0xFF818792),
    shadow: Color(0x24241418),
    success: Color(0xFF167A45),
    warning: Color(0xFF9A6700),
    error: Color(0xFFB3261E),
    heroStart: Color(0xF2FFFFFF),
    heroEnd: Color(0xFFFFF6F0),
    onHero: Color(0xFF1D1D1F),
    onHeroMuted: Color(0xFF5D626B),
  );

  static const dark = UtmThemeColors(
    brandMaroon: Color(0xFFFF8A8A),
    brandMaroonSoft: Color(0xFF33181A),
    brandGold: Color(0xFFE3C366),
    brandGoldSoft: Color(0xFF302814),
    onBrand: Color(0xFF1B0B0C),
    background: Color(0xFF07080B),
    surface: Color(0xFF14161D),
    glass: Color(0x941A1C24),
    glassStrong: Color(0xC21F222B),
    glassBorder: Color(0x42FFFFFF),
    mutedSurface: Color(0xFF242733),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFC3C7D0),
    textTertiary: Color(0xFF8E95A3),
    shadow: Color(0x7A000000),
    success: Color(0xFF70D79A),
    warning: Color(0xFFE3C366),
    error: Color(0xFFFF8F86),
    heroStart: Color(0xD92A2D38),
    heroEnd: Color(0xD92B1518),
    onHero: Color(0xFFF5F5F7),
    onHeroMuted: Color(0xFFC3C7D0),
  );

  static UtmThemeColors of(BuildContext context) {
    return Theme.of(context).extension<UtmThemeColors>()!;
  }

  @override
  UtmThemeColors copyWith({
    Color? brandMaroon,
    Color? brandMaroonSoft,
    Color? brandGold,
    Color? brandGoldSoft,
    Color? onBrand,
    Color? background,
    Color? surface,
    Color? glass,
    Color? glassStrong,
    Color? glassBorder,
    Color? mutedSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? shadow,
    Color? success,
    Color? warning,
    Color? error,
    Color? heroStart,
    Color? heroEnd,
    Color? onHero,
    Color? onHeroMuted,
  }) {
    return UtmThemeColors(
      brandMaroon: brandMaroon ?? this.brandMaroon,
      brandMaroonSoft: brandMaroonSoft ?? this.brandMaroonSoft,
      brandGold: brandGold ?? this.brandGold,
      brandGoldSoft: brandGoldSoft ?? this.brandGoldSoft,
      onBrand: onBrand ?? this.onBrand,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      glass: glass ?? this.glass,
      glassStrong: glassStrong ?? this.glassStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      shadow: shadow ?? this.shadow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      onHero: onHero ?? this.onHero,
      onHeroMuted: onHeroMuted ?? this.onHeroMuted,
    );
  }

  @override
  UtmThemeColors lerp(ThemeExtension<UtmThemeColors>? other, double t) {
    if (other is! UtmThemeColors) {
      return this;
    }

    return UtmThemeColors(
      brandMaroon: Color.lerp(brandMaroon, other.brandMaroon, t)!,
      brandMaroonSoft: Color.lerp(brandMaroonSoft, other.brandMaroonSoft, t)!,
      brandGold: Color.lerp(brandGold, other.brandGold, t)!,
      brandGoldSoft: Color.lerp(brandGoldSoft, other.brandGoldSoft, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      onHeroMuted: Color.lerp(onHeroMuted, other.onHeroMuted, t)!,
    );
  }
}
