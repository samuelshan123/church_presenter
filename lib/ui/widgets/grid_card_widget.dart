import 'package:flutter/material.dart';

class GridCardWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool compact;

  const GridCardWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = iconColor ?? theme.colorScheme.primary;
    final titleStyle = compact
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleLarge;
    final subtitleStyle = compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 2 : 6,
      shadowColor: accentColor.withValues(alpha: isDark ? 0.12 : 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      theme.colorScheme.surfaceContainerHighest,
                      theme.colorScheme.surfaceContainer,
                    ]
                  : [
                      theme.colorScheme.surface,
                      theme.colorScheme.surfaceContainerLow,
                    ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -22,
                right: -18,
                child: Container(
                  height: compact ? 72 : 88,
                  width: compact ? 72 : 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: isDark ? 0.12 : 0.10),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 16 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(compact ? 14 : 16),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: compact ? 28 : 32,
                        color: accentColor,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    Text(
                      title,
                      style: titleStyle?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: subtitleStyle?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.66,
                          ),
                          height: 1.35,
                        ),
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          'Open',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: accentColor,
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
    );
  }
}
