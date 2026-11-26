import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/operation_report.dart';
import '../viewmodels/operation_report_viewmodel.dart';

/// Formulario para registrar/actualizar el reporte de operación de un día.
class OperationReportFormView extends StatefulWidget {
  const OperationReportFormView({
    super.key,
    required this.codigoActivo,
    required this.nombreActivo,
    required this.areaId,
    required this.fecha,
    this.existing,
  });

  final String codigoActivo;
  final String nombreActivo;
  final String areaId;
  final DateTime fecha;
  final OperationReport? existing;

  @override
  State<OperationReportFormView> createState() => _OperationReportFormViewState();
}

class _OperationReportFormViewState extends State<OperationReportFormView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _jornada;
  late final TextEditingController _operacion;
  late final TextEditingController _paroFalla;
  late final TextEditingController _paroMP;
  late final TextEditingController _paroMC;
  late final TextEditingController _paroPlan;
  late final TextEditingController _paroExt;
  late final TextEditingController _obs;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _jornada   = TextEditingController(text: _fmt(e?.horasTotalesJornada ?? 24.0));
    _operacion = TextEditingController(text: _fmt(e?.horasOperacion       ?? 0.0));
    _paroFalla = TextEditingController(text: _fmt(e?.horasParoFalla       ?? 0.0));
    _paroMP    = TextEditingController(text: _fmt(e?.horasParoMantPrev    ?? 0.0));
    _paroMC    = TextEditingController(text: _fmt(e?.horasParoMantCorr    ?? 0.0));
    _paroPlan  = TextEditingController(text: _fmt(e?.horasParoPlanificado ?? 0.0));
    _paroExt   = TextEditingController(text: _fmt(e?.horasParoExterno     ?? 0.0));
    _obs       = TextEditingController(text: e?.observaciones ?? '');
  }

  String _fmt(double v) => v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in [_jornada, _operacion, _paroFalla, _paroMP, _paroMC, _paroPlan, _paroExt, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String v) => double.tryParse(v) ?? 0.0;

  double get _totalParos =>
      _parse(_paroFalla.text) + _parse(_paroMP.text) + _parse(_paroMC.text) +
      _parse(_paroPlan.text) + _parse(_paroExt.text);

  double get _totalUsado => _parse(_operacion.text) + _totalParos;
  double get _jornada_   => _parse(_jornada.text);

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<OperationReportViewModel>();

    final ok = await vm.guardarDia(
      codigoActivo:        widget.codigoActivo,
      fecha:               widget.fecha,
      horasTotalesJornada: _jornada_,
      horasOperacion:      _parse(_operacion.text),
      horasParoFalla:      _parse(_paroFalla.text),
      horasParoMantPrev:   _parse(_paroMP.text),
      horasParoMantCorr:   _parse(_paroMC.text),
      horasParoPlanificado:_parse(_paroPlan.text),
      horasParoExterno:    _parse(_paroExt.text),
      observaciones:       _obs.text.trim().isEmpty ? null : _obs.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte guardado correctamente.')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.saveError ?? 'Error al guardar el reporte.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _llenarJornadaCompleta() {
    setState(() {
      _jornada.text   = '24';
      _operacion.text = '24';
      _paroFalla.text = '0';
      _paroMP.text    = '0';
      _paroMC.text    = '0';
      _paroPlan.text  = '0';
      _paroExt.text   = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<OperationReportViewModel>();
    final theme  = Theme.of(context);
    final colors = theme.colorScheme;

    final isEdit  = widget.existing?.tieneReporte == true;
    final dispPct = _jornada_ > 0
        ? (_parse(_operacion.text) / _jornada_ * 100).clamp(0.0, 100.0)
        : 0.0;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Reporte' : 'Nuevo Reporte'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado: nombre del activo + fecha
                      Text(
                        widget.nombreActivo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFecha(widget.fecha),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botón para rellenar día normal
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _llenarJornadaCompleta,
                        child: const Text('Rellenar día normal (24 h operativas)'),
                      ),
                      const SizedBox(height: 20),

                      // Indicador de disponibilidad en tiempo real
                      _DispIndicator(pct: dispPct, colors: colors, theme: theme),
                      const SizedBox(height: 20),

                      // Jornada y Operación — 2 columnas
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _HoraField(
                              label: 'Horas jornada',
                              controller: _jornada,
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final h = double.tryParse(v ?? '');
                                if (h == null || h <= 0 || h > 24) return '0.1 a 24 h';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HoraField(
                              label: 'Horas de operación',
                              controller: _operacion,
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final h = double.tryParse(v ?? '');
                                if (h == null || h < 0) return 'No válido';
                                if (_totalUsado > _jornada_) return 'Excede jornada';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sección Paros
                      Text(
                        'Desglose de Paros (horas)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Fila 1
                      Row(
                        children: [
                          Expanded(
                            child: _HoraField(
                              label: 'Por falla / avería',
                              controller: _paroFalla,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HoraField(
                              label: 'Mant. preventivo',
                              controller: _paroMP,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fila 2
                      Row(
                        children: [
                          Expanded(
                            child: _HoraField(
                              label: 'Mant. correctivo',
                              controller: _paroMC,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HoraField(
                              label: 'Paro planificado',
                              controller: _paroPlan,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fila 3 — causa externa (ancho completo)
                      _HoraField(
                        label: 'Causa externa',
                        controller: _paroExt,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Resumen de horas
                      _HoursSummary(
                        jornada: _jornada_,
                        operacion: _parse(_operacion.text),
                        totalParos: _totalParos,
                        colors: colors,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),

                      // Observaciones
                      TextFormField(
                        controller: _obs,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Observaciones (opcional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botón guardar
                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: vm.saving ? null : _guardar,
                          icon: vm.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(isEdit ? 'Actualizar reporte' : 'Guardar reporte'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatFecha(DateTime d) {
    const dias  = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${dias[d.weekday - 1]}, ${d.day} ${meses[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

class _DispIndicator extends StatelessWidget {
  const _DispIndicator({
    required this.pct,
    required this.colors,
    required this.theme,
  });
  final double pct;
  final ColorScheme colors;
  final ThemeData theme;

  /// Color semántico usando solo el ColorScheme del tema:
  /// ≥ 85 % → primary (bueno)  |  ≥ 60 % → tertiary (alerta)  |  < 60 % → error (crítico)
  Color get _color {
    if (pct >= 85) return colors.primary;
    if (pct >= 60) return colors.tertiary;
    return colors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Disponibilidad del día',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct / 100,
          backgroundColor: _color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation<Color>(_color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _HoraField extends StatelessWidget {
  const _HoraField({
    required this.label,
    required this.controller,
    this.onChanged,
    this.validator,
  });
  final String label;
  final TextEditingController controller;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'h',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _HoursSummary extends StatelessWidget {
  const _HoursSummary({
    required this.jornada,
    required this.operacion,
    required this.totalParos,
    required this.colors,
    required this.theme,
  });
  final double jornada;
  final double operacion;
  final double totalParos;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final usado     = operacion + totalParos;
    final restante  = (jornada - usado).clamp(0.0, 24.0);
    final excede    = usado > jornada;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Jornada total',
            value: '${jornada.toStringAsFixed(1)} h',
            theme: theme,
            colors: colors,
          ),
          _SummaryRow(
            label: 'Horas registradas',
            value: '${usado.toStringAsFixed(1)} h',
            theme: theme,
            colors: colors,
            valueColor: excede ? colors.error : null,
          ),
          _SummaryRow(
            label: 'Sin contabilizar',
            value: '${restante.toStringAsFixed(1)} h',
            theme: theme,
            colors: colors,
            valueColor: restante > 0 ? colors.tertiary : colors.primary,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.colors,
    this.valueColor,
  });
  final String label;
  final String value;
  final ThemeData theme;
  final ColorScheme colors;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
