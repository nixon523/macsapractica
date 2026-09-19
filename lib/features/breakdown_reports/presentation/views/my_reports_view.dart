import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/my_reports_viewmodel.dart';

enum _MyReportTab { all, open, inWorkOrder, resolved, rejected }

class MyReportsView extends StatefulWidget {
  const MyReportsView({super.key});

  @override
  State<MyReportsView> createState() => _MyReportsViewState();
}

class _MyReportsViewState extends State<MyReportsView> {
  _MyReportTab _tab = _MyReportTab.all;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPreset = 'mes';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      context.read<MyReportsViewModel>().load(user.userId);
    }
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'hoy':
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'ayer':
          final yesterday = now.subtract(const Duration(days: 1));
          _startDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
          _endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
          break;
        case '7dias':
          final sevenDaysAgo = now.subtract(const Duration(days: 6));
          _startDate = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'mes':
          _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'todo':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month, now.day),
            ),
      helpText: 'Seleccionar Rango de Fechas (Desde - Hasta)',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar Filtro',
    );
    if (picked != null) {
      setState(() {
        _selectedPreset = 'personalizado';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  List<BreakdownReport> _filterReports(List<BreakdownReport> list) {
    var filtered = list;

    // 1. Filtro de Fechas
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((r) {
        final d = r.reportedAt;
        if (d == null) return false;
        if (_startDate != null && d.isBefore(_startDate!)) return false;
        if (_endDate != null && d.isAfter(_endDate!)) return false;
        return true;
      }).toList();
    }

    // 2. Filtro de Pestaña / Estado
    filtered = switch (_tab) {
      _MyReportTab.all => filtered,
      _MyReportTab.open => filtered.where((r) => r.status == BreakdownReportStatus.reported).toList(),
      _MyReportTab.inWorkOrder => filtered.where((r) => r.status == BreakdownReportStatus.inWorkOrder).toList(),
      _MyReportTab.resolved => filtered.where((r) => r.status == BreakdownReportStatus.resolved).toList(),
      _MyReportTab.rejected => filtered.where((r) => r.status == BreakdownReportStatus.rejected).toList(),
    };

    // 3. Filtro de Búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final assetId = r.assetId.toLowerCase();
        final assetName = r.assetName.toLowerCase();
        final areaId = r.areaId.toLowerCase();
        final desc = r.description.toLowerCase();
        final ot = (r.workOrderId ?? '').toLowerCase();
        final reason = (r.rejectionReason ?? '').toLowerCase();

        return assetId.contains(_searchQuery) ||
            assetName.contains(_searchQuery) ||
            areaId.contains(_searchQuery) ||
            desc.contains(_searchQuery) ||
            ot.contains(_searchQuery) ||
            reason.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MyReportsViewModel>();
    final isNarrow = MediaQuery.of(context).size.width < 750;

    final allReports = vm.reports;
    final filteredReports = _filterReports(allReports);

    // Contadores para chips de estado dentro del rango de fecha seleccionado
    final dateFilteredReports = (_startDate != null || _endDate != null)
        ? allReports.where((r) {
            final d = r.reportedAt;
            if (d == null) return false;
            if (_startDate != null && d.isBefore(_startDate!)) return false;
            if (_endDate != null && d.isAfter(_endDate!)) return false;
            return true;
          }).toList()
        : allReports;

    final openCount = dateFilteredReports.where((r) => r.status == BreakdownReportStatus.reported).length;
    final inOtCount = dateFilteredReports.where((r) => r.status == BreakdownReportStatus.inWorkOrder).length;
    final resolvedCount = dateFilteredReports.where((r) => r.status == BreakdownReportStatus.resolved).length;
    final rejectedCount = dateFilteredReports.where((r) => r.status == BreakdownReportStatus.rejected).length;

    return Scaffold(
      body: Column(
        children: [
          _buildFilterSection(
            isNarrow: isNarrow,
            totalCount: dateFilteredReports.length,
            openCount: openCount,
            inOtCount: inOtCount,
            resolvedCount: resolvedCount,
            rejectedCount: rejectedCount,
          ),
          const Divider(height: 1),
          _buildSummaryBar(
            filteredCount: filteredReports.length,
            totalCount: allReports.length,
            openCount: openCount,
          ),
          Expanded(
            child: switch (vm.viewState) {
              MyReportsViewState.initial ||
              MyReportsViewState.loading =>
                const Center(child: CircularProgressIndicator()),
              MyReportsViewState.error => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text('Error al cargar reportes: ${vm.errorMessage}'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              MyReportsViewState.success => filteredReports.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: 56,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Sin resultados para "$_searchQuery"'
                                  : allReports.isEmpty
                                      ? 'Aún no has reportado averías.'
                                      : 'No hay reportes que coincidan con los filtros.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Intenta con otro término o limpia la barra de búsqueda.'
                                  : 'Prueba cambiando el rango de fechas o el filtro de estado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_selectedPreset != 'todo' || _tab != _MyReportTab.all || _searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _searchCtrl.clear();
                                    _tab = _MyReportTab.all;
                                    _applyPreset('todo');
                                  });
                                },
                                icon: const Icon(Icons.clear_all, size: 18),
                                label: const Text('Limpiar todos los filtros'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadData(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) =>
                            _ModernMyReportCard(report: filteredReports[index]),
                      ),
                    ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required bool isNarrow,
    required int totalCount,
    required int openCount,
    required int inOtCount,
    required int resolvedCount,
    required int rejectedCount,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Selector de Fechas y Presets
          if (!isNarrow)
            Row(
              children: [
                _buildDateRangeButton(),
                const SizedBox(width: 12),
                Expanded(child: _buildPresetsRow()),
              ],
            )
          else ...[
            _buildDateRangeButton(),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildPresetsRow(),
            ),
          ],
          const SizedBox(height: 10),

          // Fila 2: Búsqueda y Chips de Estado
          if (!isNarrow)
            Row(
              children: [
                Expanded(flex: 3, child: _buildSearchBar()),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _buildStatusChips(
                    totalCount: totalCount,
                    openCount: openCount,
                    inOtCount: inOtCount,
                    resolvedCount: resolvedCount,
                    rejectedCount: rejectedCount,
                    scrollable: false,
                  ),
                ),
              ],
            )
          else ...[
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildStatusChips(
              totalCount: totalCount,
              openCount: openCount,
              inOtCount: inOtCount,
              resolvedCount: resolvedCount,
              rejectedCount: rejectedCount,
              scrollable: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRangeButton() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    String label;
    if (_startDate == null && _endDate == null) {
      label = 'Todo el historial';
    } else if (_startDate != null && _endDate != null) {
      final s = _startDate!;
      final e = _endDate!;
      if (s.year == e.year && s.month == e.month && s.day == e.day) {
        label = 'Hoy: ${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')}/${s.year}';
      } else {
        label = '${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')}/${s.year} '
            '➔ ${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}';
      }
    } else {
      label = 'Filtrar rango';
    }

    return OutlinedButton.icon(
      onPressed: _selectDateRange,
      icon: Icon(Icons.calendar_today_outlined, size: 18, color: colors.primary),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: colors.onSurface,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: colors.surfaceContainerLowest,
      ),
    );
  }

  Widget _buildPresetsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPresetChip('hoy', 'Hoy'),
        const SizedBox(width: 6),
        _buildPresetChip('ayer', 'Ayer'),
        const SizedBox(width: 6),
        _buildPresetChip('7dias', '7 días'),
        const SizedBox(width: 6),
        _buildPresetChip('mes', 'Este mes'),
        const SizedBox(width: 6),
        _buildPresetChip('todo', 'Todo'),
      ],
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final isSelected = _selectedPreset == key;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyPreset(key),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
      ),
      selectedColor: colors.primary,
      backgroundColor: colors.surfaceContainerLow,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar por equipo, código, motivo o # OT…',
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => _searchCtrl.clear(),
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildStatusChips({
    required int totalCount,
    required int openCount,
    required int inOtCount,
    required int resolvedCount,
    required int rejectedCount,
    required bool scrollable,
  }) {
    final categories = <(_MyReportTab, String, IconData, Color)>[
      (_MyReportTab.all, 'Todas ($totalCount)', Icons.all_inbox_outlined, const Color(0xFF0055A5)),
      (_MyReportTab.open, 'En Revisión ($openCount)', Icons.report_problem_outlined, const Color(0xFFC2410C)),
      (_MyReportTab.inWorkOrder, 'Con OT ($inOtCount)', Icons.engineering_outlined, const Color(0xFF2563EB)),
      (_MyReportTab.resolved, 'Resueltas ($resolvedCount)', Icons.check_circle_outline, const Color(0xFF15803D)),
      (_MyReportTab.rejected, 'Rechazadas ($rejectedCount)', Icons.cancel_outlined, const Color(0xFFDC2626)),
    ];

    final chips = categories.map((item) {
      final isSelected = _tab == item.$1;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;

      return FilterChip(
        avatar: Icon(
          item.$3,
          size: 15,
          color: isSelected ? Colors.white : item.$4,
        ),
        label: Text(item.$2),
        selected: isSelected,
        onSelected: (_) => setState(() => _tab = item.$1),
        selectedColor: item.$4,
        backgroundColor: colors.surfaceContainerLow,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : colors.onSurface,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)).toList(),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildSummaryBar({
    required int filteredCount,
    required int totalCount,
    required int openCount,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final hasActiveFilter = _selectedPreset != 'todo' ||
        _tab != _MyReportTab.all ||
        _searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            '$filteredCount de $totalCount reporte(s)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: 10),
          if (openCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$openCount en revisión',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC2410C),
                ),
              ),
            ),
          const Spacer(),
          if (hasActiveFilter) ...[
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                  _tab = _MyReportTab.all;
                  _applyPreset('todo');
                });
              },
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('Limpiar filtros', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ] else ...[
            Text(
              'Orden cronológico',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModernMyReportCard extends StatelessWidget {
  const _ModernMyReportCard({required this.report});

  final BreakdownReport report;

  @override
  Widget build(BuildContext context) {
    final (sevColor, sevBg, sevLabel) = switch (report.severity) {
      BreakdownSeverity.low => (const Color(0xFF15803D), const Color(0xFFDCFCE7), 'Severidad Baja'),
      BreakdownSeverity.medium => (const Color(0xFFB45309), const Color(0xFFFEF3C7), 'Severidad Media'),
      BreakdownSeverity.high => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), 'Severidad Alta'),
    };

    final (statusColor, statusBg, statusLabel, statusIcon) = switch (report.status) {
      BreakdownReportStatus.reported => (
          const Color(0xFFC2410C),
          const Color(0xFFFFEDD5),
          'En Revisión',
          Icons.error_outline,
        ),
      BreakdownReportStatus.inWorkOrder => (
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          'OT Asignada',
          Icons.engineering_outlined,
        ),
      BreakdownReportStatus.resolved => (
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
          'Resuelta',
          Icons.check_circle_outline,
        ),
      BreakdownReportStatus.rejected => (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          'Rechazada',
          Icons.block_outlined,
        ),
    };

    final dateStr = report.reportedAt != null
        ? '${report.reportedAt!.day.toString().padLeft(2, '0')}/${report.reportedAt!.month.toString().padLeft(2, '0')}/${report.reportedAt!.year} '
            '${report.reportedAt!.hour.toString().padLeft(2, '0')}:'
            '${report.reportedAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: report.status == BreakdownReportStatus.reported
              ? const Color(0xFFFED7AA)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Ícono, Activo, Área y Chip de Estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: sevBg,
                  child: Icon(
                    Icons.precision_manufacturing_outlined,
                    color: sevColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              report.assetId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Text(
                            report.assetName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Área ${report.areaId}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0055A5),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: sevBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sevLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: sevColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cuadro de Descripción de la avería
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalle de la falla:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // En caso de rechazo: Alerta explicativa
            if (report.status == BreakdownReportStatus.rejected) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF991B1B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motivo de rechazo: ${report.rejectionReason ?? "Sin motivo especificado"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Fila inferior: Fecha y Orden de Trabajo (si existe)
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  'Reportado el $dateStr',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (report.workOrderId != null && report.workOrderId!.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment, size: 12, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Text(
                          'OT: ${report.workOrderId}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
