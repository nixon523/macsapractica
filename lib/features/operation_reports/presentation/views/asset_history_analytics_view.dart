import 'package:flutter/material.dart';

import '../../../../app/di/get_it.dart';
import '../../domain/entities/maintenance_analytics.dart';
import '../viewmodels/maintenance_analytics_viewmodel.dart';

/// Hoja de Vida y Diagnóstico Individual de un Activo / Sub-árbol jerárquico.
class AssetHistoryAnalyticsView extends StatefulWidget {
  const AssetHistoryAnalyticsView({
    super.key,
    required this.codigoActivo,
    required this.nombreActivo,
  });

  final String codigoActivo;
  final String nombreActivo;

  @override
  State<AssetHistoryAnalyticsView> createState() =>
      _AssetHistoryAnalyticsViewState();
}

class _AssetHistoryAnalyticsViewState extends State<AssetHistoryAnalyticsView>
    with SingleTickerProviderStateMixin {
  late final MaintenanceAnalyticsViewModel _viewModel =
      getIt<MaintenanceAnalyticsViewModel>();
  late TabController _tabController;

  bool _incluirHijos = true;
  DateTime _desde = DateTime.now().subtract(const Duration(days: 365));
  DateTime _hasta = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _cargar() {
    _viewModel.loadAssetHistory(
      widget.codigoActivo,
      fechaDesde: _desde,
      fechaHasta: _hasta,
      incluirHijos: _incluirHijos,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final history = _viewModel.assetHistory;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nombreActivo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Hoja de Vida: ${widget.codigoActivo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.date_range_outlined),
                tooltip: 'Filtrar Periodo',
                onPressed: _pickDateRange,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: _cargar,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'KPIs & Diagnóstico'),
                Tab(icon: Icon(Icons.history_outlined), text: 'Línea de Tiempo'),
                Tab(icon: Icon(Icons.build_circle_outlined), text: 'Piezas & Repuestos'),
              ],
            ),
          ),
          body: _viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _viewModel.errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          _viewModel.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : history == null
                      ? const Center(child: Text('Sin datos disponibles'))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildKpisTab(history.resumen, isDark),
                            _buildTimelineTab(history.timeline, isDark),
                            _buildPartsTab(history.repuestos, isDark),
                          ],
                        ),
        );
      },
    );
  }

  Widget _buildKpisTab(AssetKpiSummary kpi, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Switch de componentes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Incluir sub-equipos, partes y sub-partes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Switch(
              value: _incluirHijos,
              onChanged: (val) {
                setState(() => _incluirHijos = val);
                _cargar();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid de Métricas Principales
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'Total Averías',
              value: '${kpi.totalAverias}',
              subtitle: '${kpi.totalAveriasCriticas} críticas',
              icon: Icons.warning_amber_rounded,
              color: Colors.orange.shade800,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'Órdenes de Trabajo',
              value: '${kpi.totalOrdenesTrabajo}',
              subtitle: '${kpi.totalOTsPreventivas} PM / ${kpi.totalOTsCorrectivas} Correctivas',
              icon: Icons.assignment_outlined,
              color: const Color(0xFF0055A5),
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'Horas Taller Acum.',
              value: '${kpi.horasTotalesTaller.toStringAsFixed(1)} h',
              subtitle: 'Tiempo total invertido',
              icon: Icons.timer_outlined,
              color: Colors.blueGrey,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'MTTR (Reparación Media)',
              value: kpi.mttrHorasPromedio != null
                  ? '${kpi.mttrHorasPromedio!.toStringAsFixed(1)} h'
                  : '—',
              subtitle: 'Tiempo medio por reparación',
              icon: Icons.handyman_outlined,
              color: Colors.teal,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'MTBF (Tiempo Entre Fallas)',
              value: kpi.mtbfDiasEstimado != null
                  ? '${kpi.mtbfDiasEstimado!.toStringAsFixed(0)} días'
                  : '—',
              subtitle: 'Frecuencia promedio de avería',
              icon: Icons.update_rounded,
              color: Colors.indigo,
              isDark: isDark,
            ),
            if (kpi.disponibilidadPromedioPct != null)
              _buildMetricCard(
                title: 'Disponibilidad Operativa',
                value: '${kpi.disponibilidadPromedioPct!.toStringAsFixed(1)}%',
                subtitle: 'Basado en reporte diario',
                icon: Icons.check_circle_outline,
                color: Colors.green.shade700,
                isDark: isDark,
              ),
            if (kpi.oeePromedioPct != null)
              _buildMetricCard(
                title: 'OEE General',
                value: '${kpi.oeePromedioPct!.toStringAsFixed(1)}%',
                subtitle: 'Efectividad Operacional',
                icon: Icons.speed_rounded,
                color: const Color(0xFF7C3AED),
                isDark: isDark,
              ),
          ],
        ),

        const SizedBox(height: 24),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos Técnicos del Activo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _buildTechRow('Área:', kpi.nombreArea),
                _buildTechRow('Nivel Jerárquico:', kpi.nivel),
                if (kpi.marca != null && kpi.marca!.isNotEmpty) _buildTechRow('Marca:', kpi.marca!),
                if (kpi.modelo != null && kpi.modelo!.isNotEmpty) _buildTechRow('Modelo:', kpi.modelo!),
                if (kpi.serie != null && kpi.serie!.isNotEmpty) _buildTechRow('Serie:', kpi.serie!),
                _buildTechRow('Estado Operativo:', kpi.estadoActivo),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(List<MaintenanceIntervention> timeline, bool isDark) {
    if (timeline.isEmpty) {
      return const Center(child: Text('No hay intervenciones registradas en este periodo'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final item = timeline[index];
        final isAveria = item.tipoIntervencion == 'AVERIA';
        final isOtPreventiva = item.tipoIntervencion == 'OT_PREVENTIVA';

        final iconData = isAveria
            ? Icons.warning_amber_rounded
            : (isOtPreventiva ? Icons.event_available_outlined : Icons.handyman_outlined);

        final badgeColor = isAveria
            ? Colors.orange.shade800
            : (isOtPreventiva ? Colors.blue.shade700 : Colors.teal.shade700);

        final fechaStr =
            '${item.fecha.day.toString().padLeft(2, "0")}/${item.fecha.month.toString().padLeft(2, "0")}/${item.fecha.year}';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.12),
              child: Icon(iconData, color: badgeColor, size: 20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.tipoIntervencion.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.id,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  fechaStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  item.titulo,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (item.descripcion.isNotEmpty && item.descripcion != item.titulo)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (item.horasReales != null && item.horasReales! > 0) ...[
                      Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${item.horasReales} h taller',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (item.responsable != null && item.responsable!.isNotEmpty) ...[
                      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        item.responsable!,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartsTab(List<PartReplacementStat> parts, bool isDark) {
    if (parts.isEmpty) {
      return const Center(
        child: Text('No hay registro de repuestos o piezas cambiadas en este periodo'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.blue.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0055A5), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Frecuencia y ciclo de vida de componentes: te permite ajustar la periodicidad de los planes preventivos antes de que ocurra la falla.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Repuesto / Pieza')),
              DataColumn(label: Text('Total Consumido')),
              DataColumn(label: Text('Veces Reemplazado')),
              DataColumn(label: Text('Frecuencia Media')),
              DataColumn(label: Text('Último Cambio')),
            ],
            rows: parts.map((p) {
              final ultimoStr = p.ultimoReemplazo != null
                  ? '${p.ultimoReemplazo!.day.toString().padLeft(2, "0")}/${p.ultimoReemplazo!.month.toString().padLeft(2, "0")}/${p.ultimoReemplazo!.year}'
                  : '—';
              final frecuenciaStr = p.diasPromedioEntreReemplazos != null
                  ? 'Cada ~${p.diasPromedioEntreReemplazos!.toStringAsFixed(0)} días'
                  : '1 solo cambio';

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      p.repuesto,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(Text('${p.cantidadTotalConsumida} ${p.unidad}')),
                  DataCell(Text('${p.vecesReemplazado}')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        frecuenciaStr,
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(ultimoStr)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

