import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const tabularFigures = [FontFeature.tabularFigures()];
  static const pagePadding = EdgeInsets.fromLTRB(20, 8, 20, 24);

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF1C1E1F) : const Color(0xFFF7F5F0);
    final surface = dark ? const Color(0xFF242728) : Colors.white;
    final text = dark ? const Color(0xFFF0F0EB) : const Color(0xFF242623);
    final secondary = dark ? const Color(0xFFBFC1BA) : const Color(0xFF575A55);
    final primary = dark ? const Color(0xFFA8CBE4) : const Color(0xFF294C65);
    final selection = dark ? const Color(0xFF2C3B46) : const Color(0xFFEBF0F4);
    final neutral = dark ? const Color(0xFF333636) : const Color(0xFFF1F0EC);
    final line = dark ? const Color(0xFF404444) : const Color(0xFFDFE0DA);
    final outline = dark ? const Color(0xFF9A9E98) : const Color(0xFF80847E);

    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF294C65),
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: dark ? const Color(0xFF142C3D) : Colors.white,
          primaryContainer: selection,
          onPrimaryContainer: primary,
          secondaryContainer: selection,
          onSecondaryContainer: primary,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: secondary,
          surfaceContainerLow: neutral,
          surfaceContainerHigh: neutral,
          surfaceContainerHighest: neutral,
          outline: outline,
          outlineVariant: line,
        );
    // Let Flutter choose the platform font; only adjust the typographic scale.
    final theme = ThemeData(useMaterial3: true, colorScheme: colors);
    final type = theme.textTheme.apply(bodyColor: text, displayColor: text);
    final control = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: outline),
    );

    return theme.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: type.copyWith(
        headlineMedium: type.headlineMedium?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineSmall: type.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleLarge: type.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: type.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyMedium: type.bodyMedium?.copyWith(fontSize: 16, letterSpacing: 0),
        bodySmall: type.bodySmall?.copyWith(
          fontSize: 13,
          color: secondary,
          letterSpacing: 0,
        ),
        labelLarge: type.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: background,
        foregroundColor: text,
        scrolledUnderElevation: 0,
        titleTextStyle: type.titleLarge?.copyWith(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: line),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: control,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: control,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: control,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: selection,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => type.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primary : secondary,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  static Color attention(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF1CF99)
      : const Color(0xFF76501F);

  static Color attentionBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF403426)
      : const Color(0xFFF7EEE0);
}
