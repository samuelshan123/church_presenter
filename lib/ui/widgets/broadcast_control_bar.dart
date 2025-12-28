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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            icon: const Icon(Icons.arrow_back, size: 20),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.arrow_forward, size: 20),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 20),
            label: const Text('Clear'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
