import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/my_reports_viewmodel.dart';

enum _MyReportTab { all, open, inWorkOrder, resolved, rejected }

/// Vista ejecutiva, ultra-limpia y responsive de "Mis Reportes de Avería".
/// Diseñada bajo principios de diseño minimalista industrial (SaaS moderno)
/// para que los supervisores u operadores consulten con claridad el estado
/// de sus incidencias en Web y Android.
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
    final vm = context.watch<MyReportsViewModel>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allReports = vm.reports;
    final filteredReports = _filterReports(allReports);

    // Contadores basados en el rango de fecha seleccionado
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

    final bgMain = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgMain,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 680;

          return Column(
            children: [
              // Encabezado Limpio con Buscador y Selector de Fecha
              _buildCleanHeader(
                isMobile: isMobile,
                isDark: isDark,
                borderColor: borderColor,
                totalCount: dateFilteredReports.length,
                openCount: openCount,
                inOtCount: inOtCount,
                resolvedCount: resolvedCount,
                rejectedCount: rejectedCount,
              ),

              // Lista de Mis Reportes con diseño despejado
              Expanded(
                child: switch (vm.viewState) {
                  MyReportsViewState.initial ||
                  MyReportsViewState.loading =>
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF0055A5),
                      ),
                    ),
                  MyReportsViewState.error => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
                            const SizedBox(height: 12),
                            Text(
                              'Error al cargar tus reportes: ${vm.errorMessage}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
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
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0055A5).withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_turned_in_outlined,
                                    size: 28,
                                    color: Color(0xFF0055A5),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Sin resultados para "$_searchQuery"'
                                      : allReports.isEmpty
                                          ? 'Aún no has reportado averías en el sistema.'
                                          : 'No hay reportes que coincidan con los filtros.',
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
                                      ? 'Intenta con otro término o limpia la barra de búsqueda.'
                                      : 'Prueba cambiando el rango de fechas o el filtro de estado.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (_selectedPreset != 'todo' || _tab != _MyReportTab.all || _searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF0055A5),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchCtrl.clear();
                                        _tab = _MyReportTab.all;
                                        _applyPreset('todo');
                                      });
                                    },
                                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                                    label: const Text('Limpiar todos los filtros', style: TextStyle(fontSize: 12.5)),
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
                            itemBuilder: (context, index) => _CleanMyReportCard(
                              report: filteredReports[index],
                              isDark: isDark,
                              borderColor: borderColor,
                              isMobile: isMobile,
                            ),
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

  /// Encabezado Ultra-Limpio con Buscador y Pestañas
  Widget _buildCleanHeader({
    required bool isMobile,
    required bool isDark,
    required Color borderColor,
    required int totalCount,
    required int openCount,
    required int inOtCount,
    required int resolvedCount,
    required int rejectedCount,
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
                  tab: _MyReportTab.all,
                  label: 'Todos',
                  count: totalCount,
                  accentColor: const Color(0xFF0055A5),
                  isDark: isDark,
                ),
                _buildCleanTab(
                  tab: _MyReportTab.open,
                  label: 'En Revisión',
                  count: openCount,
                  accentColor: const Color(0xFFD97706),
                  isDark: isDark,
                ),
                _buildCleanTab(
                  tab: _MyReportTab.inWorkOrder,
                  label: 'En OT',
                  count: inOtCount,
                  accentColor: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
                _buildCleanTab(
                  tab: _MyReportTab.resolved,
                  label: 'Resueltos',
                  count: resolvedCount,
                  accentColor: const Color(0xFF059669),
                  isDark: isDark,
                ),
                _buildCleanTab(
                  tab: _MyReportTab.rejected,
                  label: 'Rechazados',
                  count: rejectedCount,
                  accentColor: const Color(0xFF64748B),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildCleanTab({
    required _MyReportTab tab,
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

/// Tarjeta Limpia y Formal para "Mis Reportes de Avería"
class _CleanMyReportCard extends StatelessWidget {
  const _CleanMyReportCard({
    required this.report,
    required this.isDark,
    required this.borderColor,
    required this.isMobile,
  });

  final BreakdownReport report;
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
    final (sevColor, sevText) = switch (report.severity) {
      BreakdownSeverity.low => (const Color(0xFF059669), 'Baja'),
      BreakdownSeverity.medium => (const Color(0xFFD97706), 'Media'),
      BreakdownSeverity.high => (const Color(0xFFDC2626), 'Alta / Urgente'),
    };

    final (statusText, statusColor, statusBg) = switch (report.status) {
      BreakdownReportStatus.reported => (
          'En Revisión',
          const Color(0xFFC2410C),
          const Color(0xFFFFF7ED),
        ),
      BreakdownReportStatus.inWorkOrder => (
          report.workOrderId != null ? 'OT Asignada: ${report.workOrderId}' : 'En Orden de Trabajo',
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
                    // Fila 1: Código, Nombre de Equipo, Criticidad y Estado
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
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
                              Text(
                                report.assetName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
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

                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
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

                    // Fila 2: Descripción limpia y directa
                    Text(
                      report.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),

                    // Motivo de rechazo si aplica
                    if (report.status == BreakdownReportStatus.rejected &&
                        report.rejectionReason != null &&
                        report.rejectionReason!.isNotEmpty) ...[
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

                    // Fila 3: Metadatos (Fecha de captura y enlace a OT)
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatTimestamp(report.reportedAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        if (report.workOrderId != null && report.workOrderId!.isNotEmpty) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.assignment_outlined, size: 12, color: Color(0xFF0055A5)),
                                const SizedBox(width: 4),
                                Text(
                                  'OT: ${report.workOrderId}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0055A5),
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
