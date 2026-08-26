import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Diálogo con ancho responsivo.
///
/// - En pantallas anchas usa `maxWidth` (por defecto 560 dp).
/// - En pantallas estrechas usa el 92 % del ancho disponible.
///
/// Reemplaza al patrón `AlertDialog(content: SizedBox(width: 400, …))` que
/// desborda en móvil.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.icon,
    required this.content,
    this.actions,
    this.maxWidth = 560,
    this.scrollable = true,
    this.contentPadding,
  });

  final Widget? title;
  final Widget? icon;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(screenWidth * 0.92, maxWidth);

    final child = scrollable
        ? SingleChildScrollView(child: content)
        : content;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.allLg),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: contentPadding ?? const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null || title != null) ...[
                Row(
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: AppSpacing.md),
                    ],
                    if (title != null)
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: Theme.of(context).textTheme.titleLarge,
                          child: title!,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Flexible(child: child),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _ActionsBar(actions: actions!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Helper para invocar como reemplazo directo de `showDialog(builder: (_) => AlertDialog(...))`.
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    Widget? icon,
    required Widget content,
    List<Widget>? actions,
    double maxWidth = 560,
    bool scrollable = true,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog(
        title: title,
        icon: icon,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
        scrollable: scrollable,
      ),
    );
  }
}

/// Calcula un ancho responsivo para diálogos y contenido.
///
/// - Nunca excede [maxWidth].
/// - En pantallas estrechas nunca supera el 90 % del ancho disponible,
///   evitando que el contenido desborde.
///
/// Usa esto en lugar de `SizedBox(width: 400)` dentro de diálogos.
double responsiveDialogWidth(BuildContext context, double maxWidth) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  return math.min(screenWidth * 0.9, maxWidth);
}

/// Distribuye los botones de acción: en móvil los apila, en desktop los alinea a la derecha.
class _ActionsBar extends StatelessWidget {
  const _ActionsBar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cuando el diálogo es muy estrecho, apila las acciones verticalmente.
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                actions[i],
              ],
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              actions[i],
            ],
          ],
        );
      },
    );
  }
}
