import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_list_viewmodel.dart';
import 'work_order_create_view.dart';
import 'work_order_detail_view.dart';

enum _WorkOrderFilter { all, pending, inProgress, completed, cancelled }

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
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
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

  void _onFilterSelected(_WorkOrderFilter filter) {
    setState(() => _filter = filter);
    _loadData();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: 'Seleccionar Rango de Fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      _loadData();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
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
    final canCreate = context.watch<AuthViewModel>().hasPermission(
          'work_order.create',
        );

    final dateLabel = _startDate == null
        ? 'Filtrar fecha'
        : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';

    final vm = context.watch<WorkOrderListViewModel>();
    final filteredOrders = _filterOrders(vm.workOrders);

    return Scaffold(
      body: Column(
        children: [
          // Barra de Control Responsiva
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;

                final segmented = SegmentedButton<_WorkOrderFilter>(
                  segments: const [
                    ButtonSegment(
                      value: _WorkOrderFilter.all,
                      label: Text('Todas'),
                    ),
                    ButtonSegment(
                      value: _WorkOrderFilter.pending,
                      label: Text('Pendientes'),
                    ),
                    ButtonSegment(
                      value: _WorkOrderFilter.inProgress,
                      label: Text('En Progreso'),
                    ),
                    ButtonSegment(
                      value: _WorkOrderFilter.completed,
                      label: Text('Completadas'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (set) => _onFilterSelected(set.first),
                );

                final searchField = TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por OT, equipo o descripción...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );

                final dateChip = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionChip(
                      avatar: Icon(
                        Icons.date_range,
                        size: 16,
                        color: _startDate != null ? Theme.of(context).colorScheme.primary : null,
                      ),
                      label: Text(dateLabel, style: const TextStyle(fontSize: 12)),
                      onPressed: _selectDateRange,
                    ),
                    if (_startDate != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Limpiar fecha',
                        onPressed: _clearDateRange,
                      ),
                    ],
                  ],
                );

                final createBtn = canCreate
                    ? FilledButton.icon(
                        onPressed: _createOrder,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva OT'),
                      )
                    : null;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: segmented,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 8),
                          dateChip,
                        ],
                      ),
                      if (createBtn != null) ...[
                        const SizedBox(height: 8),
                        createBtn,
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    segmented,
                    const SizedBox(width: 12),
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    dateChip,
                    if (createBtn != null) ...[
                      const SizedBox(width: 8),
                      createBtn,
                    ],
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Listado
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.errorMessage.isNotEmpty
                    ? Center(child: Text('Error: ${vm.errorMessage}'))
                    : filteredOrders.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay órdenes de trabajo registradas.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async => _loadData(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = filteredOrders[index];
                                return _SimpleWorkOrderTile(
                                  order: order,
                                  onTap: () => _openDetail(order),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SimpleWorkOrderTile extends StatelessWidget {
  const _SimpleWorkOrderTile({
    required this.order,
    required this.onTap,
  });

  final WorkOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg, statusLabel) = switch (order.status) {
      WorkOrderStatus.pending => (
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7),
          'Pendiente',
        ),
      WorkOrderStatus.inProgress => (
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
          'En Progreso',
        ),
      WorkOrderStatus.completed => (
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7),
          'Completada',
        ),
      WorkOrderStatus.cancelled => (
          const Color(0xFF475569),
          const Color(0xFFF1F5F9),
          'Cancelada',
        ),
    };

    final (priorityColor, priorityLabel) = switch (order.priority) {
      WorkOrderPriority.low => (Colors.grey.shade700, 'Baja'),
      WorkOrderPriority.medium => (Colors.orange.shade800, 'Media'),
      WorkOrderPriority.high => (Colors.red.shade700, 'Alta'),
    };

    final dateStr = order.createdAt != null
        ? '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}'
        : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Text(
              order.id,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${order.assetId} — ${order.assetName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(4),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              order.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  'Prioridad: $priorityLabel',
                  style: TextStyle(fontSize: 11, color: priorityColor, fontWeight: FontWeight.w500),
                ),
                if (order.assignedTo != null && order.assignedTo!.isNotEmpty)
                  Text(
                    '· Asignado a: ${order.assignedTo}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                Text(
                  '· Fecha: $dateStr',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
