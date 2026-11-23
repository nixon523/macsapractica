import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../breakdown_reports/domain/entities/breakdown_report.dart';
import '../../../breakdown_reports/presentation/reports/breakdown_report_filter_dialog.dart';
import '../../../preventive_schedules/domain/entities/preventive_schedule.dart';
import '../../../work_orders/domain/entities/work_order.dart';
import '../../../work_orders/presentation/reports/work_order_report_filter_dialog.dart';
import '../../../work_orders/presentation/views/work_order_detail_view.dart';
import '../../domain/entities/cost_center_maintenance_stats.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'widgets/dashboard_interactive_chart.dart';

/// Tablero General de Control Ejecutivo y Operativo.
///
/// Diseño corporativo alineado a estándares ejecutivos:
/// - Fila de 5 tarjetas clave (Activos, Operatividad, Fuera de Servicio, Servicios Próximos, Cumplimiento).
/// - Panel central con priorización estricta de Órdenes de Trabajo pendientes, Averías abiertas y Agenda Preventiva.
/// - Panel lateral con Distribución por Área e indicadores de atención inmediata.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key, this.onNavigateToSection});

  final ValueChanged<String>? onNavigateToSection;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedPendingTab = 0; // 0: OTs Pendientes, 1: Averías Abiertas, 2: Agenda Preventiva

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardViewModel>().loadDashboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final stats = vm.stats;

    return RefreshIndicator(
      onRefresh: () async => context.read<DashboardViewModel>().loadDashboard(),
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cabecera Ejecutiva
              _buildHeader(context, vm),
              const SizedBox(height: 20),

              if (vm.isLoading && stats == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (vm.errorMessage.isNotEmpty && stats == null)
                _buildErrorCard(context, vm)
              else ...[
                // 2. Fila Superior de 5 Métricas Clave
                _buildKpiCardsRow(context, stats, vm),
                const SizedBox(height: 24),

                // 3. Sección Inferior: Panel Principal de Pendientes + Gráfico Interactivo de Balance
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1050;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildMainPendingPanel(context, vm),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: _buildSidePanel(context, vm),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardInteractiveChart(viewModel: vm),
                        const SizedBox(height: 20),
                        _buildMainPendingPanel(context, vm),
                        const SizedBox(height: 16),
                        _buildSecurityCard(context),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 4. Mantenimientos por Centro de Costo y Tipo
                _buildCostCenterMaintenanceSection(context, vm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Cabecera con título corporativo y subtítulo ejecutivo
  Widget _buildHeader(BuildContext context, DashboardViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Tablero General de Control',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Monitoreo ejecutivo de infraestructura, confiabilidad y mantenimiento',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vm.isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ],
            OutlinedButton.icon(
              onPressed: () => context.read<DashboardViewModel>().loadDashboard(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Fila de 5 tarjetas métricas ejecutivas con diseño limpio
  Widget _buildKpiCardsRow(
    BuildContext context,
    DashboardStats? stats,
    DashboardViewModel vm,
  ) {
    final totalAssets = stats?.totalAssets ?? 0;
    final openBreakdowns = stats?.openBreakdowns ?? vm.openBreakdowns.length;
    final activeAssets = (totalAssets - openBreakdowns).clamp(0, totalAssets);
    final operativityPct = totalAssets > 0
        ? ((activeAssets / totalAssets) * 100.0)
        : 100.0;
    final pendingOrders = stats?.pendingWorkOrders ?? vm.pendingWorkOrders.length;
    final overdueSchedules = stats?.overdueSchedules ?? 0;
    final complianceRate = stats?.pmComplianceRate ?? 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        const spacing = 14.0;

        // Distribución según ancho de pantalla
        int columns = 5;
        if (screenWidth < 640) {
          columns = 1;
        } else if (screenWidth < 920) {
          columns = 2;
        } else if (screenWidth < 1200) {
          columns = 3;
        }

        final itemWidth = (screenWidth - (spacing * (columns - 1))) / columns;

        final cards = [
          _buildKpiCard(
            title: 'TOTAL ACTIVOS',
            value: '$totalAssets',
            subtitle: 'Inventario registrado',
            valueColor: const Color(0xFF1D4ED8),
            onTap: () => widget.onNavigateToSection?.call('assets'),
          ),
          _buildKpiCard(
            title: 'OPERATIVIDAD',
            value: '$activeAssets',
            subtitle: '${operativityPct.toStringAsFixed(1)}% del total disponible',
            valueColor: const Color(0xFF16A34A),
            onTap: () => widget.onNavigateToSection?.call('assets'),
          ),
          _buildKpiCard(
            title: 'FUERA DE SERVICIO',
            value: '$openBreakdowns',
            subtitle: openBreakdowns == 0
                ? 'Sin fallas críticas'
                : '$openBreakdowns avería(s) activa(s)',
            valueColor: openBreakdowns > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF475569),
            onTap: () => widget.onNavigateToSection?.call('breakdownReports'),
          ),
          _buildKpiCard(
            title: 'SERVICIOS PRÓXIMOS',
            value: '$pendingOrders',
            subtitle: '$overdueSchedules vencidas',
            valueColor: const Color(0xFFD97706),
            onTap: () => widget.onNavigateToSection?.call('workOrders'),
          ),
          _buildKpiCard(
            title: 'CUMPLIMIENTO',
            value: '${complianceRate.toStringAsFixed(0)}%',
            subtitle: 'Programa preventivo',
            valueColor: const Color(0xFF0D9488),
            onTap: () => widget.onNavigateToSection?.call('preventive'),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  /// Tarjeta métrica individual con fondo blanco y tipografía ejecutiva
  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: const Color(0xFFF1F5F9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Panel principal para mostrar lo pendiente, priorizando OTs y Averías
  Widget _buildMainPendingPanel(BuildContext context, DashboardViewModel vm) {
    final pendingOrders = vm.pendingWorkOrders;
    final openBreakdowns = vm.openBreakdowns;
    final upcomingSchedules = vm.upcomingSchedules;

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
          // Selector de pestaña de pendientes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                // Pestañas tipo Segmented Control
                Wrap(
                  spacing: 8,
                  children: [
                    _buildPendingTabButton(
                      index: 0,
                      label: 'Órdenes de Trabajo',
                      count: pendingOrders.length,
                      badgeColor: const Color(0xFFD97706),
                    ),
                    _buildPendingTabButton(
                      index: 1,
                      label: 'Averías Abiertas',
                      count: openBreakdowns.length,
                      badgeColor: const Color(0xFFDC2626),
                    ),
                    _buildPendingTabButton(
                      index: 2,
                      label: 'Agenda Preventiva',
                      count: upcomingSchedules.length,
                      badgeColor: const Color(0xFF0284C7),
                    ),
                  ],
                ),

                // Acciones de reporte y navegación rápida
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        if (_selectedPendingTab == 0) {
                          WorkOrderReportFilterDialog.show(context, initialOrders: pendingOrders);
                        } else if (_selectedPendingTab == 1) {
                          BreakdownReportFilterDialog.show(context, initialReports: openBreakdowns);
                        } else {
                          widget.onNavigateToSection?.call('preventive');
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                      label: Text(
                        _selectedPendingTab == 0
                            ? 'Reporte OTs'
                            : (_selectedPendingTab == 1 ? 'Reporte Averías' : 'Exportar'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0055A5),
                        side: const BorderSide(color: Color(0xFF0055A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () {
                        switch (_selectedPendingTab) {
                          case 0:
                            widget.onNavigateToSection?.call('workOrders');
                          case 1:
                            widget.onNavigateToSection?.call('breakdownReports');
                          case 2:
                            widget.onNavigateToSection?.call('preventive');
                        }
                      },
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: Text(
                        _selectedPendingTab == 0
                            ? 'Gestionar OTs'
                            : (_selectedPendingTab == 1
                                ? 'Bandeja Averías'
                                : 'Ver Planes'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenido según pestaña seleccionada
          Padding(
            padding: const EdgeInsets.all(16),
            child: switch (_selectedPendingTab) {
              0 => _buildWorkOrdersTable(context, pendingOrders),
              1 => _buildBreakdownsTable(context, openBreakdowns),
              _ => _buildPreventiveScheduleTable(context, upcomingSchedules),
            },
          ),
        ],
      ),
    );
  }

  /// Botón de pestaña con badge numérico
  Widget _buildPendingTabButton({
    required int index,
    required String label,
    required int count,
    required Color badgeColor,
  }) {
    final isSelected = _selectedPendingTab == index;

    return Material(
      color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() => _selectedPendingTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFCBD5E1) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isSelected ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tabla de Órdenes de Trabajo Pendientes (priorizando Alta > Media > Baja)
  Widget _buildWorkOrdersTable(BuildContext context, List<WorkOrder> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Al día',
        message: 'No hay órdenes de trabajo pendientes ni en progreso en este momento.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF1E293B),
              ),
              horizontalMargin: 12,
              columnSpacing: 20,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Código OT')),
                DataColumn(label: Text('Activo')),
                DataColumn(label: Text('Descripción / Plan')),
                DataColumn(label: Text('Prioridad')),
                DataColumn(label: Text('Responsable')),
                DataColumn(label: Text('Acción')),
              ],
              rows: orders.take(12).map((order) {
                final dateStr = order.scheduledDate != null
                    ? order.scheduledDate!.toIso8601String().substring(0, 10)
                    : (order.createdAt != null
                        ? order.createdAt!.toIso8601String().substring(0, 10)
                        : '—');

                return DataRow(
                  cells: [
                    DataCell(Text(dateStr, style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(
                      Text(
                        order.displayCorrelative,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          '${order.assetId} · ${order.assetName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          order.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(_buildPriorityBadge(order.priority)),
                    DataCell(
                      Text(
                        order.assignedTo != null && order.assignedTo!.trim().isNotEmpty
                            ? order.assignedTo!
                            : 'Sin asignar',
                        style: TextStyle(
                          color: order.assignedTo != null && order.assignedTo!.trim().isNotEmpty
                              ? const Color(0xFF334155)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    DataCell(
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WorkOrderDetailView(order: order),
                            ),
                          ).then((_) {
                            if (context.mounted) {
                              context.read<DashboardViewModel>().loadDashboard();
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Ver OT', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// Tabla de Averías Abiertas (priorizando severidad Alta)
  Widget _buildBreakdownsTable(
    BuildContext context,
    List<BreakdownReport> breakdowns,
  ) {
    if (breakdowns.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Sin averías activas',
        message: 'No existen reportes de avería abiertos en la planta.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF1E293B),
              ),
              horizontalMargin: 12,
              columnSpacing: 20,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Folio')),
                DataColumn(label: Text('Activo')),
                DataColumn(label: Text('Falla Reportada')),
                DataColumn(label: Text('Severidad')),
                DataColumn(label: Text('Reportado Por')),
                DataColumn(label: Text('Acción')),
              ],
              rows: breakdowns.take(12).map((b) {
                final dateStr = b.reportedAt != null
                    ? b.reportedAt!.toIso8601String().substring(0, 10)
                    : '—';

                return DataRow(
                  cells: [
                    DataCell(Text(dateStr, style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(
                      Text(
                        b.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          '${b.assetId} · ${b.assetName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          b.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(_buildSeverityBadge(b.severity)),
                    DataCell(Text(b.reportedByUserName)),
                    DataCell(
                      OutlinedButton(
                        onPressed: () => widget.onNavigateToSection?.call('breakdownReports'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Atender', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// Tabla de Agenda de Mantenimientos Próximos (diseño exacto a la imagen de referencia)
  Widget _buildPreventiveScheduleTable(
    BuildContext context,
    List<PreventiveSchedule> schedules,
  ) {
    if (schedules.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'Sin servicios pendientes',
        message: 'No hay planes preventivos programados para los próximos días.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF1E293B),
              ),
              horizontalMargin: 12,
              columnSpacing: 20,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Activo')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Responsable')),
                DataColumn(label: Text('Estado')),
              ],
              rows: schedules.take(12).map((s) {
                final dateStr = s.nextDate.toIso8601String().substring(0, 10);
                final alert = s.alertLevel;

                final (badgeColor, badgeBg) = switch (alert) {
                  PreventiveAlertLevel.overdue => (const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
                  PreventiveAlertLevel.urgent => (const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                  PreventiveAlertLevel.upcoming => (const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
                  PreventiveAlertLevel.onSchedule => (const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
                };

                return DataRow(
                  cells: [
                    DataCell(Text(dateStr, style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          '${s.assetId} · ${s.assetName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          s.title.isNotEmpty ? s.title : s.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        s.createdByUserName != null && s.createdByUserName!.trim().isNotEmpty
                            ? s.createdByUserName!
                            : 'Mantenimiento General',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          alert.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// Badge de Prioridad de Orden de Trabajo
  Widget _buildPriorityBadge(WorkOrderPriority priority) {
    final (label, color, bg) = switch (priority) {
      WorkOrderPriority.high => ('Alta', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      WorkOrderPriority.medium => ('Media', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      WorkOrderPriority.low => ('Baja', const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  /// Badge de Severidad de Avería
  Widget _buildSeverityBadge(BreakdownSeverity severity) {
    final (label, color, bg) = switch (severity) {
      BreakdownSeverity.high => ('Crítica', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      BreakdownSeverity.medium => ('Media', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      BreakdownSeverity.low => ('Baja', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  /// Panel lateral con el Gráfico Interactivo de Balance Operativo y Acceso a Bitácora
  Widget _buildSidePanel(BuildContext context, DashboardViewModel vm) {
    return Column(
      children: [
        DashboardInteractiveChart(viewModel: vm),
        const SizedBox(height: 16),
        _buildSecurityCard(context),
      ],
    );
  }

  /// Tarjeta de Enlaces Rápidos y Seguridad Transaccional
  Widget _buildSecurityCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text(
                'Bitácora & Seguridad Transaccional',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Todas las órdenes de trabajo, averías y bajas de activos se auditan de forma inmutable en SQL Server.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => widget.onNavigateToSection?.call('kardex'),
            icon: const Icon(Icons.history_outlined, size: 14),
            label: const Text('Ver Kardex General', style: TextStyle(fontSize: 11.5)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 34),
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  /// Estado vacío
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de error con botón de reintento
  Widget _buildErrorCard(BuildContext context, DashboardViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
            const SizedBox(height: 8),
            Text(
              'Error al cargar el tablero: ${vm.errorMessage}',
              style: const TextStyle(color: Color(0xFFDC2626)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => vm.loadDashboard(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4. SECCIÓN: MANTENIMIENTOS POR CENTRO DE COSTO Y TIPO
  // --------------------------------------------------------------------------

  Widget _buildCostCenterMaintenanceSection(BuildContext context, DashboardViewModel vm) {
    final stats = vm.costCenterStats;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la sección
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Color(0xFF0055A5), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mantenimientos por Centro de Costo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Historial consolidado por Centro de Costo (CC) y tipos de intervención (Correctivo, Preventivo, Predictivo, Mejoras, Otros)',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: Text(
                        vm.onlyWithMaintenance ? 'Solo con actividad' : 'Todos los CC',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: vm.onlyWithMaintenance ? const Color(0xFF0055A5) : const Color(0xFF475569),
                        ),
                      ),
                      selected: vm.onlyWithMaintenance,
                      onSelected: (_) => vm.toggleOnlyWithMaintenance(),
                      avatar: Icon(
                        vm.onlyWithMaintenance ? Icons.filter_alt : Icons.filter_alt_outlined,
                        size: 14,
                        color: vm.onlyWithMaintenance ? const Color(0xFF0055A5) : const Color(0xFF64748B),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Actualizar centros de costo',
                      onPressed: vm.isLoadingCostCenters ? null : () => vm.loadCostCenterMaintenance(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Resumen rápido de KPIs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 700;
                final items = [
                  _buildCostCenterMetricChip(
                    label: 'Total Trabajos',
                    value: '${vm.totalCostCenterMaintenance}',
                    color: const Color(0xFF0F172A),
                    bg: const Color(0xFFF1F5F9),
                    icon: Icons.assignment_outlined,
                  ),
                  _buildCostCenterMetricChip(
                    label: 'Correctivos',
                    value: '${vm.totalCostCenterCorrective}',
                    color: const Color(0xFFDC2626),
                    bg: const Color(0xFFFEE2E2),
                    icon: Icons.warning_amber_rounded,
                  ),
                  _buildCostCenterMetricChip(
                    label: 'Preventivos',
                    value: '${vm.totalCostCenterPreventive}',
                    color: const Color(0xFF0284C7),
                    bg: const Color(0xFFE0F2FE),
                    icon: Icons.calendar_today_outlined,
                  ),
                  _buildCostCenterMetricChip(
                    label: 'Predictivos / Mejoras',
                    value: '${vm.totalCostCenterPredictive + vm.totalCostCenterImprovement}',
                    color: const Color(0xFF7C3AED),
                    bg: const Color(0xFFF3E8FF),
                    icon: Icons.trending_up_outlined,
                  ),
                  _buildCostCenterMetricChip(
                    label: 'Horas Reales',
                    value: '${vm.totalCostCenterHours.toStringAsFixed(1)} h',
                    color: const Color(0xFF059669),
                    bg: const Color(0xFFD1FAE5),
                    icon: Icons.access_time_outlined,
                  ),
                ];

                if (isCompact) {
                  return Wrap(spacing: 8, runSpacing: 8, children: items);
                }
                return Row(
                  children: items
                      .map((w) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: w,
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Contenido: Lista / Tabla
          if (vm.isLoadingCostCenters && stats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (stats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  vm.onlyWithMaintenance
                      ? 'No hay registros de mantenimiento para los centros de costo con filtros actuales.'
                      : 'No se encontraron áreas ni centros de costo registrados.',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            _buildCostCenterTable(context, stats, vm),
        ],
      ),
    );
  }

  Widget _buildCostCenterMetricChip({
    required String label,
    required String value,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostCenterTable(
    BuildContext context,
    List<CostCenterMaintenanceStats> stats,
    DashboardViewModel vm,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF1E293B),
              ),
              horizontalMargin: 16,
              columnSpacing: 18,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Centro Costo')),
                DataColumn(label: Text('Área / Ubicación')),
                DataColumn(label: Text('Total OTs')),
                DataColumn(label: Text('Tipos de Mantenimiento')),
                DataColumn(label: Text('Estado Trabajos')),
                DataColumn(label: Text('Horas Invertidas')),
                DataColumn(label: Text('Detalle')),
              ],
              rows: stats.map((item) {
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          item.costCenter.isNotEmpty ? item.costCenter : 'S/CC',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${item.areaId} · ${item.areaName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${item.totalMaintenance}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.corrective > 0)
                            _buildMaintenanceTypeBadge(
                              'Correctivo: ${item.corrective}',
                              const Color(0xFFDC2626),
                              const Color(0xFFFEE2E2),
                            ),
                          if (item.preventive > 0)
                            _buildMaintenanceTypeBadge(
                              'Preventivo: ${item.preventive}',
                              const Color(0xFF0284C7),
                              const Color(0xFFE0F2FE),
                            ),
                          if (item.predictive > 0)
                            _buildMaintenanceTypeBadge(
                              'Predictivo: ${item.predictive}',
                              const Color(0xFF7C3AED),
                              const Color(0xFFF3E8FF),
                            ),
                          if (item.improvement > 0)
                            _buildMaintenanceTypeBadge(
                              'Mejora: ${item.improvement}',
                              const Color(0xFF0D9488),
                              const Color(0xFFCCFBF1),
                            ),
                          if (item.otherTypes > 0)
                            _buildMaintenanceTypeBadge(
                              'Otros: ${item.otherTypes}',
                              const Color(0xFF64748B),
                              const Color(0xFFF1F5F9),
                            ),
                          if (item.totalMaintenance == 0)
                            const Text('—', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        '${item.completed} completadas · ${item.inProgress} en proceso',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${item.totalRealHours.toStringAsFixed(1)} h',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0055A5)),
                        tooltip: 'Ver órdenes de trabajo asociadas',
                        onPressed: item.totalMaintenance > 0
                            ? () => _showCostCenterDetailDialog(context, item, vm)
                            : null,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceTypeBadge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Future<void> _showCostCenterDetailDialog(
    BuildContext context,
    CostCenterMaintenanceStats stat,
    DashboardViewModel vm,
  ) async {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<CostCenterMaintenanceDetail>>(
          future: vm.getCostCenterDetails(
            costCenter: stat.costCenter.isNotEmpty ? stat.costCenter : null,
            areaId: stat.areaId,
          ),
          builder: (dialogCtx, snapshot) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF0055A5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Órdenes en ${stat.costCenter.isNotEmpty ? stat.costCenter : "Área"} · ${stat.areaName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${stat.totalMaintenance} órdenes de trabajo registradas',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 720,
                height: 400,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : (snapshot.data == null || snapshot.data!.isEmpty)
                        ? const Center(
                            child: Text(
                              'No se encontraron detalles para este centro de costo.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: snapshot.data!.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (itemCtx, index) {
                              final d = snapshot.data![index];
                              final dateStr = d.createdAt != null
                                  ? d.createdAt!.toIso8601String().substring(0, 10)
                                  : '—';

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    d.workOrderId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${d.assetCode} · ${d.assetName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'Fecha: $dateStr',
                                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                                        ),
                                        if (d.actualHours != null && d.actualHours! > 0) ...[
                                          const Text(' · ', style: TextStyle(color: Colors.black54)),
                                          Text(
                                            'Horas: ${d.actualHours!.toStringAsFixed(1)} h',
                                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                                          ),
                                        ],
                                        if (d.assignedTo != null && d.assignedTo!.isNotEmpty) ...[
                                          const Text(' · ', style: TextStyle(color: Colors.black54)),
                                          Text(
                                            'Resp: ${d.assignedTo}',
                                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: _buildMaintenanceTypeBadge(
                                  d.mainMaintenanceType == 'preventive'
                                      ? 'Preventivo'
                                      : (d.mainMaintenanceType == 'corrective'
                                          ? 'Correctivo'
                                          : 'Otro'),
                                  d.mainMaintenanceType == 'preventive'
                                      ? const Color(0xFF0284C7)
                                      : (d.mainMaintenanceType == 'corrective'
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF64748B)),
                                  d.mainMaintenanceType == 'preventive'
                                      ? const Color(0xFFE0F2FE)
                                      : (d.mainMaintenanceType == 'corrective'
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFF1F5F9)),
                                ),
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
