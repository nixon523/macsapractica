import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../features/assets/domain/entities/area.dart';
import '../../../../features/assets/domain/usecases/get_areas_usecase.dart';
import '../../../../app/di/get_it.dart';
import '../../domain/entities/operation_report.dart';
import '../viewmodels/operation_report_viewmodel.dart';
import 'operation_report_form_view.dart';
import 'operation_report_metrics_view.dart';

/// Vista principal del módulo de Disponibilidad y Tiempos de Operación.
/// Soporta vista semanal día por día y vista mensual consolidada con búsqueda ágil.
class OperationReportListView extends StatefulWidget {
  const OperationReportListView({super.key});

  static const routeName = '/operation-reports';

  @override
  State<OperationReportListView> createState() =>
      _OperationReportListViewState();
}

class _OperationReportListViewState extends State<OperationReportListView> {
  List<Area> _areas = [];
  String? _selectedAreaId;
  String? _selectedAreaName;

  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    final vm = context.read<OperationReportViewModel>();
    _selectedAreaId = vm.selectedAreaId;
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    try {
      final areas = await getIt<GetAreasUseCase>().call(const NoParams());
      if (mounted) {
        setState(() {
          _areas = areas;
          final vm = context.read<OperationReportViewModel>();
          if (vm.selectedAreaId != null) {
            final matched = areas.where((a) => a.id == vm.selectedAreaId);
            if (matched.isNotEmpty) {
              _selectedAreaId = matched.first.id;
              _selectedAreaName = matched.first.name;
            }
          }
        });
      }
    } catch (_) {}
  }

  void _selectArea(String id, String name) {
    setState(() {
      _selectedAreaId = id;
      _selectedAreaName = name;
    });
    final vm = context.read<OperationReportViewModel>();
    vm.seleccionarArea(id);
  }

  void _openAreaSearchDialog() {
    showDialog<Area>(
      context: context,
      builder: (ctx) => _AreaSearchDialog(areas: _areas),
    ).then((selected) {
      if (selected != null) {
        _selectArea(selected.id, selected.name);
      }
    });
  }

  Future<void> _pickDateOrMonth(BuildContext context, OperationReportViewModel vm) async {
    if (vm.viewMode == OperationReportViewMode.weekly) {
      final picked = await showDatePicker(
        context: context,
        initialDate: vm.currentMonday,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        helpText: 'Seleccionar Fecha / Semana',
        cancelText: 'Cancelar',
        confirmText: 'Seleccionar',
      );
      if (picked != null) {
        vm.seleccionarFecha(picked);
      }
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: vm.selectedMonth,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDatePickerMode: DatePickerMode.year,
        helpText: 'Seleccionar Mes',
        cancelText: 'Cancelar',
        confirmText: 'Seleccionar Mes',
      );
      if (picked != null) {
        vm.seleccionarMes(DateTime(picked.year, picked.month, 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OperationReportViewModel>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isLoading = vm.viewMode == OperationReportViewMode.weekly
        ? vm.loadingWeekly
        : vm.loadingMonthly;
    final currentError = vm.viewMode == OperationReportViewMode.weekly
        ? vm.weeklyError
        : vm.monthlyError;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Disponibilidad Operativa'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _selectedAreaId == null
                ? null
                : () {
                    if (vm.viewMode == OperationReportViewMode.weekly) {
                      vm.cargarSemana(_selectedAreaId!);
                    } else {
                      vm.cargarMes(_selectedAreaId!);
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de Área Limpio y Buscable
          _AreaHeaderSelector(
            selectedAreaId: _selectedAreaId,
            selectedAreaName: _selectedAreaName,
            onOpenSearch: _openAreaSearchDialog,
          ),

          // Barra de Control Temporal y Modos de Vista
          _TimeNavigationControlBar(
            vm: vm,
            onPickDate: () => _pickDateOrMonth(context, vm),
          ),

          // Contenido Principal (Semanal o Mensual)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : currentError != null
                    ? Center(
                        child: Text(
                          currentError,
                          style: TextStyle(color: colors.error),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : (vm.viewMode == OperationReportViewMode.weekly &&
                            vm.weeklyReports.isEmpty) ||
                        (vm.viewMode == OperationReportViewMode.monthly &&
                            vm.monthlySummaries.isEmpty)
                        ? _EmptyState(areaName: _selectedAreaName)
                        : vm.viewMode == OperationReportViewMode.weekly
                            ? _WeeklyGrid(
                                vm: vm,
                                areaId: _selectedAreaId ?? '',
                                dias: _dias,
                              )
                            : _MonthlyGrid(
                                vm: vm,
                                areaId: _selectedAreaId ?? '',
                              ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selector de Área Tipo Tarjeta Buscable (Sin Checkboxes)
// ---------------------------------------------------------------------------
class _AreaHeaderSelector extends StatelessWidget {
  const _AreaHeaderSelector({
    required this.selectedAreaId,
    required this.selectedAreaName,
    required this.onOpenSearch,
  });

  final String? selectedAreaId;
  final String? selectedAreaName;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.primaryContainer.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.factory_outlined, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ÁREA DE PROCESO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedAreaId != null
                      ? '$selectedAreaId - ${selectedAreaName ?? ''}'
                      : 'Seleccionar Área...',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onOpenSearch,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Buscar Área'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogo de Búsqueda Interactiva de Áreas
// ---------------------------------------------------------------------------
class _AreaSearchDialog extends StatefulWidget {
  const _AreaSearchDialog({required this.areas});
  final List<Area> areas;

  @override
  State<_AreaSearchDialog> createState() => _AreaSearchDialogState();
}

class _AreaSearchDialogState extends State<_AreaSearchDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = widget.areas.where((a) {
      final q = _query.toLowerCase().trim();
      if (q.isEmpty) return true;
      return a.id.toLowerCase().contains(q) || a.name.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.factory, color: Color(0xFF0288D1)),
          SizedBox(width: 8),
          Text('Seleccionar Área de Proceso'),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por código (A001) o nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No se encontraron áreas coincidentes.'),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final area = filtered[idx];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              area.id,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            area.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          onTap: () => Navigator.of(context).pop(area),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Barra de Control Temporal y Modos de Vista
// ---------------------------------------------------------------------------
class _TimeNavigationControlBar extends StatelessWidget {
  const _TimeNavigationControlBar({
    required this.vm,
    required this.onPickDate,
  });

  final OperationReportViewModel vm;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isWeekly = vm.viewMode == OperationReportViewMode.weekly;

    return Container(
      color: colors.primaryContainer.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          // Conmutador Semanal / Mensual
          SegmentedButton<OperationReportViewMode>(
            segments: const [
              ButtonSegment(
                value: OperationReportViewMode.weekly,
                label: Text('Semanal'),
                icon: Icon(Icons.calendar_view_week, size: 16),
              ),
              ButtonSegment(
                value: OperationReportViewMode.monthly,
                label: Text('Mensual'),
                icon: Icon(Icons.calendar_month, size: 16),
              ),
            ],
            selected: {vm.viewMode},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) {
                vm.setViewMode(set.first);
              }
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

          // Navegación de período (Semana o Mes)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: (isWeekly ? vm.loadingWeekly : vm.loadingMonthly)
                    ? null
                    : () {
                        if (isWeekly) {
                          vm.irSemanaAnterior();
                        } else {
                          vm.irMesAnterior();
                        }
                      },
                tooltip: isWeekly ? 'Semana anterior' : 'Mes anterior',
              ),
              InkWell(
                onTap: onPickDate,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        isWeekly ? vm.weekLabel : vm.monthLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: (isWeekly ? vm.loadingWeekly : vm.loadingMonthly)
                    ? null
                    : () {
                        if (isWeekly) {
                          vm.irSemanaSiguiente();
                        } else {
                          vm.irMesSiguiente();
                        }
                      },
                tooltip: isWeekly ? 'Semana siguiente' : 'Mes siguiente',
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => vm.irHoy(),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.today, size: 14),
                label: const Text('Hoy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cuadrícula Semanal
// ---------------------------------------------------------------------------
class _WeeklyGrid extends StatelessWidget {
  const _WeeklyGrid({
    required this.vm,
    required this.areaId,
    required this.dias,
  });
  final OperationReportViewModel vm;
  final String areaId;
  final List<String> dias;

  Color _colorFromDisp(double pct) {
    if (pct >= 85) return const Color(0xFF2ECC71);
    if (pct >= 60) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final equipos = vm.weeklyReports.keys.toList();
    final monday = vm.currentMonday;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            colors.primaryContainer.withValues(alpha: 0.4),
          ),
          columnSpacing: 12,
          columns: [
            const DataColumn(label: Text('Equipo')),
            ...List.generate(7, (i) {
              final d = monday.add(Duration(days: i));
              final isToday = _sameDay(d, DateTime.now());
              return DataColumn(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dias[i],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isToday ? colors.primary : null,
                      ),
                    ),
                    Text(
                      '${d.day}/${d.month}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isToday ? colors.primary : colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const DataColumn(label: Text('% Disp.')),
            const DataColumn(label: Text('')),
          ],
          rows: equipos.map((codigo) {
            final reportes = vm.weeklyReports[codigo] ?? [];
            final nombre = reportes.isNotEmpty
                ? reportes.first.nombreActivo
                : codigo;

            double totalOp = 0, totalJornada = 0;
            for (final r in reportes) {
              if (r.tieneReporte) {
                totalOp += r.horasOperacion;
                totalJornada += r.horasTotalesJornada;
              }
            }
            final dispSemana = totalJornada > 0
                ? (totalOp / totalJornada * 100).clamp(0.0, 100.0)
                : 0.0;

            return DataRow(
              cells: [
                DataCell(
                  Tooltip(
                    message: '$codigo - $nombre',
                    child: SizedBox(
                      width: 250,
                      child: Text(
                        nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
                ...List.generate(7, (i) {
                  final dia = monday.add(Duration(days: i));
                  final reporte = reportes.cast<OperationReport?>().firstWhere(
                        (r) => r != null && _sameDay(r.fechaOperacion, dia),
                        orElse: () => null,
                      );
                  final tieneReporte = reporte?.tieneReporte ?? false;

                  return DataCell(
                    InkWell(
                      onTap: () => _openForm(context, codigo, nombre, dia, reporte, areaId),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: tieneReporte
                              ? _colorFromDisp(reporte!.disponibilidad).withValues(alpha: 0.15)
                              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: Border.all(
                            color: tieneReporte
                                ? _colorFromDisp(reporte!.disponibilidad)
                                : colors.outline.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: tieneReporte
                              ? Text(
                                  '${reporte!.disponibilidad.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _colorFromDisp(reporte.disponibilidad),
                                  ),
                                )
                              : Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                  color: colors.outline,
                                ),
                        ),
                      ),
                    ),
                  );
                }),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _colorFromDisp(dispSemana).withValues(alpha: 0.15),
                    ),
                    child: Text(
                      '${dispSemana.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _colorFromDisp(dispSemana),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    tooltip: 'Ver métricas',
                    onPressed: () => _openMetrics(context, codigo, nombre),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openForm(
    BuildContext context,
    String codigoActivo,
    String nombreActivo,
    DateTime fecha,
    OperationReport? existing,
    String areaId,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<OperationReportViewModel>(),
          child: OperationReportFormView(
            codigoActivo: codigoActivo,
            nombreActivo: nombreActivo,
            areaId: areaId,
            fecha: fecha,
            existing: existing,
          ),
        ),
      ),
    );
  }

  void _openMetrics(BuildContext context, String codigo, String nombre) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<OperationReportViewModel>(),
          child: OperationReportMetricsView(
            codigoActivo: codigo,
            nombreActivo: nombre,
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Cuadrícula Mensual Consolidada
// ---------------------------------------------------------------------------
class _MonthlyGrid extends StatelessWidget {
  const _MonthlyGrid({
    required this.vm,
    required this.areaId,
  });

  final OperationReportViewModel vm;
  final String areaId;

  Color _colorFromDisp(double pct) {
    if (pct >= 85) return const Color(0xFF2ECC71);
    if (pct >= 60) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summaries = vm.monthlySummaries;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            colors.primaryContainer.withValues(alpha: 0.4),
          ),
          columnSpacing: 14,
          columns: const [
            DataColumn(label: Text('Equipo')),
            DataColumn(label: Text('Días Reportados')),
            DataColumn(label: Text('Horas Jornada')),
            DataColumn(label: Text('Horas Operación')),
            DataColumn(label: Text('Paros Falla')),
            DataColumn(label: Text('Paros Mant.')),
            DataColumn(label: Text('Paros Plan./Ext.')),
            DataColumn(label: Text('% Disp. Mensual')),
            DataColumn(label: Text('')),
          ],
          rows: summaries.map((s) {
            final parosMant = s.horasParoMantPrev + s.horasParoMantCorr;
            final parosPlanExt = s.horasParoPlanificado + s.horasParoExterno;

            return DataRow(
              cells: [
                DataCell(
                  Tooltip(
                    message: '${s.codigoActivo} - ${s.nombreActivo}',
                    child: SizedBox(
                      width: 250,
                      child: Text(
                        s.nombreActivo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text('${s.reportesRegistrados} / ${s.diasDelMes} días'),
                ),
                DataCell(
                  Text('${s.horasTotalesJornada.toStringAsFixed(1)} h'),
                ),
                DataCell(
                  Text(
                    '${s.horasOperacion.toStringAsFixed(1)} h',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Text(
                    '${s.horasParoFalla.toStringAsFixed(1)} h',
                    style: TextStyle(
                      color: s.horasParoFalla > 0 ? Colors.red.shade700 : null,
                    ),
                  ),
                ),
                DataCell(
                  Text('${parosMant.toStringAsFixed(1)} h'),
                ),
                DataCell(
                  Text('${parosPlanExt.toStringAsFixed(1)} h'),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _colorFromDisp(s.disponibilidadPct).withValues(alpha: 0.15),
                    ),
                    child: Text(
                      '${s.disponibilidadPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _colorFromDisp(s.disponibilidadPct),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    tooltip: 'Ver métricas detalladas',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: context.read<OperationReportViewModel>(),
                            child: OperationReportMetricsView(
                              codigoActivo: s.codigoActivo,
                              nombreActivo: s.nombreActivo,
                            ),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.areaName});
  final String? areaName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.factory_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            areaName != null
                ? 'No hay equipos de proceso en "$areaName"'
                : 'Selecciona un área para ver los reportes',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Marca un activo de primer nivel como "Equipo de proceso"\nen la vista de detalle del activo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
