import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xff111111),
    ),
    fontFamily: 'Jost',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 30,
        height: 1.2,
        letterSpacing: -.75,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(fontSize: 20, height: 1.2, letterSpacing: -.5),
      titleMedium: TextStyle(fontSize: 16, height: 1.4, letterSpacing: -.25),
      titleSmall: TextStyle(fontSize: 14, height: 1.4),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4, letterSpacing: -.25),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, height: 1.2, letterSpacing: -.1),
      labelLarge: TextStyle(fontSize: 14, height: 1.4),
      labelMedium: TextStyle(fontSize: 12, height: 1.2, letterSpacing: -.1),
      labelSmall: TextStyle(
        fontSize: 10,
        height: 1.2,
        letterSpacing: 1,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xfff4f4f5),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xff18181b),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
