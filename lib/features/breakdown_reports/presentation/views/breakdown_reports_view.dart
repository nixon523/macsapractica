import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../work_orders/presentation/views/work_order_create_view.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/breakdown_reports_viewmodel.dart';

enum _ReportTab { open, resolved, rejected, all }

/// Vista ejecutiva, ultra-limpia y responsive de la Bandeja de Averías.
/// Diseñada bajo principios de diseño minimalista industrial (SaaS moderno)
/// con alta legibilidad, soporte para pantallas móviles (Android) y web.
class BreakdownReportsView extends StatefulWidget {
  const BreakdownReportsView({super.key});

  @override
  State<BreakdownReportsView> createState() => _BreakdownReportsViewState();
}

class _BreakdownReportsViewState extends State<BreakdownReportsView> {
  _ReportTab _tab = _ReportTab.open;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
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
      helpText: 'Filtrar por Rango de Fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: ok ? const Color(0xFF0F766E) : const Color(0xFFB91C1C),
        content: Text(
          ok ? 'Reporte desestimado y archivado correctamente.' : 'Error: ${viewModel.errorMessage}',
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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

  String _getPresetLabel() {
    switch (_selectedPreset) {
      case 'hoy':
        return 'Hoy';
      case 'ayer':
        return 'Ayer';
      case '7dias':
        return 'Últimos 7 días';
      case 'mes':
        return 'Este mes';
      case 'todo':
        return 'Histórico completo';
      case 'personalizado':
        if (_startDate != null && _endDate != null) {
          return '${_startDate!.day}/${_startDate!.month} — ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';
        }
        return 'Personalizado';
      default:
        return 'Filtrar fecha';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BreakdownReportsViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final canManage = authVm.hasPermission('breakdown.manage');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allReports = [...vm.openReports, ...vm.resolvedReports, ...vm.rejectedReports];
    final filteredReports = _filterReports(allReports);

    final bgMain = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgMain,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 680;

          return Column(
            children: [
              // Barra de Control Superior Limpia
              _buildCleanHeader(
                isMobile: isMobile,
                isDark: isDark,
                borderColor: borderColor,
                openCount: vm.openReports.length,
                resolvedCount: vm.resolvedReports.length,
                rejectedCount: vm.rejectedReports.length,
                totalCount: allReports.length,
              ),

              // Lista de Incidencias con diseño despejado
              Expanded(
                child: switch (vm.viewState) {
                  BreakdownReportsViewState.initial ||
                  BreakdownReportsViewState.loading =>
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF0055A5),
                      ),
                    ),
                  BreakdownReportsViewState.error => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error al cargar las incidencias: ${vm.errorMessage}',
                          style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  BreakdownReportsViewState.success => filteredReports.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0055A5).withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.inbox_outlined,
                                    size: 28,
                                    color: Color(0xFF0055A5),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Sin incidencias para "$_searchQuery"'
                                      : 'No hay averías registradas en este periodo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Verifica los términos o limpia la barra de búsqueda.'
                                      : 'Prueba cambiando el rango de fechas en el selector superior.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (_selectedPreset != 'todo') ...[
                                  const SizedBox(height: 14),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF0055A5),
                                    ),
                                    onPressed: () => _applyPreset('todo'),
                                    icon: const Icon(Icons.history_rounded, size: 16),
                                    label: const Text('Ver todo el historial', style: TextStyle(fontSize: 12.5)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadData(),
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 14 : 24,
                              vertical: 14,
                            ),
                            itemCount: filteredReports.length,
                            itemBuilder: (context, index) {
                              final report = filteredReports[index];
                              return _CleanReportCard(
                                report: report,
                                isProcessing: vm.isProcessing,
                                canGenerateOt: canManage,
                                canReject: canManage,
                                onGenerateOt: () => _generateWorkOrder(report),
                                onReject: () => _confirmReject(report),
                                isDark: isDark,
                                borderColor: borderColor,
                                isMobile: isMobile,
                              );
                            },
                          ),
                        ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Encabezado Ultra-Limpio con Tabs Modernas y Barra de Herramientas Compacta
  Widget _buildCleanHeader({
    required bool isMobile,
    required bool isDark,
    required Color borderColor,
    required int openCount,
    required int resolvedCount,
    required int rejectedCount,
    required int totalCount,
  }) {
    final headerBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Buscador integrado + Botón de Fechas Compacto
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 24,
              14,
              isMobile ? 14 : 24,
              10,
            ),
            child: isMobile
                ? Column(
                    children: [
                      _buildSearchField(isDark, borderColor),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDateMenuButton(isDark, borderColor)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildSearchField(isDark, borderColor)),
                      const SizedBox(width: 12),
                      _buildDateMenuButton(isDark, borderColor),
                    ],
                  ),
          ),

          // Fila 2: Pestañas de Estado Estilo Clean Underline
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 20),
            child: Row(
              children: [
                _buildCleanTab(
                  tab: _ReportTab.open,
                  label: 'Pendientes',
                  count: openCount,
                  accentColor: const Color(0xFFD97706),
                  isDark: isDark,
                ),
                _buildCleanTab(
                  tab: _ReportTab.resolved,
                  label: 'Resueltas',
                  count: resolvedCount,
                  accentColor: const Color(0xFF059669),
                  isDark: isDark,
                ),
                _buildCleanTab(
                  tab: _ReportTab.rejected,
                  label: 'Rechazadas',
                  count: rejectedCount,
                  accentColor: const Color(0xFF64748B),
                  isDark: isDark,
                ),
                _buildCleanTab(
                  tab: _ReportTab.all,
                  label: 'Todas',
                  count: totalCount,
                  accentColor: const Color(0xFF0055A5),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de Búsqueda Despejado y Elegante
  Widget _buildSearchField(bool isDark, Color borderColor) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.9),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por equipo, código (ej. A003), motivo...',
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  /// Selector de Fecha Compacto con Menú Desplegable
  Widget _buildDateMenuButton(bool isDark, Color borderColor) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'personalizado') {
          _selectDateRange();
        } else {
          _applyPreset(val);
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      itemBuilder: (ctx) => [
        _buildPopupItem('hoy', 'Hoy', Icons.today_outlined),
        _buildPopupItem('ayer', 'Ayer', Icons.history_toggle_off_outlined),
        _buildPopupItem('7dias', 'Últimos 7 días', Icons.calendar_view_week_outlined),
        _buildPopupItem('mes', 'Este mes', Icons.calendar_month_outlined),
        _buildPopupItem('todo', 'Histórico completo', Icons.all_inclusive_rounded),
        const PopupMenuDivider(),
        _buildPopupItem('personalizado', 'Seleccionar rango personalizado...', Icons.date_range_outlined),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF0055A5)),
            const SizedBox(width: 8),
            Text(
              _getPresetLabel(),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String text, IconData icon) {
    final isSelected = _selectedPreset == value;

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? const Color(0xFF0055A5) : const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0055A5) : null,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0055A5)),
        ],
      ),
    );
  }

  /// Pestaña Limpia con Subrayado Activo (Estilo Modern SaaS)
  Widget _buildCleanTab({
    required _ReportTab tab,
    required String label,
    required int count,
    required Color accentColor,
    required bool isDark,
  }) {
    final isSelected = _tab == tab;

    return InkWell(
      onTap: () => setState(() => _tab = tab),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF0055A5) : Colors.transparent,
              width: 2.2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0055A5).withValues(alpha: 0.1)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFF0055A5)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta Limpia, Espaciosa y Responsiva para cada Incidencia
class _CleanReportCard extends StatelessWidget {
  const _CleanReportCard({
    required this.report,
    required this.isProcessing,
    required this.canGenerateOt,
    required this.canReject,
    required this.onGenerateOt,
    required this.onReject,
    required this.isDark,
    required this.borderColor,
    required this.isMobile,
  });

  final BreakdownReport report;
  final bool isProcessing;
  final bool canGenerateOt;
  final bool canReject;
  final VoidCallback onGenerateOt;
  final VoidCallback onReject;
  final bool isDark;
  final Color borderColor;
  final bool isMobile;

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final dayStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return 'Hoy a las $timeStr';
    } else if (diff.inDays == 1 || (diff.inHours < 48 && dt.day == now.subtract(const Duration(days: 1)).day)) {
      return 'Ayer a las $timeStr';
    }
    return '$dayStr $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    // Criticidad limpia
    final (sevColor, sevText) = switch (report.severity) {
      BreakdownSeverity.low => (const Color(0xFF059669), 'Baja'),
      BreakdownSeverity.medium => (const Color(0xFFD97706), 'Media'),
      BreakdownSeverity.high => (const Color(0xFFDC2626), 'Alta / Urgente'),
    };

    // Estado formal limpio
    final (statusText, statusColor, statusBg) = switch (report.status) {
      BreakdownReportStatus.reported => (
          'En Revisión',
          const Color(0xFFC2410C),
          const Color(0xFFFFF7ED),
        ),
      BreakdownReportStatus.inWorkOrder => (
          report.workOrderId != null ? 'En OT ${report.workOrderId}' : 'En OT',
          const Color(0xFF0055A5),
          const Color(0xFFEFF6FF),
        ),
      BreakdownReportStatus.resolved => (
          'Resuelta',
          const Color(0xFF059669),
          const Color(0xFFF0FDF4),
        ),
      BreakdownReportStatus.rejected => (
          'Rechazada',
          const Color(0xFF64748B),
          const Color(0xFFF8FAFC),
        ),
    };

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    // Fila 1: Código de Equipo, Nombre y Badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Chip de código de activo
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0055A5).withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  report.assetId,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: Color(0xFF0055A5),
                                  ),
                                ),
                              ),
                              // Nombre del equipo
                              Text(
                                report.assetName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              // Área
                              Text(
                                '· Área: ${report.areaId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Severidad + Estado
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Indicador de severidad
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.5,
                                  height: 6.5,
                                  decoration: BoxDecoration(
                                    color: sevColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4.5),
                                Text(
                                  sevText,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: sevColor,
                                  ),
                                ),
                              ],
                            ),
                            // Badge de estado
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark ? statusColor.withValues(alpha: 0.15) : statusBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Fila 2: Descripción limpia (directa, sin cajas excesivas)
                    Text(
                      report.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),

                    // Motivo de rechazo si aplica
                    if (report.rejectionReason != null && report.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Motivo de rechazo: ${report.rejectionReason}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Fila 3: Metadatos y Acciones
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetadata(isDark),
                          if (report.status == BreakdownReportStatus.reported) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (canReject) ...[
                                  _buildRejectButton(),
                                  const SizedBox(width: 8),
                                ],
                                if (canGenerateOt)
                                  _buildGenerateOtButton(),
                              ],
                            ),
                          ],
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(child: _buildMetadata(isDark)),
                          if (report.status == BreakdownReportStatus.reported)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canReject) ...[
                                  _buildRejectButton(),
                                  const SizedBox(width: 8),
                                ],
                                if (canGenerateOt)
                                  _buildGenerateOtButton(),
                              ],
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
  }

  Widget _buildMetadata(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.person_outline_rounded,
          size: 14,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        const SizedBox(width: 4),
        Text(
          report.reportedByUserName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '·',
          style: TextStyle(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatTimestamp(report.reportedAt),
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectButton() {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFDC2626),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: isProcessing ? null : onReject,
      icon: const Icon(Icons.close_rounded, size: 14),
      label: const Text('Rechazar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGenerateOtButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0055A5),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: isProcessing ? null : onGenerateOt,
      icon: const Icon(Icons.assignment_add, size: 14),
      label: const Text('Generar OT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Diálogo Modal Limpio y Formal de Rechazo
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: const Text(
        'Desestimar Reporte de Avería',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.report.assetId} — ${widget.report.assetName}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Indica el motivo técnico por el cual no procede...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El motivo es obligatorio para auditoría.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reasonCtrl.text.trim());
            }
          },
          child: const Text('Confirmar Rechazo'),
        ),
      ],
    );
  }
}
