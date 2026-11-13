import 'package:flutter/material.dart';

import '../../../../app/di/get_it.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/usecases/get_areas_usecase.dart';
import '../../../assets/presentation/views/widgets/area_search_dialog.dart';
import '../../domain/entities/maintenance_analytics.dart';
import '../viewmodels/maintenance_analytics_viewmodel.dart';
import 'asset_history_analytics_view.dart';

/// Dashboard Integral de Tendencias, Estacionalidad de Averías, MTTR y OEE General.
class MaintenanceAnalyticsDashboardView extends StatefulWidget {
  const MaintenanceAnalyticsDashboardView({super.key});

  @override
  State<MaintenanceAnalyticsDashboardView> createState() =>
      _MaintenanceAnalyticsDashboardViewState();
}

class _MaintenanceAnalyticsDashboardViewState
    extends State<MaintenanceAnalyticsDashboardView>
    with SingleTickerProviderStateMixin {
  late final MaintenanceAnalyticsViewModel _viewModel =
      getIt<MaintenanceAnalyticsViewModel>();
  late TabController _tabController;

  List<Area> _areas = [];
  String? _selectedAreaId;
  int _selectedYear = DateTime.now().year;
  int? _selectedSeasonalityMonthIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarAreas();
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _cargarAreas() async {
    try {
      final getAreas = getIt<GetAreasUseCase>();
      final areas = await getAreas(const NoParams());
      if (mounted) {
        setState(() => _areas = areas);
      }
    } catch (_) {}
  }

  void _cargar() {
    _viewModel.loadDashboardAnalytics(
      areaId: _selectedAreaId,
      anio: _selectedYear,
    );
  }

  String get _nombreAreaSeleccionada {
    if (_selectedAreaId == null || _selectedAreaId!.isEmpty) {
      return 'Todas las Áreas (Toda la Planta)';
    }
    final match = _areas.where((a) => a.id == _selectedAreaId).firstOrNull;
    if (match != null) {
      return '${match.id} — ${match.name}';
    }
    return _selectedAreaId!;
  }

  Future<void> _seleccionarArea() async {
    if (_areas.isEmpty) {
      await _cargarAreas();
    }
    if (!mounted) return;
    final result = await AreaSearchDialog.show(
      context,
      areas: _areas,
      currentAreaId: _selectedAreaId,
    );
    if (result != null) {
      setState(() {
        _selectedAreaId = result.isEmpty ? null : result;
      });
      _cargar();
    }
  }

  Future<void> _seleccionarAnioModal() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(8, (i) => currentYear + 1 - i);

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Seleccionar Año de Análisis',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        children: years.map((y) {
          final isSelected = y == _selectedYear;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, y),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$y',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF0284C7) : null,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, size: 18, color: Color(0xFF0284C7)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null && selected != _selectedYear) {
      setState(() => _selectedYear = selected);
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
        return Scaffold(
          body: Column(
            children: [
              // Barra superior con pestañas ejecutivas y botón de refresco
              Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.calendar_month_outlined),
                            text: 'Estacionalidad Mensual & MTTR',
                          ),
                          Tab(
                            icon: Icon(Icons.leaderboard_outlined),
                            text: 'Top Averías (Pareto)',
                          ),
                          Tab(
                            icon: Icon(Icons.settings_suggest_outlined),
                            text: 'Consumo de Piezas',
                          ),
                          Tab(
                            icon: Icon(Icons.speed_outlined),
                            text: 'OEE por Equipo',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar Datos',
                      onPressed: _cargar,
                    ),
                  ],
                ),
              ),

              // Barra de Filtros Ejecutiva (Área con Buscador + Navegación de Año)
              _buildFilterBar(isDark),

              // Contenido con Tabs
              Expanded(
                child: _viewModel.isLoading
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
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSeasonalityTab(
                                _viewModel.seasonalityStats,
                                isDark,
                              ),
                              _buildTopFailuresTab(
                                _viewModel.topFailures,
                                isDark,
                              ),
                              _buildPartsConsumptionTab(
                                _viewModel.partsConsumption,
                                isDark,
                              ),
                              _buildOeeTab(_viewModel.oeeRecords, isDark),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Barra de filtros con Buscador de Área y Selector de Años dinámico
  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          // 1. Selector de Área con Buscador
          InkWell(
            onTap: _seleccionarArea,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.apartment_outlined,
                    size: 16,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      _nombreAreaSeleccionada,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: isDark
                        ? Colors.grey.shade400
                        : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // 2. Navegador de Año Dinámico [ ◀  2026  ▶ ]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Año anterior',
                  onPressed: () {
                    setState(() => _selectedYear--);
                    _cargar();
                  },
                ),
                InkWell(
                  onTap: _seleccionarAnioModal,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_selectedYear',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.unfold_more,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Año siguiente',
                  onPressed: _selectedYear < DateTime.now().year + 1
                      ? () {
                          setState(() => _selectedYear++);
                          _cargar();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pestaña 1: Estacionalidad Mensual, MTTR y Gráficos Ejecutivos
  Widget _buildSeasonalityTab(List<SeasonalityStat> stats, bool isDark) {
    if (stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 44, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'No hay datos registrados para el año $_selectedYear',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Cálculos consolidados anuales
    final totalAveriasAnual =
        stats.fold<int>(0, (sum, s) => sum + s.totalAverias);
    final totalHorasTaller =
        stats.fold<double>(0.0, (sum, s) => sum + s.horasTotalesTaller);
    final totalOtsCorrectivas =
        stats.fold<int>(0, (sum, s) => sum + s.otsCorrectivas);
    final mttrPromedioAnual = totalAveriasAnual > 0
        ? (totalHorasTaller / totalAveriasAnual)
        : (totalOtsCorrectivas > 0
            ? (totalHorasTaller / totalOtsCorrectivas)
            : 0.0);

    final maxAverias =
        stats.fold<int>(0, (max, s) => s.totalAverias > max ? s.totalAverias : max);
    final mesPico = stats.firstWhere(
      (s) => s.totalAverias == maxAverias && maxAverias > 0,
      orElse: () => stats.first,
    );

    final selectedMonth = (_selectedSeasonalityMonthIndex != null &&
            _selectedSeasonalityMonthIndex! < stats.length)
        ? stats[_selectedSeasonalityMonthIndex!]
        : (maxAverias > 0 ? mesPico : stats.first);

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 12 : 16),
      children: [
        // 1. Tarjetas Superiores de Métricas y MTTR Anual
        _buildSeasonalityKpiRow(
          totalAverias: totalAveriasAnual,
          mttrPromedio: mttrPromedioAnual,
          totalHorasTaller: totalHorasTaller,
          mesPico: mesPico,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // 2. Gráfico Interactivo de Barras de 12 Meses (Ene - Dic)
        _buildSeasonalityBarChartCard(
          stats: stats,
          maxAverias: maxAverias,
          selectedMonth: selectedMonth,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // 3. Matriz / Tabla Ejecutiva Detallada (Estilo de la Captura 2)
        _buildSeasonalityTableCard(stats: stats, isDark: isDark),
      ],
    );
  }

  /// Fila de 4 tarjetas KPI para Estacionalidad y MTTR
  Widget _buildSeasonalityKpiRow({
    required int totalAverias,
    required double mttrPromedio,
    required double totalHorasTaller,
    required SeasonalityStat mesPico,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        int columns = 4;
        if (screenWidth < 600) {
          columns = 1;
        } else if (screenWidth < 980) {
          columns = 2;
        }

        const spacing = 12.0;
        final itemWidth = (screenWidth - (spacing * (columns - 1))) / columns;

        final cards = [
          _buildAnalyticsMetricCard(
            title: 'TOTAL AVERÍAS ($_selectedYear)',
            value: '$totalAverias',
            subtitle: 'Incidentes registrados',
            valueColor: const Color(0xFF1D4ED8),
            icon: Icons.warning_amber_rounded,
            isDark: isDark,
          ),
          _buildAnalyticsMetricCard(
            title: 'MTTR PROMEDIO',
            value: '${mttrPromedio.toStringAsFixed(1)} hrs',
            subtitle: 'Tiempo medio de reparación',
            valueColor: const Color(0xFF0D9488),
            icon: Icons.build_circle_outlined,
            isDark: isDark,
          ),
          _buildAnalyticsMetricCard(
            title: 'HORAS EN TALLER',
            value: '${totalHorasTaller.toStringAsFixed(1)} h',
            subtitle: 'Mantenimiento correctivo',
            valueColor: const Color(0xFFD97706),
            icon: Icons.hourglass_bottom_outlined,
            isDark: isDark,
          ),
          _buildAnalyticsMetricCard(
            title: 'MES CON MÁS FALLOS',
            value: mesPico.totalAverias > 0 ? mesPico.nombreMes : 'Sin picos',
            subtitle: mesPico.totalAverias > 0
                ? '${mesPico.totalAverias} averías en ${mesPico.nombreMes}'
                : 'Operación estable',
            valueColor: mesPico.totalAverias > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A),
            icon: Icons.insights_outlined,
            isDark: isDark,
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

  /// Tarjeta de métrica analítica individual
  Widget _buildAnalyticsMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 16, color: valueColor.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Tarjeta con el Gráfico de Barras Mensuales Interactivo (12 Meses)
  Widget _buildSeasonalityBarChartCard({
    required List<SeasonalityStat> stats,
    required int maxAverias,
    required SeasonalityStat selectedMonth,
    required bool isDark,
  }) {
    const chartHeight = 170.0;
    final maxScale = maxAverias > 0 ? maxAverias : 5;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
          // Cabecera del Gráfico
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribución Mensual de Averías y Tiempos MTTR ($_selectedYear)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Haz clic en un mes para ver el desglose operativo detallado',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 14, color: Color(0xFF0284C7)),
                      SizedBox(width: 4),
                      Text(
                        'Interactivo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Lienzo de Barras
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isScrollable = constraints.maxWidth < 540;
                final totalWidth = isScrollable ? 540.0 : constraints.maxWidth;
                final colWidth = totalWidth / stats.length;

                final chartContent = SizedBox(
                  width: totalWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: chartHeight,
                        child: Stack(
                          children: [
                            // Líneas de guía de fondo
                            Positioned.fill(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildChartGridLine('$maxScale fallas'),
                                  _buildChartGridLine(
                                      '${(maxScale / 2).ceil()} fallas'),
                                  _buildChartGridLine('0 fallas'),
                                ],
                              ),
                            ),

                            // Columnas de cada mes
                            Positioned.fill(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(stats.length, (index) {
                                  final s = stats[index];
                                  final isSelected =
                                      selectedMonth.mesNumero == s.mesNumero;
                                  final isPico =
                                      s.totalAverias > 0 && s.totalAverias == maxAverias;

                                  final barHeight = s.totalAverias > 0
                                      ? (s.totalAverias / maxScale) *
                                          (chartHeight - 32)
                                      : 2.0;

                                  final barColor = s.averiasCriticas > 0
                                      ? const Color(0xFFDC2626)
                                      : (isPico
                                          ? const Color(0xFFEA580C)
                                          : (s.totalAverias > 0
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFFE2E8F0)));

                                  return SizedBox(
                                    width: colWidth,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedSeasonalityMonthIndex = index;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF0284C7)
                                                  .withValues(alpha: 0.1)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: isSelected
                                              ? Border.all(
                                                  color: const Color(0xFF0284C7)
                                                      .withValues(alpha: 0.4),
                                                )
                                              : null,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // Valor numérico de averías arriba de la barra
                                            if (s.totalAverias > 0)
                                              Text(
                                                '${s.totalAverias}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: barColor,
                                                ),
                                              )
                                            else
                                              const SizedBox(height: 12),
                                            const SizedBox(height: 3),

                                            // Barra
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeOutCubic,
                                              width: colWidth * 0.45,
                                              height: barHeight.clamp(
                                                  2.0, chartHeight - 32),
                                              decoration: BoxDecoration(
                                                color: barColor,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                  top: Radius.circular(4),
                                                ),
                                              ),
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

                      const SizedBox(height: 8),

                      // Etiquetas del mes (Ene, Feb, Mar...) y MTTR
                      Row(
                        children: List.generate(stats.length, (index) {
                          final s = stats[index];
                          final isSelected =
                              selectedMonth.mesNumero == s.mesNumero;

                          return SizedBox(
                            width: colWidth,
                            child: Column(
                              children: [
                                Text(
                                  s.nombreMes.substring(0, 3),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.totalAverias > 0
                                      ? '${s.mttrHoras.toStringAsFixed(1)}h'
                                      : '—',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: s.totalAverias > 0
                                        ? const Color(0xFF0D9488)
                                        : const Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );

                if (isScrollable) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: chartContent,
                  );
                }
                return chartContent;
              },
            ),
          ),

          // Detalle interactivo del mes seleccionado
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildMonthDetailCallout(selectedMonth, isDark),
        ],
      ),
    );
  }

  Widget _buildChartGridLine(String label) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1)),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
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

  /// Tarjeta de desglose al hacer clic en un mes
  Widget _buildMonthDetailCallout(SeasonalityStat s, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF0284C7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Diagnóstico de ${s.nombreMes} $_selectedYear:',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildDetailTag('Averías Totales', '${s.totalAverias}', const Color(0xFFDC2626)),
              _buildDetailTag('MTTR Promedio', '${s.mttrHoras.toStringAsFixed(1)} h/falla', const Color(0xFF0D9488)),
              _buildDetailTag('OTs Correctivas', '${s.otsCorrectivas}', const Color(0xFFD97706)),
              _buildDetailTag('OTs Preventivas', '${s.otsPreventivas}', const Color(0xFF2563EB)),
              _buildDetailTag('Horas Taller', '${s.horasTotalesTaller} h', const Color(0xFF475569)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTag(String label, String value, Color color) {
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
          Text('$label: ', style: TextStyle(fontSize: 11, color: color)),
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

  /// Tabla Ejecutiva de Estacionalidad y Tiempos MTTR (Estilo de la Captura 2)
  Widget _buildSeasonalityTableCard({
    required List<SeasonalityStat> stats,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Matriz Mensual de Averías, MTTR y Tiempos de Taller',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '12 meses evaluados',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Tabla
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
              ),
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
              columnSpacing: 24,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(label: Text('Mes')),
                DataColumn(label: Text('Averías Reportadas')),
                DataColumn(label: Text('MTTR Promedio')),
                DataColumn(label: Text('OTs Correctivas')),
                DataColumn(label: Text('OTs Preventivas')),
                DataColumn(label: Text('Horas en Taller')),
                DataColumn(label: Text('Nivel de Riesgo')),
              ],
              rows: stats.map((s) {
                final isSelected =
                    _selectedSeasonalityMonthIndex == (s.mesNumero - 1);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedSeasonalityMonthIndex = s.mesNumero - 1;
                    });
                  },
                  cells: [
                    DataCell(
                      Text(
                        s.nombreMes,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${s.totalAverias}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.totalAverias > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (s.averiasCriticas > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${s.averiasCriticas} crít.',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.totalAverias > 0
                              ? const Color(0xFF0D9488).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s.totalAverias > 0
                              ? '${s.mttrHoras.toStringAsFixed(1)} hrs'
                              : '—',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: s.totalAverias > 0
                                ? const Color(0xFF0D9488)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text('${s.otsCorrectivas}')),
                    DataCell(Text('${s.otsPreventivas}')),
                    DataCell(
                      Text(
                        '${s.horasTotalesTaller} h',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    DataCell(_buildRiskLevelBadge(s)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLevelBadge(SeasonalityStat s) {
    if (s.totalAverias == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Óptimo',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF15803D),
          ),
        ),
      );
    }

    if (s.averiasCriticas > 0 || s.totalAverias >= 5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Pico Crítico',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC2626),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Moderado',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFFD97706),
        ),
      ),
    );
  }

  Widget _buildTopFailuresTab(List<TopFailureAsset> tops, bool isDark) {
    if (tops.isEmpty) {
      return const Center(
          child: Text('No hay averías registradas en este periodo'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.amber.withValues(alpha: 0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.pie_chart_outline, color: Colors.amber, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Principio de Pareto (80/20): Concentra la atención y recursos preventivos en los equipos que acumulan la mayor frecuencia de averías y horas de paro.',
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
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Equipo / Activo')),
              DataColumn(label: Text('Área')),
              DataColumn(label: Text('Averías')),
              DataColumn(label: Text('Críticas')),
              DataColumn(label: Text('% Pareto')),
              DataColumn(label: Text('% Acumulado')),
              DataColumn(label: Text('Acción')),
            ],
            rows: List.generate(tops.length, (index) {
              final t = tops[index];
              final ranking = index + 1;
              final pctAcumulado = tops
                  .take(index + 1)
                  .fold<double>(0.0, (sum, item) => sum + item.porcentajeDelTotalFallas);
              final isHighPareto = pctAcumulado <= 80.0;
              return DataRow(
                cells: [
                  DataCell(Text('$ranking')),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.codigoActivo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          t.nombreActivo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(t.nombreArea)),
                  DataCell(
                    Text(
                      '${t.totalAverias}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${t.averiasCriticas}',
                      style: TextStyle(
                        color: t.averiasCriticas > 0 ? Colors.red : null,
                        fontWeight: t.averiasCriticas > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  DataCell(Text('${t.porcentajeDelTotalFallas.toStringAsFixed(1)}%')),
                  DataCell(
                    Row(
                      children: [
                        Text(
                          '${pctAcumulado.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: isHighPareto
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isHighPareto ? Colors.red.shade700 : null,
                          ),
                        ),
                        if (isHighPareto) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.priority_high,
                              size: 14, color: Colors.red),
                        ],
                      ],
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      tooltip: 'Diagnóstico del Equipo',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssetHistoryAnalyticsView(
                              codigoActivo: t.codigoActivo,
                              nombreActivo: t.nombreActivo,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPartsConsumptionTab(List<PartReplacementStat> parts, bool isDark) {
    if (parts.isEmpty) {
      return const Center(child: Text('No hay repuestos registrados'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.teal.withValues(alpha: 0.08),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.teal, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rotación de Piezas: Identifica qué piezas se reemplazan con más frecuencia y el intervalo promedio en días para ajustar compras y preventivos.',
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
              DataColumn(label: Text('Pieza / Repuesto')),
              DataColumn(label: Text('Veces Reemplazado')),
              DataColumn(label: Text('Cantidad Total')),
              DataColumn(label: Text('Unidad')),
              DataColumn(label: Text('Intervalo Promedio')),
              DataColumn(label: Text('Último Recambio')),
            ],
            rows: parts.map((p) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      p.repuesto,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(Text('${p.vecesReemplazado}')),
                  DataCell(
                    Text(
                      p.cantidadTotalConsumida.toStringAsFixed(1),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(Text(p.unidad)),
                  DataCell(
                    Text(
                      p.diasPromedioEntreReemplazos != null
                          ? 'Cada ${p.diasPromedioEntreReemplazos!.toStringAsFixed(0)} días'
                          : '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Text(
                      p.ultimoReemplazo != null
                          ? p.ultimoReemplazo!
                              .toIso8601String()
                              .substring(0, 10)
                          : '—',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOeeTab(List<OeeGeneralRecord> records, bool isDark) {
    if (records.isEmpty) {
      return const Center(
          child: Text('No hay registros de OEE disponibles para este filtro'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.blue.withValues(alpha: 0.08),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.speed, color: Colors.blue, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'OEE (Overall Equipment Effectiveness) = Disponibilidad% × Rendimiento% × Calidad%. Mide la efectividad real del equipo en planta.',
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
              DataColumn(label: Text('Equipo')),
              DataColumn(label: Text('Área')),
              DataColumn(label: Text('Disponibilidad')),
              DataColumn(label: Text('Rendimiento')),
              DataColumn(label: Text('Calidad')),
              DataColumn(label: Text('OEE')),
              DataColumn(label: Text('Nivel')),
            ],
            rows: records.map((r) {
              final oee = r.oeePct;
              final isGood = oee >= 85.0;
              final isMedium = oee >= 65.0 && oee < 85.0;

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          r.codigoActivo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          r.nombreActivo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(r.nombreArea)),
                  DataCell(Text('${r.disponibilidadPct.toStringAsFixed(1)}%')),
                  DataCell(Text('${r.rendimientoPct.toStringAsFixed(1)}%')),
                  DataCell(Text('${r.calidadPct.toStringAsFixed(1)}%')),
                  DataCell(
                    Text(
                      '${oee.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isGood
                            ? Colors.green.shade700
                            : (isMedium ? Colors.amber.shade800 : Colors.red),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isGood
                            ? Colors.green.shade50
                            : (isMedium
                                ? Colors.amber.shade50
                                : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isGood
                            ? 'Clase Mundial'
                            : (isMedium ? 'Aceptable' : 'Bajo'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isGood
                              ? Colors.green.shade800
                              : (isMedium
                                  ? Colors.amber.shade900
                                  : Colors.red.shade800),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
