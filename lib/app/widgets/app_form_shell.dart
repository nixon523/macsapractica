import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Envuelve un formulario con un ancho máximo cómodo y padding consistente.
///
/// - En desktop / web, centra el contenido y lo limita a `maxWidth`
///   (720 dp por defecto) para evitar formularios "oceánicos".
/// - En móvil ocupa el ancho disponible y aplica padding lateral estándar.
class AppFormShell extends StatelessWidget {
  const AppFormShell({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.centered = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final constrained = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    );

    return centered ? Center(child: constrained) : constrained;
  }
}
