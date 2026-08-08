import 'package:flutter/material.dart';

abstract final class NexBookTheme {
  static const primary = Color(0xff155eef);
  static const secondary = Color(0xff007f73);
  static const tertiary = Color(0xffb4235a);

  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xffdbe7ff),
        onPrimaryContainer: const Color(0xff082b69),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xffc4f2ea),
        onSecondaryContainer: const Color(0xff003c36),
        tertiary: tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xffffd9e3),
        onTertiaryContainer: const Color(0xff6f0833),
        surface: const Color(0xfffbfcff),
        onSurface: const Color(0xff171a21),
        onSurfaceVariant: const Color(0xff555b66),
        surfaceContainerLowest: const Color(0xffffffff),
        surfaceContainerLow: const Color(0xffeef4ff),
        surfaceContainer: const Color(0xffe3ecfc),
        surfaceContainerHigh: const Color(0xffd8e4f7),
        surfaceContainerHighest: const Color(0xffcbd9f0),
        outline: const Color(0xff69758a),
        outlineVariant: const Color(0xffc2d0e7),
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: const Color(0xffadc6ff),
        onPrimary: const Color(0xff003587),
        primaryContainer: const Color(0xff174aaf),
        onPrimaryContainer: const Color(0xffdbe7ff),
        secondary: const Color(0xff78d8cc),
        onSecondary: const Color(0xff003732),
        secondaryContainer: const Color(0xff005047),
        onSecondaryContainer: const Color(0xff9cf5e9),
        tertiary: const Color(0xffffb0c8),
        onTertiary: const Color(0xff68002c),
        tertiaryContainer: const Color(0xff8f1744),
        onTertiaryContainer: const Color(0xffffd9e3),
        surface: const Color(0xff151b25),
        onSurface: const Color(0xfff0f1f5),
        onSurfaceVariant: const Color(0xffc4c7d0),
        surfaceContainerLowest: const Color(0xff090e16),
        surfaceContainerLow: const Color(0xff0e1623),
        surfaceContainer: const Color(0xff172235),
        surfaceContainerHigh: const Color(0xff202d40),
        surfaceContainerHighest: const Color(0xff2b3a4f),
        outline: const Color(0xff95a0b2),
        outlineVariant: const Color(0xff41516a),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color secondary,
    required Color onSecondary,
    required Color secondaryContainer,
    required Color onSecondaryContainer,
    required Color tertiary,
    required Color onTertiary,
    required Color tertiaryContainer,
    required Color onTertiaryContainer,
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color surfaceContainerLowest,
    required Color surfaceContainerLow,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
    required Color outline,
    required Color outlineVariant,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final textTheme = base.textTheme.copyWith(
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: onSurfaceVariant,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
    final rounded8 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final appBarBackground =
        brightness == Brightness.light ? primary : primaryContainer;
    final appBarForeground =
        brightness == Brightness.light ? onPrimary : onPrimaryContainer;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: outlineVariant),
    );

    return base.copyWith(
      scaffoldBackgroundColor: surfaceContainerLow,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: appBarForeground),
        actionsIconTheme: IconThemeData(color: appBarForeground),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: appBarForeground,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 4,
        shadowColor: const Color(0x33000000),
        backgroundColor: surface,
        indicatorColor: primary,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? primary
                : onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 25,
            color: states.contains(WidgetState.selected)
                ? onPrimary
                : onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: onSurfaceVariant, letterSpacing: 0),
        floatingLabelStyle: TextStyle(color: primary, letterSpacing: 0),
        helperStyle: textTheme.bodySmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: rounded8,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: outlineVariant),
          shape: rounded8,
          foregroundColor: primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: rounded8,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          foregroundColor: onSurfaceVariant,
          shape: rounded8,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: rounded8,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(BorderSide(color: outlineVariant)),
        shape: WidgetStatePropertyAll(rounded8),
        textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyMedium!.copyWith(color: onSurfaceVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: secondary,
        textColor: onSurface,
        subtitleTextStyle:
            textTheme.bodyMedium!.copyWith(color: onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: rounded8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? onPrimary
              : onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 24,
      ),
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 4,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded8,
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        backgroundColor: brightness == Brightness.light
            ? const Color(0xff20242c)
            : const Color(0xffe7e9ef),
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: brightness == Brightness.light
              ? Colors.white
              : const Color(0xff17191e),
        ),
        shape: rounded8,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primaryContainer,
        circularTrackColor: primaryContainer,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: onSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: textTheme.bodySmall!.copyWith(color: surface),
      ),
    );
  }
}
