import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../work_orders/presentation/views/work_order_create_view.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/breakdown_reports_viewmodel.dart';

enum _ReportTab { open, resolved, rejected, all }

/// Vista ejecutiva y profesional de Reportes de Averías basada en el estándar del Kardex.
class BreakdownReportsView extends StatefulWidget {
  const BreakdownReportsView({super.key});

  @override
  State<BreakdownReportsView> createState() => _BreakdownReportsViewState();
}

class _BreakdownReportsViewState extends State<BreakdownReportsView> {
  _ReportTab _tab = _ReportTab.open;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  late DateTime? _startDate;
  late DateTime? _endDate;
  String _selectedPreset = 'hoy';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
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
    context.read<BreakdownReportsViewModel>().load(
          startDate: _startDate,
          endDate: _endDate,
        );
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
    _loadData();
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
              start: DateTime(now.year, now.month, now.day),
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
      _loadData();
    }
  }

  Future<void> _generateWorkOrder(BreakdownReport report) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => WorkOrderCreateView(report: report),
      ),
    );

    if (created == true && mounted) {
      _loadData();
    }
  }

  Future<void> _confirmReject(BreakdownReport report) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectReportDialog(report: report),
    );
    if (reason == null || !mounted) return;

    final viewModel = context.read<BreakdownReportsViewModel>();
    final ok = await viewModel.reject(
      report: report,
      reason: reason,
      rejectedByUserId: user.userId,
      rejectedByUserName: user.username,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Reporte rechazado.' : 'Error: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  List<BreakdownReport> _filterReports(List<BreakdownReport> list) {
    var filtered = switch (_tab) {
      _ReportTab.open => list.where((r) => r.status == BreakdownReportStatus.reported).toList(),
      _ReportTab.resolved => list.where((r) => r.status == BreakdownReportStatus.resolved || r.status == BreakdownReportStatus.inWorkOrder).toList(),
      _ReportTab.rejected => list.where((r) => r.status == BreakdownReportStatus.rejected).toList(),
      _ReportTab.all => list,
    };

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final assetId = r.assetId.toLowerCase();
        final assetName = r.assetName.toLowerCase();
        final areaId = r.areaId.toLowerCase();
        final desc = r.description.toLowerCase();
        final reporter = r.reportedByUserName.toLowerCase();
        final ot = (r.workOrderId ?? '').toLowerCase();

        return assetId.contains(_searchQuery) ||
            assetName.contains(_searchQuery) ||
            areaId.contains(_searchQuery) ||
            desc.contains(_searchQuery) ||
            reporter.contains(_searchQuery) ||
            ot.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BreakdownReportsViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final canManage = authVm.hasPermission('breakdown.manage');

    final allReports = [...vm.openReports, ...vm.resolvedReports, ...vm.rejectedReports];
    final filteredReports = _filterReports(allReports);

    return Scaffold(
      body: Column(
        children: [
          _buildFilterSection(
            isNarrow: MediaQuery.of(context).size.width < 750,
            openCount: vm.openReports.length,
            resolvedCount: vm.resolvedReports.length,
            rejectedCount: vm.rejectedReports.length,
          ),
          const Divider(height: 1),
          _buildSummaryBar(filteredReports.length, vm.openReports.length),
          Expanded(
            child: switch (vm.viewState) {
              BreakdownReportsViewState.initial ||
              BreakdownReportsViewState.loading =>
                const Center(child: CircularProgressIndicator()),
              BreakdownReportsViewState.error => Center(
                  child: Text('Error: ${vm.errorMessage}'),
                ),
              BreakdownReportsViewState.success => filteredReports.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bug_report_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Sin resultados para "$_searchQuery"'
                                  : 'No hay averías registradas en este periodo.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Intenta con otro término o limpia la barra de búsqueda.'
                                  : 'Prueba cambiando el rango de fechas o el filtro de estado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            if (_selectedPreset != 'todo') ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _applyPreset('todo'),
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('Ver todas las averías'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadData(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          return _ModernReportCard(
                            report: report,
                            isProcessing: vm.isProcessing,
                            canGenerateOt: canManage,
                            canReject: canManage,
                            onGenerateOt: () => _generateWorkOrder(report),
                            onReject: () => _confirmReject(report),
                          );
                        },
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
    required int openCount,
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
          // Fila 1: Selector de Fechas (Desde - Hasta) y Presets
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
                    openCount: openCount,
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
              openCount: openCount,
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
        hintText: 'Buscar por equipo, código, motivo o reportero…',
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
    required int openCount,
    required int resolvedCount,
    required int rejectedCount,
    required bool scrollable,
  }) {
    final categories = <(_ReportTab, String, IconData, Color)>[
      (_ReportTab.open, 'Abiertas ($openCount)', Icons.report_problem_outlined, const Color(0xFFC2410C)),
      (_ReportTab.resolved, 'Resueltas ($resolvedCount)', Icons.check_circle_outline, const Color(0xFF15803D)),
      (_ReportTab.rejected, 'Rechazadas ($rejectedCount)', Icons.cancel_outlined, const Color(0xFFDC2626)),
      (_ReportTab.all, 'Todas', Icons.all_inbox_outlined, const Color(0xFF1E293B)),
    ];

    final chips = categories.map((item) {
      final isSelected = _tab == item.$1;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;

      return FilterChip(
        avatar: Icon(
          item.$3,
          size: 16,
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

  Widget _buildSummaryBar(int count, int openCount) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.bug_report_outlined, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            '$count reporte(s) de avería',
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
                '$openCount pendiente(s)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
              ),
            ),
          const Spacer(),
          Text(
            'Orden cronológico',
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta ejecutiva para cada Reporte de Avería con franja lateral de severidad.
class _ModernReportCard extends StatelessWidget {
  const _ModernReportCard({
    required this.report,
    required this.isProcessing,
    required this.canGenerateOt,
    required this.canReject,
    required this.onGenerateOt,
    required this.onReject,
  });

  final BreakdownReport report;
  final bool isProcessing;
  final bool canGenerateOt;
  final bool canReject;
  final VoidCallback onGenerateOt;
  final VoidCallback onReject;

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final dayStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final diff = now.difference(dt);
    String relative;
    if (diff.inMinutes < 1) {
      relative = 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      relative = 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      relative = 'Hoy a las $timeStr';
    } else if (diff.inDays == 1 || (diff.inHours < 48 && dt.day == now.subtract(const Duration(days: 1)).day)) {
      relative = 'Ayer a las $timeStr';
    } else {
      relative = '$dayStr $timeStr';
    }

    return relative;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
          report.workOrderId != null ? 'En ${report.workOrderId}' : 'En OT',
          Icons.engineering_outlined,
        ),
      BreakdownReportStatus.resolved => (
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7),
          'Resuelta',
          Icons.check_circle_outline,
        ),
      BreakdownReportStatus.rejected => (
          const Color(0xFF475569),
          const Color(0xFFF1F5F9),
          'Rechazada',
          Icons.cancel_outlined,
        ),
    };

    final reportedDateStr = _formatTimestamp(report.reportedAt);
    final fullDate = report.reportedAt != null
        ? '${report.reportedAt!.day.toString().padLeft(2, '0')}/${report.reportedAt!.month.toString().padLeft(2, '0')}/${report.reportedAt!.year} ${report.reportedAt!.hour.toString().padLeft(2, '0')}:${report.reportedAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Franja lateral con acento de color de severidad
            Container(
              width: 5,
              color: sevColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Código, Equipo, Badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: sevColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(statusIcon, size: 18, color: sevColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: theme.colorScheme.outlineVariant),
                                    ),
                                    child: Text(
                                      report.assetId,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sevBg,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      sevLabel,
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: sevColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${report.assetName} · Área: ${report.areaId}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Descripción de la avería
                    Text(
                      report.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),

                    if (report.rejectionReason != null && report.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Motivo del rechazo: ${report.rejectionReason}',
                          style: TextStyle(fontSize: 11.5, color: Colors.red.shade900, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Footer: Usuario y fecha
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  report.reportedByUserName,
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Tooltip(
                              message: fullDate,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    reportedDateStr,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (report.status == BreakdownReportStatus.reported)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (canReject)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onPressed: isProcessing ? null : onReject,
                                  icon: const Icon(Icons.close, size: 15),
                                  label: const Text('Rechazar', style: TextStyle(fontSize: 11.5)),
                                ),
                              if (canGenerateOt)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onPressed: isProcessing ? null : onGenerateOt,
                                  icon: const Icon(Icons.assignment_add, size: 15),
                                  label: const Text('Generar OT', style: TextStyle(fontSize: 11.5)),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectReportDialog extends StatefulWidget {
  const _RejectReportDialog({required this.report});

  final BreakdownReport report;

  @override
  State<_RejectReportDialog> createState() => _RejectReportDialogState();
}

class _RejectReportDialogState extends State<_RejectReportDialog> {
  final _reasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar reporte de avería'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Equipo: ${widget.report.assetId} — ${widget.report.assetName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo *',
                hintText: 'Explica por qué no procede esta avería...',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El motivo es obligatorio' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reasonCtrl.text.trim());
            }
          },
          child: const Text('Rechazar reporte'),
        ),
      ],
    );
  }
}
