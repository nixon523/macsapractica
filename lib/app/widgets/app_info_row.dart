import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Fila etiqueta / valor que se adapta al ancho disponible.
///
/// - Con ancho suficiente (>= [breakpoint]): dibuja una `Row` con el label a la
///   izquierda (ancho fijo [labelWidth]) y el valor en `Expanded`.
/// - Con ancho menor: apila label sobre valor (Column), evitando que el valor
///   quede recortado en móvil.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 140,
    this.breakpoint = 420,
    this.labelStyle,
    this.valueStyle,
    this.spacing = AppSpacing.sm,
  });

  final String label;
  final Widget value;
  final double labelWidth;
  final double breakpoint;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabelStyle = labelStyle ??
        theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    final labelWidget = Text(label, style: effectiveLabelStyle);
    final valueWidget = DefaultTextStyle.merge(
      style: valueStyle ?? theme.textTheme.bodyMedium,
      child: value,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                SizedBox(height: spacing / 2),
                valueWidget,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: labelWidth, child: labelWidget),
              SizedBox(width: spacing),
              Expanded(child: valueWidget),
            ],
          ),
        );
      },
    );
  }
}
