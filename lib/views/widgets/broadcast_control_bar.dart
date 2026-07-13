import 'package:flutter/material.dart';

/// A control bar with Previous, Next, and Clear buttons for broadcast navigation
class BroadcastControlBar extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClear;
  final bool hasPrevious;
  final bool hasNext;

  const BroadcastControlBar({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.onClear,
    this.hasPrevious = true,
    this.hasNext = true,
  });

  @override
  Widget build(BuildContext context) {
    const buttonPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    const labelStyle = TextStyle(fontSize: 13);
    const iconSize = 16.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: hasPrevious ? onPrevious : null,
            icon: const Icon(Icons.arrow_back, size: iconSize),
            label: const Text('Prev', style: labelStyle),
            style: ElevatedButton.styleFrom(
              padding: buttonPadding,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.arrow_forward, size: iconSize),
            label: const Text('Next', style: labelStyle),
            style: ElevatedButton.styleFrom(
              padding: buttonPadding,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: iconSize),
            label: const Text('Clear', style: labelStyle),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: buttonPadding,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
