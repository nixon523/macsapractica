import 'package:flutter/material.dart';

import '../../viewmodels/dashboard_viewmodel.dart';

/// Gráfico interactivo y analítico para el Balance Operativo de Mantenimiento.
///
/// Compara en tiempo real:
/// - 🔴 Averías Activas / Reportadas
/// - 🟠 Órdenes de Trabajo Pendientes / en proceso
/// - 🟢 Órdenes de Trabajo Completadas / cerradas
///
/// Permite filtrado interactivo por Semana, Mes, Año o Todo el Histórico,
/// alternar series visibles y hacer clic para ver el diagnóstico detallado.
class DashboardInteractiveChart extends StatelessWidget {
  const DashboardInteractiveChart({
    super.key,
    required this.viewModel,
  });

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final points = viewModel.chartPoints;
    final selectedIndex = viewModel.selectedChartPointIndex;
    final activePoint = (selectedIndex != null && selectedIndex < points.length)
        ? points[selectedIndex]
        : (points.isNotEmpty ? points.last : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera con Título y Selector de Periodo
          _buildHeader(context),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 2. Barra de Leyenda Interactiva y KPIs de Resumen
          _buildLegendAndSummaryBar(context),

          // 3. Área del Gráfico de Barras Agrupadas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildChartArea(context, points, selectedIndex),
          ),

          // 4. Detalle / Tooltip Interactivo del Punto Seleccionado
          if (activePoint != null) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            _buildInteractiveDetailCard(context, activePoint),
          ],
        ],
      ),
    );
  }

  /// Encabezado con título y filtros interactivos de tiempo
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Balance Operativo y Flujo de Mantenimiento',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Averías vs OTs Pendientes vs OTs Completadas',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Selector de Periodos (Semana, Mes, Año, Histórico)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: DashboardChartPeriod.values.map((period) {
                final isSelected = viewModel.chartPeriod == period;
                return InkWell(
                  onTap: () => viewModel.setChartPeriod(period),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      period.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Leyenda interactiva que permite ocultar o mostrar series
  Widget _buildLegendAndSummaryBar(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          // Series con botones interactivos de activación/desactivación
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildSeriesToggle(
                label: 'Averías',
                count: viewModel.totalAveriasInPeriod,
                color: const Color(0xFFDC2626),
                isActive: viewModel.showAveriasSeries,
                onTap: viewModel.toggleAveriasSeries,
              ),
              _buildSeriesToggle(
                label: 'OTs Pendientes',
                count: viewModel.totalPendingInPeriod,
                color: const Color(0xFFD97706),
                isActive: viewModel.showPendingSeries,
                onTap: viewModel.togglePendingSeries,
              ),
              _buildSeriesToggle(
                label: 'OTs Completadas',
                count: viewModel.totalCompletedInPeriod,
                color: const Color(0xFF16A34A),
                isActive: viewModel.showCompletedSeries,
                onTap: viewModel.toggleCompletedSeries,
              ),
            ],
          ),

          // Tasa de Resolución global del periodo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 13,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 4),
                Text(
                  'Efectividad: ${viewModel.overallResolutionRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Toggle interactivo para encender/apagar una serie
  Widget _buildSeriesToggle({
    required String label,
    required int count,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive ? color : color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isActive ? color : Colors.grey.shade400,
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? const Color(0xFF334155)
                    : const Color(0xFF94A3B8),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isActive ? color : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lienzo del gráfico con barras agrupadas proporcionales y escala Y
  Widget _buildChartArea(
    BuildContext context,
    List<DashboardChartPoint> points,
    int? selectedIndex,
  ) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No hay datos registrados para este periodo.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    // Calcular el valor máximo para escalar la altura de las barras
    int maxValue = 1;
    for (final p in points) {
      if (viewModel.showAveriasSeries && p.averiasCount > maxValue) {
        maxValue = p.averiasCount;
      }
      if (viewModel.showPendingSeries && p.pendingWorkOrdersCount > maxValue) {
        maxValue = p.pendingWorkOrdersCount;
      }
      if (viewModel.showCompletedSeries &&
          p.completedWorkOrdersCount > maxValue) {
        maxValue = p.completedWorkOrdersCount;
      }
    }

    const chartHeight = 160.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final colWidth = totalWidth / points.length;

        return Column(
          children: [
            // Área de barras con líneas guía de fondo
            SizedBox(
              height: chartHeight,
              child: Stack(
                children: [
                  // 1. Líneas de referencia horizontales (Grid)
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildGridLine('$maxValue'),
                        _buildGridLine('${(maxValue / 2).ceil()}'),
                        _buildGridLine('0'),
                      ],
                    ),
                  ),

                  // 2. Columnas de barras agrupadas interactivas
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(points.length, (index) {
                        final point = points[index];
                        final isSelected = selectedIndex == index;

                        return SizedBox(
                          width: colWidth,
                          child: InkWell(
                            onTap: () => viewModel.selectChartPoint(index),
                            borderRadius: BorderRadius.circular(6),
                            hoverColor: const Color(0xFFF8FAFC),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0284C7).withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF0284C7)
                                            .withValues(alpha: 0.3),
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Barra 1: Averías
                                  if (viewModel.showAveriasSeries)
                                    _buildSingleBar(
                                      value: point.averiasCount,
                                      maxValue: maxValue,
                                      maxHeight: chartHeight - 16,
                                      color: const Color(0xFFDC2626),
                                    ),

                                  // Barra 2: OTs Pendientes
                                  if (viewModel.showPendingSeries)
                                    _buildSingleBar(
                                      value: point.pendingWorkOrdersCount,
                                      maxValue: maxValue,
                                      maxHeight: chartHeight - 16,
                                      color: const Color(0xFFD97706),
                                    ),

                                  // Barra 3: OTs Completadas
                                  if (viewModel.showCompletedSeries)
                                    _buildSingleBar(
                                      value: point.completedWorkOrdersCount,
                                      maxValue: maxValue,
                                      maxHeight: chartHeight - 16,
                                      color: const Color(0xFF16A34A),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Etiquetas de texto en el eje X
            Row(
              children: List.generate(points.length, (index) {
                final point = points[index];
                final isSelected = selectedIndex == index;

                return SizedBox(
                  width: colWidth,
                  child: Text(
                    point.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  /// Línea horizontal de referencia
  Widget _buildGridLine(String label) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1)),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Divider(
            height: 1,
            thickness: 0.8,
            color: Color(0xFFF1F5F9),
          ),
        ),
      ],
    );
  }

  /// Barra individual animada y proporcional
  Widget _buildSingleBar({
    required int value,
    required int maxValue,
    required double maxHeight,
    required Color color,
  }) {
    final barHeight = value > 0 ? (value / maxValue) * maxHeight : 2.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Tooltip(
        message: '$value',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 6.5,
          height: barHeight.clamp(2.0, maxHeight),
          decoration: BoxDecoration(
            color: value > 0 ? color : const Color(0xFFE2E8F0),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );
  }

  /// Tarjeta de detalle interactivo al seleccionar o hacer clic en un punto
  Widget _buildInteractiveDetailCard(
    BuildContext context,
    DashboardChartPoint point,
  ) {
    final isGood = point.completedWorkOrdersCount >=
        (point.averiasCount + point.pendingWorkOrdersCount);
    final hasActivity = point.totalEvents > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Detalle del corte: ${point.label} (${point.sublabel})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Efectividad: ${point.resolutionRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isGood
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Píldoras de métricas exactas
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildMetricChip(
                label: 'Averías Reportadas',
                value: '${point.averiasCount}',
                color: const Color(0xFFDC2626),
              ),
              _buildMetricChip(
                label: 'OTs Pendientes',
                value: '${point.pendingWorkOrdersCount}',
                color: const Color(0xFFD97706),
              ),
              _buildMetricChip(
                label: 'OTs Completadas',
                value: '${point.completedWorkOrdersCount}',
                color: const Color(0xFF16A34A),
              ),
            ],
          ),

          if (hasActivity) ...[
            const SizedBox(height: 6),
            Text(
              isGood
                  ? 'Buen balance: el volumen de órdenes cerradas supera o equilibra los incidentes presentados.'
                  : (point.averiasCount > point.completedWorkOrdersCount
                      ? 'Atención: Se reportaron más averías de las que se lograron cerrar en este corte.'
                      : 'Carga en proceso: existen órdenes pendientes que requieren cierre técnico.'),
              style: TextStyle(
                fontSize: 11,
                color: isGood
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB45309),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: color),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

