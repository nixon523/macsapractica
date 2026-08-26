import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Tarjeta outlined consistente para toda la aplicación.
///
/// Reemplaza el patrón repetido:
/// ```
/// Card(
///   elevation: 0,
///   shape: RoundedRectangleBorder(
///     borderRadius: BorderRadius.circular(8),
///     side: BorderSide(color: Colors.grey.shade300),
///   ),
///   child: …,
/// )
/// ```
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius = AppRadius.allMd,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorder = borderColor ?? context.appColors.neutralBorder;
    final effectiveBg = backgroundColor ?? theme.colorScheme.surface;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: borderRadius,
        border: Border.all(color: effectiveBorder),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
