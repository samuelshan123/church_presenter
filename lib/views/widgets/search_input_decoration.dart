import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'app_icon.dart';

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
    prefixIcon: Padding(
      padding: const EdgeInsets.all(14.0),
      child: AppIcon(HugeIcons.strokeRoundedSearch01),
    ),
    suffixIcon: hasValue
        ? IconButton(
            icon: AppIcon(HugeIcons.strokeRoundedCancel01),
            onPressed: onClear,
          )
        : null,
    isDense: true,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
  );
}
