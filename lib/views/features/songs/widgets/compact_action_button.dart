import 'package:flutter/material.dart';

const BoxConstraints _compactActionConstraints = BoxConstraints(
  minWidth: 32,
  minHeight: 32,
);

/// Small icon-only action button used in list-row trailing widgets (song and
/// list edit/delete actions).
class CompactActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const CompactActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: _compactActionConstraints,
      padding: EdgeInsets.zero,
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 18),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
