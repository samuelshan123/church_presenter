import 'package:flutter/material.dart';

/// Border used across the Bible screens to highlight a selected item
/// (verse tile, chapter/verse grid cell, color/template swatch): a thicker
/// primary-colored border when selected, a thin neutral one otherwise.
Border selectionBorder(
  BuildContext context, {
  required bool isSelected,
  double selectedWidth = 2,
  double unselectedWidth = 1.5,
  Color? unselectedColor,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Border.all(
    color: isSelected
        ? colorScheme.primary
        : (unselectedColor ?? colorScheme.outlineVariant),
    width: isSelected ? selectedWidth : unselectedWidth,
  );
}
