import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminPalette {
  static const background = Color(0xFFF2E8DA);
  static const surface = Colors.white;
  static const primary = Color(0xFF9C5A1A);
  static const primaryDark = Color(0xFF2D241A);
  static const border = Color(0xFFEADBC9);
  static const muted = Color(0xFF6B6257);
}

TextStyle adminSora({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return GoogleFonts.sora(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

TextStyle adminJakarta({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  TextDecoration? decoration,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    decoration: decoration,
  );
}
