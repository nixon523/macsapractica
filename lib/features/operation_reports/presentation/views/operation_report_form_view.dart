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
        const SnackBar(
          content: Text('Reporte guardado correctamente.'),
          backgroundColor: Color(0xFF2ECC71),
        ),
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
      _jornada.text = '24';
      _operacion.text = '24';
      _paroFalla.text = '0';
      _paroMP.text = '0';
      _paroMC.text = '0';
      _paroPlan.text = '0';
      _paroExt.text = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm    = context.watch<OperationReportViewModel>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isEdit = widget.existing?.tieneReporte == true;
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
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.precision_manufacturing, color: colors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.nombreActivo,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fecha: ${_formatFecha(widget.fecha)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0288D1),
                                  side: const BorderSide(color: Color(0xFF0288D1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.flash_on, size: 18),
                                label: const Text('Rellenar Día Normal (24h Operativas / 0 Paros)'),
                                onPressed: _llenarJornadaCompleta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Indicador de disponibilidad en tiempo real
                      _DispIndicator(pct: dispPct),
                      const SizedBox(height: 18),

                      // Jornada y Operación en 2 columnas
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _HoraField(
                              label: 'Horas jornada',
                              icon: Icons.schedule,
                              controller: _jornada,
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final h = double.tryParse(v ?? '');
                                if (h == null || h <= 0 || h > 24) return '0.1 a 24h';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HoraField(
                              label: 'Horas de operación',
                              icon: Icons.play_circle_outline,
                              controller: _operacion,
                              color: const Color(0xFF2ECC71),
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
                      const SizedBox(height: 18),

                      // Sección Paros
                      Row(
                        children: [
                          Icon(Icons.pause_circle_outline, size: 18, color: colors.onSurface.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Text(
                            'Desglose de Paros (horas)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fila 1 de paros
                      Row(
                        children: [
                          Expanded(
                            child: _HoraField(
                              label: 'Por falla / avería',
                              icon: Icons.warning_amber_rounded,
                              controller: _paroFalla,
                              color: const Color(0xFFE74C3C),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HoraField(
                              label: 'Mant. preventivo',
                              icon: Icons.build_circle_outlined,
                              controller: _paroMP,
                              color: const Color(0xFF3498DB),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fila 2 de paros
                      Row(
                        children: [
                          Expanded(
                            child: _HoraField(
                              label: 'Mant. correctivo',
                              icon: Icons.build_outlined,
                              controller: _paroMC,
                              color: const Color(0xFF9B59B6),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HoraField(
                              label: 'Paro planificado',
                              icon: Icons.event_available,
                              controller: _paroPlan,
                              color: const Color(0xFFF39C12),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fila 3 de paros
                      _HoraField(
                        label: 'Causa externa',
                        icon: Icons.logout_outlined,
                        controller: _paroExt,
                        color: const Color(0xFF95A5A6),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Resumen de horas
                      _HoursSummary(
                        jornada: _jornada_,
                        operacion: _parse(_operacion.text),
                        totalParos: _totalParos,
                      ),
                      const SizedBox(height: 16),

                      // Observaciones
                      TextFormField(
                        controller: _obs,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Observaciones (opcional)',
                          prefixIcon: const Icon(Icons.notes),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${dias[d.weekday - 1]}, ${d.day} ${meses[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------
class _DispIndicator extends StatelessWidget {
  const _DispIndicator({required this.pct});
  final double pct;

  Color get _color {
    if (pct >= 85) return const Color(0xFF2ECC71);
    if (pct >= 60) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Disponibilidad del día',
                style: Theme.of(context).textTheme.titleSmall),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: _color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct / 100,
          backgroundColor: _color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation<Color>(_color),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }
}

class _HoraField extends StatelessWidget {
  const _HoraField({
    required this.label,
    required this.icon,
    required this.controller,
    this.color,
    this.onChanged,
    this.validator,
  });
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final Color? color;
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
        prefixIcon: Icon(icon, color: color),
        suffixText: 'h',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
  });
  final double jornada;
  final double operacion;
  final double totalParos;

  @override
  Widget build(BuildContext context) {
    final usado = operacion + totalParos;
    final restante = (jornada - usado).clamp(0.0, 24.0);
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _Row('Jornada total',    '${jornada.toStringAsFixed(1)} h', null),
          _Row('Horas registradas', '${usado.toStringAsFixed(1)} h',
              usado > jornada ? const Color(0xFFE74C3C) : null),
          _Row('Sin contabilizar', '${restante.toStringAsFixed(1)} h',
              restante > 0 ? const Color(0xFFF39C12) : const Color(0xFF2ECC71)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
