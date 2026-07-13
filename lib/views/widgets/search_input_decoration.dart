import 'package:flutter/material.dart';

/// Shared borderless pill-style decoration for search boxes (Bible index,
/// book selector, web song search) — kept visually distinct from regular
/// form fields, which use the app's default outlined [InputDecorationTheme].
InputDecoration searchInputDecoration({
  required String hintText,
  required bool hasValue,
  required VoidCallback onClear,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: const Icon(Icons.search),
    suffixIcon: hasValue
        ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
        : null,
    isDense: true,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
  );
}
