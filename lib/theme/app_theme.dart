import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seed = Color(0xFF7C5CFF);
  static const Color _cyan = Color(0xFF24D6FF);
  static const Color _background = Color(0xFF050B16);
  static const Color _surface = Color(0xFF0B1424);
  static const Color _surfaceRaised = Color(0xFF111D31);

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    final colorScheme = base.copyWith(
      primary: _seed,
      secondary: _cyan,
      surface: _surface,
      surfaceContainer: _surface,
      surfaceContainerHigh: _surfaceRaised,
      surfaceContainerHighest: const Color(0xFF18253B),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      canvasColor: _background,
      appBarTheme: AppBarTheme(
        backgroundColor: _background.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.1,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: const Color(0xFF07101D),
        indicatorColor: _seed.withValues(alpha: 0.24),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            color: selected ? _cyan : const Color(0xFFA6B1C2),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? _cyan : const Color(0xFFA6B1C2),
          );
        }),
      ),
      searchBarTheme: const SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(_surfaceRaised),
        elevation: WidgetStatePropertyAll(0),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: Color(0xFF8E9AAF)),
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF182942), width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF20314B), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _cyan, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceRaised,
        selectedColor: _seed.withValues(alpha: 0.32),
        side: const BorderSide(color: Color(0xFF20314B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFA8B5C7),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF17243A),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF142239),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
