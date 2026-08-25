import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/kardex_log.dart';
import '../viewmodels/kardex_list_viewmodel.dart';

class KardexListView extends StatefulWidget {
  const KardexListView({super.key, this.entityId});

  final String? entityId;

  @override
  State<KardexListView> createState() => _KardexListViewState();
}

class _KardexListViewState extends State<KardexListView> {
  DateTime? _startDate;
  DateTime? _endDate;

  void _loadData() {
    final vm = context.read<KardexListViewModel>();
    if (widget.entityId != null && widget.entityId!.isNotEmpty) {
      vm.loadForEntity(widget.entityId!);
    } else {
      vm.loadAll(limit: 50, startDate: _startDate, endDate: _endDate);
    }
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KardexListViewModel>();

    final dateLabel = _startDate == null
        ? 'Filtrar fecha'
        : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';

    final bodyContent = Column(
      children: [
        if (widget.entityId == null || widget.entityId!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionChip(
                  avatar: Icon(
                    Icons.date_range,
                    size: 16,
                    color: _startDate != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  label: Text(dateLabel, style: const TextStyle(fontSize: 12)),
                  onPressed: _selectDateRange,
                ),
                if (_startDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Limpiar fecha',
                    onPressed: _clearDateRange,
                  ),
              ],
            ),
          ),
        Expanded(
          child: () {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.errorMessage.isNotEmpty) {
              return Center(child: Text('Error: ${vm.errorMessage}'));
            }
            if (vm.logs.isEmpty) {
              return const Center(
                child: Text('No hay registros en el kardex.'),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: vm.logs.length,
                itemBuilder: (context, index) =>
                    _KardexLogTile(log: vm.logs[index]),
              ),
            );
          }(),
        ),
      ],
    );

    if (widget.entityId != null && widget.entityId!.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Historial / Kardex: ${widget.entityId}')),
        body: bodyContent,
      );
    }

    return bodyContent;
  }
}

class _KardexLogTile extends StatelessWidget {
  const _KardexLogTile({required this.log});

  final KardexLog log;

  static const Map<String, String> _actionLabels = {
    'WORK_ORDER_CREATED': 'Orden de Trabajo Creada',
    'WORK_ORDER_STATUS_CHANGED': 'Cambio de Estado en Orden de Trabajo',
    'WORK_ORDER_UPDATED': 'Actualización de Orden de Trabajo',
    'BREAKDOWN_REPORTED': 'Reporte de Avería Creado',
    'BREAKDOWN_LINKED_WORK_ORDER': 'Reporte de Avería Vinculado a OT',
    'BREAKDOWN_RESOLVED': 'Reporte de Avería Resuelto',
    'BREAKDOWN_REJECTED': 'Reporte de Avería Rechazado',
    'ASSET_DELETE_REQUESTED': 'Solicitud de Baja de Activo',
    'ASSET_DELETED': 'Baja de Activo Aprobada',
    'ASSET_DELETE_REJECTED': 'Solicitud de Baja de Activo Rechazada',
    'ASSET_CREATED': 'Activo Registrado',
    'ASSET_UPDATED': 'Información de Activo Actualizada',
    'ASSET_REACTIVATED': 'Activo Reactivado',
    'ASSET_DEACTIVATED': 'Activo Desactivado',
    'PREVENTIVE_SCHEDULE_CREATED': 'Programa Preventivo Creado',
    'PREVENTIVE_SCHEDULE_UPDATED': 'Programa Preventivo Actualizado',
    'PREVENTIVE_SCHEDULE_DELETED': 'Programa Preventivo Eliminado',
    'USER_CREATED': 'Usuario Creado',
    'USER_UPDATED': 'Usuario Actualizado',
    'USER_STATUS_CHANGED': 'Estado de Usuario Modificado',
    'PASSWORD_RESET_TEMPORARY': 'Clave Temporal Asignada',
  };

  static const Map<String, IconData> _moduleIcons = {
    'ASSETS': Icons.precision_manufacturing_outlined,
    'WORK_ORDERS': Icons.assignment_outlined,
    'BREAKDOWNS': Icons.report_problem_outlined,
    'PREVENTIVE': Icons.calendar_month_outlined,
    'USERS': Icons.people_outline,
  };

  @override
  Widget build(BuildContext context) {
    final actionName = _actionLabels[log.action] ?? log.action;
    final icon = _moduleIcons[log.module] ?? Icons.history;

    final dateStr = log.timestamp != null
        ? '${log.timestamp!.day}/${log.timestamp!.month}/${log.timestamp!.year} '
              '${log.timestamp!.hour.toString().padLeft(2, '0')}:'
              '${log.timestamp!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 18, child: Icon(icon, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$actionName — ${log.entityId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(log.details, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Registrado por: ${log.userName}  ·  $dateStr',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
