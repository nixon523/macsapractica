import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_list_viewmodel.dart';
import 'work_order_create_view.dart';
import 'work_order_detail_view.dart';

enum _WorkOrderFilter { all, pending, inProgress, completed, cancelled }

enum _WorkOrderTypeFilter { all, preventive, corrective }

/// Vista ejecutiva y formal de Órdenes de Trabajo del Grupo Macsa.
/// Integra filtros cronológicos con menú desplegable, pestañas con subrayado limpio,
/// búsqueda en tiempo real y tarjetas de diseño despejado y responsive.
class WorkOrderListView extends StatefulWidget {
  const WorkOrderListView({super.key, this.assetId});

  final String? assetId;

  @override
  State<WorkOrderListView> createState() => _WorkOrderListViewState();
}

class _WorkOrderListViewState extends State<WorkOrderListView> {
  _WorkOrderFilter _filter = _WorkOrderFilter.all;
  _WorkOrderTypeFilter _typeFilter = _WorkOrderTypeFilter.all;
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
    final vm = context.read<WorkOrderListViewModel>();
    final status = switch (_filter) {
      _WorkOrderFilter.all => null,
      _WorkOrderFilter.pending => WorkOrderStatus.pending,
      _WorkOrderFilter.inProgress => WorkOrderStatus.inProgress,
      _WorkOrderFilter.completed => WorkOrderStatus.completed,
      _WorkOrderFilter.cancelled => WorkOrderStatus.cancelled,
    };

    if (widget.assetId != null && widget.assetId!.isNotEmpty) {
      vm.loadForAsset(widget.assetId!);
    } else {
      vm.loadAll(
        status: status,
        startDate: _startDate,
        endDate: _endDate,
      );
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
    _loadData();
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

  void _onFilterSelected(_WorkOrderFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _loadData();
  }

  Future<void> _openDetail(WorkOrder order) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailView(order: order),
      ),
    );
    if (updated == true && mounted) {
      _loadData();
    }
  }

  Future<void> _createOrder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const WorkOrderCreateView()),
    );
    if (created == true && mounted) {
      _loadData();
    }
  }

  List<WorkOrder> _filterOrders(List<WorkOrder> orders) {
    var result = orders;

    if (_typeFilter == _WorkOrderTypeFilter.preventive) {
      result = result.where((order) => order.isPreventive).toList();
    } else if (_typeFilter == _WorkOrderTypeFilter.corrective) {
      result = result.where((order) => order.isCorrective).toList();
    }

    if (_searchQuery.isEmpty) return result;

    return result.where((order) {
      final id = order.id.toLowerCase();
      final assetName = order.assetName.toLowerCase();
      final assetId = order.assetId.toLowerCase();
      final desc = order.description.toLowerCase();
      final assigned = (order.assignedTo ?? '').toLowerCase();

      return id.contains(_searchQuery) ||
          assetName.contains(_searchQuery) ||
          assetId.contains(_searchQuery) ||
          desc.contains(_searchQuery) ||
          assigned.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AuthViewModel>().hasPermission('work_order.create');
    final vm = context.watch<WorkOrderListViewModel>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filteredOrders = _filterOrders(vm.workOrders);
    final isAssetDetail = widget.assetId != null && widget.assetId!.isNotEmpty;

    final bgMain = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final bodyContent = LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Column(
          children: [
            if (!isAssetDetail)
              _buildCleanHeader(
                isMobile: isMobile,
                isDark: isDark,
                borderColor: borderColor,
                canCreate: canCreate,
                currentCount: filteredOrders.length,
              ),
            Expanded(
              child: _buildBody(vm, filteredOrders, isDark, borderColor, isMobile),
            ),
          ],
        );
      },
    );

    if (isAssetDetail) {
      return Scaffold(
        backgroundColor: bgMain,
        appBar: AppBar(
          title: Text('Órdenes de Trabajo: ${widget.assetId}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _loadData,
            ),
          ],
        ),
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: bgMain,
      body: bodyContent,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _createOrder,
              backgroundColor: const Color(0xFF0055A5),
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Nueva OT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  /// Encabezado moderno, despejado y consistente
  Widget _buildCleanHeader({
    required bool isMobile,
    required bool isDark,
    required Color borderColor,
    required bool canCreate,
    required int currentCount,
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
          // Fila 1: Buscador integrado + Menú de Fechas + Botón Nueva OT (Desktop)
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
                          const SizedBox(width: 8),
                          Expanded(child: _buildTypeMenuButton(isDark, borderColor)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildSearchField(isDark, borderColor)),
                      const SizedBox(width: 10),
                      _buildDateMenuButton(isDark, borderColor),
                      const SizedBox(width: 8),
                      _buildTypeMenuButton(isDark, borderColor),
                      if (canCreate) ...[
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0055A5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _createOrder,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Nueva OT',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // Fila 2: Pestañas de Estado con subrayado limpio (Clean Underline)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 20),
            child: Row(
              children: [
                _buildCleanTab(
                  filter: _WorkOrderFilter.all,
                  label: 'Todas',
                  isDark: isDark,
                  accentColor: const Color(0xFF0055A5),
                ),
                _buildCleanTab(
                  filter: _WorkOrderFilter.pending,
                  label: 'Pendientes',
                  isDark: isDark,
                  accentColor: const Color(0xFFD97706),
                ),
                _buildCleanTab(
                  filter: _WorkOrderFilter.inProgress,
                  label: 'En Progreso',
                  isDark: isDark,
                  accentColor: const Color(0xFF0055A5),
                ),
                _buildCleanTab(
                  filter: _WorkOrderFilter.completed,
                  label: 'Completadas',
                  isDark: isDark,
                  accentColor: const Color(0xFF059669),
                ),
                _buildCleanTab(
                  filter: _WorkOrderFilter.cancelled,
                  label: 'Canceladas',
                  isDark: isDark,
                  accentColor: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de búsqueda despejado
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
          hintText: 'Buscar por OT, equipo, técnico o descripción…',
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

  /// Menú desplegable compacto para seleccionar el periodo de tiempo
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

  /// Menú desplegable para filtrar por Tipo de Orden de Trabajo (Preventiva vs Correctiva)
  Widget _buildTypeMenuButton(bool isDark, Color borderColor) {
    final isFiltered = _typeFilter != _WorkOrderTypeFilter.all;

    return PopupMenuButton<_WorkOrderTypeFilter>(
      initialValue: _typeFilter,
      onSelected: (val) {
        if (_typeFilter == val) return;
        setState(() => _typeFilter = val);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      itemBuilder: (ctx) => [
        _buildTypePopupItem(
          _WorkOrderTypeFilter.all,
          'Todos los tipos',
          Icons.layers_outlined,
          const Color(0xFF0055A5),
        ),
        _buildTypePopupItem(
          _WorkOrderTypeFilter.preventive,
          'Preventivas (PM)',
          Icons.event_note_outlined,
          const Color(0xFF2563EB),
        ),
        _buildTypePopupItem(
          _WorkOrderTypeFilter.corrective,
          'Correctivas (Averías)',
          Icons.report_problem_outlined,
          const Color(0xFFEA580C),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isFiltered
              ? (isDark
                  ? const Color(0xFF0055A5).withValues(alpha: 0.2)
                  : const Color(0xFF0055A5).withValues(alpha: 0.08))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFiltered ? const Color(0xFF0055A5) : borderColor,
            width: isFiltered ? 1.2 : 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (_typeFilter) {
                _WorkOrderTypeFilter.all => Icons.filter_alt_outlined,
                _WorkOrderTypeFilter.preventive => Icons.event_note_outlined,
                _WorkOrderTypeFilter.corrective => Icons.report_problem_outlined,
              },
              size: 15,
              color: switch (_typeFilter) {
                _WorkOrderTypeFilter.all => const Color(0xFF0055A5),
                _WorkOrderTypeFilter.preventive => const Color(0xFF2563EB),
                _WorkOrderTypeFilter.corrective => const Color(0xFFEA580C),
              },
            ),
            const SizedBox(width: 8),
            Text(
              switch (_typeFilter) {
                _WorkOrderTypeFilter.all => 'Tipo de OT',
                _WorkOrderTypeFilter.preventive => 'Preventivas',
                _WorkOrderTypeFilter.corrective => 'Correctivas',
              },
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isFiltered ? FontWeight.w700 : FontWeight.w600,
                color: isFiltered
                    ? const Color(0xFF0055A5)
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_WorkOrderTypeFilter> _buildTypePopupItem(
    _WorkOrderTypeFilter value,
    String text,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = _typeFilter == value;

    return PopupMenuItem<_WorkOrderTypeFilter>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? activeColor : const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 16, color: activeColor),
        ],
      ),
    );
  }

  /// Pestaña con barra inferior activa (Modern Underline Tab)
  Widget _buildCleanTab({
    required _WorkOrderFilter filter,
    required String label,
    required bool isDark,
    required Color accentColor,
  }) {
    final isSelected = _filter == filter;

    return InkWell(
      onTap: () => _onFilterSelected(filter),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    WorkOrderListViewModel vm,
    List<WorkOrder> orders,
    bool isDark,
    Color borderColor,
    bool isMobile,
  ) {
    if (vm.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0055A5)),
            SizedBox(height: 14),
            Text(
              'Cargando órdenes de trabajo…',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (vm.errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                'Error al consultar órdenes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                vm.errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
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
                  Icons.assignment_outlined,
                  size: 28,
                  color: Color(0xFF0055A5),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Sin resultados para "$_searchQuery"'
                    : (_typeFilter != _WorkOrderTypeFilter.all
                        ? 'No hay órdenes ${_typeFilter == _WorkOrderTypeFilter.preventive ? "preventivas" : "correctivas"} en este periodo.'
                        : 'No hay órdenes de trabajo en este periodo.'),
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
                    : (_typeFilter != _WorkOrderTypeFilter.all
                        ? 'Prueba cambiando el tipo de OT o el rango de fechas.'
                        : 'Prueba cambiando el rango de fechas en el selector superior.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              if (_typeFilter != _WorkOrderTypeFilter.all) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0055A5)),
                  onPressed: () => setState(() => _typeFilter = _WorkOrderTypeFilter.all),
                  icon: const Icon(Icons.layers_clear_outlined, size: 16),
                  label: const Text('Ver todos los tipos', style: TextStyle(fontSize: 12.5)),
                ),
              ] else if (_selectedPreset != 'todo') ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0055A5),
                  ),
                  onPressed: () => _applyPreset('todo'),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Ver todas las órdenes', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: Column(
        children: [
          _buildSummaryBar(orders.length, isDark, borderColor),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: 12,
              ),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _CleanWorkOrderCard(
                  order: order,
                  onTap: () => _openDetail(order),
                  isDark: isDark,
                  borderColor: borderColor,
                  isMobile: isMobile,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(int count, bool isDark, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9).withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in_outlined, size: 15, color: Color(0xFF0055A5)),
          const SizedBox(width: 8),
          Text(
            '$count orden(es) de trabajo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          if (_typeFilter != _WorkOrderTypeFilter.all) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _typeFilter == _WorkOrderTypeFilter.preventive
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _typeFilter == _WorkOrderTypeFilter.preventive
                      ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                      : const Color(0xFFEA580C).withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _typeFilter == _WorkOrderTypeFilter.preventive
                        ? 'Preventivas'
                        : 'Correctivas',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _typeFilter == _WorkOrderTypeFilter.preventive
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _typeFilter = _WorkOrderTypeFilter.all),
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: _typeFilter == _WorkOrderTypeFilter.preventive
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          Text(
            'Orden cronológico',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta ejecutiva, despejada y formal para cada Orden de Trabajo
class _CleanWorkOrderCard extends StatelessWidget {
  const _CleanWorkOrderCard({
    required this.order,
    required this.onTap,
    required this.isDark,
    required this.borderColor,
    required this.isMobile,
  });

  final WorkOrder order;
  final VoidCallback onTap;
  final bool isDark;
  final Color borderColor;
  final bool isMobile;

  static Color _getStatusColor(WorkOrderStatus status) {
    return switch (status) {
      WorkOrderStatus.pending => const Color(0xFFD97706), // Ámbar
      WorkOrderStatus.inProgress => const Color(0xFF0055A5), // Macsa Blue
      WorkOrderStatus.completed => const Color(0xFF059669), // Verde
      WorkOrderStatus.cancelled => const Color(0xFF64748B), // Pizarra
    };
  }

  static String _getStatusLabel(WorkOrderStatus status) {
    return switch (status) {
      WorkOrderStatus.pending => 'Pendiente',
      WorkOrderStatus.inProgress => 'En Progreso',
      WorkOrderStatus.completed => 'Completada',
      WorkOrderStatus.cancelled => 'Cancelada',
    };
  }

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
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _getStatusLabel(order.status);
    final timeFormatted = _formatTimestamp(order.createdAt);
    final fullDate = order.createdAt != null
        ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year} ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    final (priorityColor, priorityBg, priorityLabel) = switch (order.priority) {
      WorkOrderPriority.low => (const Color(0xFF475569), const Color(0xFFF1F5F9), 'Baja'),
      WorkOrderPriority.medium => (const Color(0xFFD97706), const Color(0xFFFFFBEB), 'Media'),
      WorkOrderPriority.high => (const Color(0xFFDC2626), const Color(0xFFFEF2F2), 'Alta'),
    };

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                        // Fila 1: ID OT + Badges de Tipo y Prioridad + Estado
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Chip OT
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      order.id,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0055A5),
                                      ),
                                    ),
                                  ),
                                  // Tipo (Preventivo / Correctivo)
                                  if (order.isPreventive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.event_note_outlined, size: 12, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 4),
                                          Text(
                                            order.preventiveScheduleId != null && order.preventiveScheduleId!.isNotEmpty
                                                ? 'PM: ${order.preventiveScheduleId}'
                                                : 'Preventivo',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.report_problem_outlined, size: 12, color: Color(0xFFEA580C)),
                                          const SizedBox(width: 4),
                                          Text(
                                            order.reportId != null && order.reportId!.isNotEmpty
                                                ? 'Avería #${order.reportId}'
                                                : 'Correctivo',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFEA580C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Prioridad
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: priorityBg,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'Prioridad $priorityLabel',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: priorityColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Badge de Estado
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
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

                        // Fila 2: Nombre y Código de Activo
                        Text(
                          '${order.assetId} — ${order.assetName}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),

                        // Fila 3: Descripción limpia
                        Text(
                          order.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Fila 4: Footer con Técnico Asignado, Fecha y Botón de Ver
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (order.assignedTo != null && order.assignedTo!.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 14,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          order.assignedTo!,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  Tooltip(
                                    message: fullDate,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 13,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeFormatted,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver detalle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0055A5),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Color(0xFF0055A5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
  }
}
