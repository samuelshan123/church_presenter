import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// The payload type of a `HugeIcons.strokeRounded*` constant.
///
/// Hugeicons ships icons as SVG element descriptors rather than font
/// codepoints, so this replaces [IconData] wherever an icon is stored in a
/// field or passed as a parameter.
typedef HugeIconData = List<List<dynamic>>;

/// Drop-in replacement for [Icon] that renders a Hugeicons stroke-rounded glyph.
///
/// [HugeIcon] bakes its colour into the generated SVG string and ignores the
/// ambient [IconTheme], which would silently break every icon that relies on
/// its parent for colour (`IconButton`, `ListTile.leading`, `Tab`, chips, ...).
/// This widget resolves colour, size and opacity from [IconTheme] the same way
/// [Icon] does, so call sites keep working unchanged after the migration.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth,
    this.semanticLabel,
  });

  /// A `HugeIcons.strokeRounded*` constant.
  final HugeIconData icon;

  final double? size;
  final Color? color;
  final double? strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24.0;

    var resolvedColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    final opacity = iconTheme.opacity ?? 1.0;
    if (opacity != 1.0) {
      resolvedColor = resolvedColor.withValues(
        alpha: resolvedColor.a * opacity,
      );
    }

    Widget result = HugeIcon(
      icon: icon,
      color: resolvedColor,
      size: resolvedSize,
      strokeWidth: strokeWidth,
    );

    if (semanticLabel != null) {
      result = Semantics(
        label: semanticLabel,
        child: ExcludeSemantics(child: result),
      );
    }

    return result;
  }
}
