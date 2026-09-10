import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/operation_report.dart';
import '../viewmodels/operation_report_viewmodel.dart';

/// Vista de métricas de disponibilidad histórica para un equipo de proceso.
class OperationReportMetricsView extends StatefulWidget {
  const OperationReportMetricsView({
    super.key,
    required this.codigoActivo,
    required this.nombreActivo,
  });

  final String codigoActivo;
  final String nombreActivo;

  @override
  State<OperationReportMetricsView> createState() =>
      _OperationReportMetricsViewState();
}

class _OperationReportMetricsViewState
    extends State<OperationReportMetricsView> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() {
    return context.read<OperationReportViewModel>().cargarMetricas(
          widget.codigoActivo,
          desde: _desde,
          hasta: _hasta,
        );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
    );
    if (picked != null) {
      setState(() {
        _desde = picked.start;
        _hasta = picked.end;
      });
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<OperationReportViewModel>();
    final theme  = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas de Disponibilidad'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Cambiar rango',
            onPressed: _pickRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Encabezado
          Container(
            color: colors.primaryContainer.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.precision_manufacturing, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.nombreActivo,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold)),
                      Text(
                        '${_fmt(_desde)} – ${_fmt(_hasta)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _pickRange,
                  child: const Text('Cambiar rango'),
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.loadingMetrics
                ? const Center(child: CircularProgressIndicator())
                : vm.metricsError != null
                    ? Center(
                        child: Text(
                          vm.metricsError!,
                          style: TextStyle(color: colors.error),
                        ),
                      )
                    : vm.metrics == null
                        ? const Center(
                            child: Text('Sin datos para el período seleccionado.'))
                        : _MetricsBody(
                            m: vm.metrics!,
                            desde: _desde,
                            hasta: _hasta,
                          ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}';
}

class _MetricsBody extends StatelessWidget {
  const _MetricsBody({
    required this.m,
    required this.desde,
    required this.hasta,
  });
  final OperationMetrics m;
  final DateTime desde;
  final DateTime hasta;

  Color _dispColor(double pct) {
    if (pct >= 85) return const Color(0xFF2ECC71);
    if (pct >= 60) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // KPI Principal: Disponibilidad
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Disponibilidad Operativa',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${m.disponibilidadPct.toStringAsFixed(1)}%',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _dispColor(m.disponibilidadPct),
                    fontSize: 56,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: m.disponibilidadPct / 100,
                  backgroundColor: _dispColor(m.disponibilidadPct).withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _dispColor(m.disponibilidadPct)),
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                Text(
                  '${m.diasConReporte} días con registro · ${m.totalHorasOperacion.toStringAsFixed(1)}h operadas de ${m.totalHorasJornada.toStringAsFixed(1)}h jornada',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // MTBF / MTTR
        if (m.mtbfHoras != null || m.mttrHoras != null) ...[
          Row(
            children: [
              if (m.mtbfHoras != null)
                Expanded(
                  child: _KpiCard(
                    label: 'MTBF',
                    subtitle: 'Tiempo medio entre fallos',
                    value: '${m.mtbfHoras!.toStringAsFixed(1)}h',
                    color: const Color(0xFF3498DB),
                    icon: Icons.timer_outlined,
                  ),
                ),
              const SizedBox(width: 12),
              if (m.mttrHoras != null)
                Expanded(
                  child: _KpiCard(
                    label: 'MTTR',
                    subtitle: 'Tiempo medio de reparación',
                    value: '${m.mttrHoras!.toStringAsFixed(1)}h',
                    color: const Color(0xFFE74C3C),
                    icon: Icons.build_circle_outlined,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Desglose de paros
        Text('Desglose de paros',
            style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              _ParoRow('Por falla / avería', m.totalParoFalla, const Color(0xFFE74C3C)),
              _ParoRow('Mantenimiento preventivo', m.totalParoMantPrev, const Color(0xFF3498DB)),
              _ParoRow('Mantenimiento correctivo', m.totalParoMantCorr, const Color(0xFF9B59B6)),
              _ParoRow('Paro planificado', m.totalParoPlanificado, const Color(0xFFF39C12)),
              _ParoRow('Causa externa', m.totalParoExterno, const Color(0xFF95A5A6), isLast: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String subtitle;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: color,
              ),
            ),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      ),
    );
  }
}

class _ParoRow extends StatelessWidget {
  const _ParoRow(this.label, this.horas, this.color, {this.isLast = false});
  final String label;
  final double horas;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 6,
            backgroundColor: color,
          ),
          title: Text(label),
          trailing: Text(
            '${horas.toStringAsFixed(1)} h',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 32,
              endIndent: 16,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ],
    );
  }
}
