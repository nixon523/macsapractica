import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_list_viewmodel.dart';
import 'work_order_create_view.dart';
import 'work_order_detail_view.dart';

enum _WorkOrderFilter { all, pending, inProgress, completed, cancelled }

/// Vista profesional de Órdenes de Trabajo basada en el estándar del Kardex.
/// Inicia SIEMPRE en el día de HOY con filtros de fecha Desde-Hasta, presets,
/// chips de estado temáticos, búsqueda en vivo y tarjetas ejecutivas.
class WorkOrderListView extends StatefulWidget {
  const WorkOrderListView({super.key, this.assetId});

  final String? assetId;

  @override
  State<WorkOrderListView> createState() => _WorkOrderListViewState();
}

class _WorkOrderListViewState extends State<WorkOrderListView> {
  _WorkOrderFilter _filter = _WorkOrderFilter.all;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  late DateTime? _startDate;
  late DateTime? _endDate;
  String _selectedPreset = 'mes';

  @override
  void initState() {
    super.initState();
    // Inicia por defecto en el MES ACTUAL para mostrar todas las órdenes del periodo
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
    if (_searchQuery.isEmpty) return orders;

    return orders.where((order) {
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
    final filteredOrders = _filterOrders(vm.workOrders);
    final isAssetDetail = widget.assetId != null && widget.assetId!.isNotEmpty;

    final bodyContent = LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;
        final isTablet = constraints.maxWidth >= 550 && constraints.maxWidth < 850;

        return Column(
          children: [
            if (!isAssetDetail) ...[
              _buildFilterSection(isDesktop: isDesktop, isTablet: isTablet, canCreate: canCreate),
              const Divider(height: 1),
            ],
            Expanded(
              child: _buildBody(vm, filteredOrders),
            ),
          ],
        );
      },
    );

    if (isAssetDetail) {
      return Scaffold(
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
      body: bodyContent,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _createOrder,
              icon: const Icon(Icons.add),
              label: const Text('Nueva OT'),
            )
          : null,
    );
  }

  Widget _buildFilterSection({
    required bool isDesktop,
    required bool isTablet,
    required bool canCreate,
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
          if (isDesktop)
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

          // Fila 2: Barra de búsqueda y Filtros por Estado
          if (isDesktop)
            Row(
              children: [
                Expanded(flex: 3, child: _buildSearchBar()),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _buildStatusChips(scrollable: false)),
              ],
            )
          else ...[
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildStatusChips(scrollable: true),
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
        hintText: 'Buscar por OT, equipo, técnico o descripción…',
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

  Widget _buildStatusChips({required bool scrollable}) {
    final statuses = <(_WorkOrderFilter, String, IconData, Color)>[
      (_WorkOrderFilter.all, 'Todas', Icons.all_inbox_outlined, const Color(0xFF1E293B)),
      (_WorkOrderFilter.pending, 'Pendientes', Icons.hourglass_top_outlined, const Color(0xFFB45309)),
      (_WorkOrderFilter.inProgress, 'En Progreso', Icons.sync_outlined, const Color(0xFF1D4ED8)),
      (_WorkOrderFilter.completed, 'Completadas', Icons.check_circle_outline, const Color(0xFF15803D)),
      (_WorkOrderFilter.cancelled, 'Canceladas', Icons.cancel_outlined, const Color(0xFF475569)),
    ];

    final chips = statuses.map((item) {
      final isSelected = _filter == item.$1;
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
        onSelected: (_) => _onFilterSelected(item.$1),
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

  Widget _buildBody(WorkOrderListViewModel vm, List<WorkOrder> orders) {
    if (vm.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando órdenes de trabajo…', style: TextStyle(fontSize: 13)),
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
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Error al consultar órdenes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                vm.errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
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
              Icon(
                Icons.assignment_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Sin resultados para "$_searchQuery"'
                    : 'No hay órdenes de trabajo en este periodo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Intenta con otro término o limpia la barra de búsqueda.'
                    : 'Prueba seleccionando otro rango de fechas o cambiando de estado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_selectedPreset != 'todo') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _applyPreset('todo'),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Ver todas las órdenes'),
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
          _buildSummaryBar(orders.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _ModernWorkOrderCard(
                  order: order,
                  onTap: () => _openDetail(order),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(int count) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            '$count orden(es) de trabajo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
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

/// Tarjeta ejecutiva para cada Orden de Trabajo con estándar visual del Kardex.
class _ModernWorkOrderCard extends StatelessWidget {
  const _ModernWorkOrderCard({
    required this.order,
    required this.onTap,
  });

  final WorkOrder order;
  final VoidCallback onTap;

  static Color _getStatusColor(WorkOrderStatus status) {
    return switch (status) {
      WorkOrderStatus.pending => const Color(0xFFB45309), // Ámbar
      WorkOrderStatus.inProgress => const Color(0xFF1D4ED8), // Azul vibrante
      WorkOrderStatus.completed => const Color(0xFF15803D), // Verde esmeralda
      WorkOrderStatus.cancelled => const Color(0xFF475569), // Pizarra
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

  static IconData _getStatusIcon(WorkOrderStatus status) {
    return switch (status) {
      WorkOrderStatus.pending => Icons.hourglass_top_outlined,
      WorkOrderStatus.inProgress => Icons.sync_outlined,
      WorkOrderStatus.completed => Icons.check_circle_outline,
      WorkOrderStatus.cancelled => Icons.cancel_outlined,
    };
  }

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
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _getStatusLabel(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final timeFormatted = _formatTimestamp(order.createdAt);
    final fullDate = order.createdAt != null
        ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year} ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    final (priorityColor, priorityBg, priorityLabel) = switch (order.priority) {
      WorkOrderPriority.low => (Colors.grey.shade800, Colors.grey.shade200, 'Baja'),
      WorkOrderPriority.medium => (Colors.orange.shade900, Colors.orange.shade100, 'Media'),
      WorkOrderPriority.high => (Colors.red.shade900, Colors.red.shade100, 'Alta'),
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Franja lateral con acento de color de estado
              Container(
                width: 5,
                color: statusColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Icono, Título/Activo y Badges
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(statusIcon, size: 18, color: statusColor),
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
                                        order.id,
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
                                        color: priorityBg,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'Prioridad $priorityLabel',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: priorityColor,
                                        ),
                                      ),
                                    ),
                                    if (order.isPreventive) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.event_note_outlined, size: 12, color: Colors.blue.shade800),
                                            const SizedBox(width: 4),
                                            Text(
                                              order.preventiveScheduleId != null && order.preventiveScheduleId!.isNotEmpty
                                                  ? 'Preventivo: ${order.preventiveScheduleId}'
                                                  : 'Preventivo',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.report_problem_outlined, size: 12, color: Colors.orange.shade900),
                                            const SizedBox(width: 4),
                                            Text(
                                              order.reportId != null && order.reportId!.isNotEmpty
                                                  ? 'Avería #${order.reportId}'
                                                  : 'Correctivo',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${order.assetId} — ${order.assetName}',
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
                          // Badge de Estado
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
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

                      // Descripción de la orden
                      Text(
                        order.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          height: 1.35,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Footer: Asignación y Fecha
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (order.assignedTo != null && order.assignedTo!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  order.assignedTo!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
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
                                  timeFormatted,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
