import 'package:flutter/material.dart';

class GridCardWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool compact;

  const GridCardWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = iconColor ?? colorScheme.primary;

    final double borderRadius = compact ? 22 : 26;
    final double padding = compact ? 16 : 20;
    final double iconSize = compact ? 26 : 30;
    final double iconBoxSize = compact ? 52 : 60;

    final TextStyle? titleStyle = (compact
            ? theme.textTheme.titleMedium
            : theme.textTheme.titleLarge)
        ?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.15,
          letterSpacing: 0.2,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      colorScheme.surfaceContainerHighest,
                      colorScheme.surfaceContainer,
                      colorScheme.surface,
                    ]
                  : [
                      Colors.white,
                      colorScheme.surface,
                      colorScheme.surfaceContainerLow,
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : accentColor.withValues(alpha: 0.10),
                blurRadius: compact ? 16 : 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -12,
                  child: Container(
                    height: compact ? 84 : 100,
                    width: compact ? 84 : 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accentColor.withValues(alpha: isDark ? 0.18 : 0.14),
                          accentColor.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -26,
                  left: -14,
                  child: Container(
                    height: compact ? 64 : 78,
                    width: compact ? 64 : 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: iconBoxSize,
                        width: iconBoxSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withValues(alpha: 0.20),
                              accentColor.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: iconSize,
                          color: accentColor,
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 12,
                              vertical: compact ? 5 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "Open",
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: compact ? 18 : 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}