import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../app/widgets/app_info_row.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../breakdown_reports/domain/usecases/resolve_breakdown_report.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_create_viewmodel.dart';
import '../viewmodels/work_order_detail_viewmodel.dart';
import 'work_order_pdf_builder.dart';

class WorkOrderDetailView extends StatefulWidget {
  const WorkOrderDetailView({super.key, required this.order});

  final WorkOrder order;

  @override
  State<WorkOrderDetailView> createState() => _WorkOrderDetailViewState();
}

class _WorkOrderDetailViewState extends State<WorkOrderDetailView> {
  late final WorkOrderDetailViewModel _viewModel =
      getIt<WorkOrderDetailViewModel>();
  late WorkOrder _currentOrder = widget.order;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _printWorkOrder() async {
    await Printing.layoutPdf(
      onLayout: (format) => WorkOrderPdfBuilder.buildPdf(_currentOrder),
      name: 'Orden_Trabajo_${_currentOrder.displayCorrelative}.pdf',
    );
  }

  Future<void> _changeStatus(WorkOrderStatus status) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final ok = await _viewModel.updateStatus(
      order: _currentOrder,
      status: status,
      userId: user.userId,
      userName: user.username,
    );
    if (!mounted) return;

    if (ok) {
      setState(() {
        _currentOrder = _currentOrder.copyWith(status: status);
      });

      // Si se completó la OT y tiene un reporte de avería vinculado,
      // resolver la avería automáticamente.
      if (status == WorkOrderStatus.completed &&
          _currentOrder.reportId != null) {
        try {
          final resolveUseCase = getIt<ResolveBreakdownReportUseCase>();
          await resolveUseCase(
            ResolveBreakdownReportParams(
              reportId: _currentOrder.reportId!,
              resolvedByUserId: user.userId,
              resolvedByUserName: user.username,
            ),
          );
        } catch (_) {
          // La OT se completó correctamente; si la resolución
          // de la avería falla, no bloqueamos al usuario.
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado de la OT actualizado a ${status.name}.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_viewModel.errorMessage}')),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar orden de trabajo'),
        content: const Text('La OT se marcará como cancelada. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar OT'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _changeStatus(WorkOrderStatus.cancelled);
    }
  }

  Future<void> _editExecutionDetails() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final workDoneCtrl = TextEditingController(text: _currentOrder.workDoneDescription);
    final staffCtrl = TextEditingController(
      text: _currentOrder.assignedStaffCount != null ? _currentOrder.assignedStaffCount.toString() : '',
    );
    final hoursCtrl = TextEditingController(
      text: _currentOrder.estimatedHours != null ? _currentOrder.estimatedHours.toString() : '',
    );
    final accCtrl = TextEditingController(text: _currentOrder.accHaccpResponsible);
    final mtnCtrl = TextEditingController(text: _currentOrder.maintenanceResponsible);
    final areaHeadCtrl = TextEditingController(text: _currentOrder.areaHeadResponsible);
    final mtnHeadCtrl = TextEditingController(text: _currentOrder.maintenanceHeadResponsible);

    bool isCompleted = _currentOrder.isCompleted ?? true;
    final unfulfillmentCtrl = TextEditingController(text: _currentOrder.unfulfillmentReason);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Informe de Ejecución de Mantenimiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: staffCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Personal asignado',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hoursCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Horas reales',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: workDoneCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Trabajo realizado y observaciones *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('¿Se cumplió la tarea?'),
                  value: isCompleted,
                  onChanged: (val) => setDialogState(() => isCompleted = val),
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: unfulfillmentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del no cumplimiento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Responsables de Firma (Impresión)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: accCtrl,
                  decoration: const InputDecoration(
                    labelText: '1. Responsable de Calidad (ACC / HACCP)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mtnCtrl,
                  decoration: const InputDecoration(
                    labelText: '2. Resp. Mantenimiento (Ejecutor)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: areaHeadCtrl,
                  decoration: const InputDecoration(
                    labelText: '3. Jefe de Área',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mtnHeadCtrl,
                  decoration: const InputDecoration(
                    labelText: '4. Jefe de Mantenimiento',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar informe'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final updated = _currentOrder.copyWith(
        assignedStaffCount: int.tryParse(staffCtrl.text.trim()),
        estimatedHours: double.tryParse(hoursCtrl.text.trim()),
        workDoneDescription: workDoneCtrl.text.trim(),
        isCompleted: isCompleted,
        unfulfillmentReason: !isCompleted ? unfulfillmentCtrl.text.trim() : null,
        accHaccpResponsible: accCtrl.text.trim(),
        maintenanceResponsible: mtnCtrl.text.trim(),
        areaHeadResponsible: areaHeadCtrl.text.trim(),
        maintenanceHeadResponsible: mtnHeadCtrl.text.trim(),
      );

      final ok = await _viewModel.updateDetails(
        updatedOrder: updated,
        userId: user.userId,
        userName: user.username,
      );

      if (ok && mounted) {
        setState(() => _currentOrder = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe de mantenimiento guardado.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;
    final canPrint = context.watch<AuthViewModel>().hasPermission('work_order.print');

    return ChangeNotifierProvider<WorkOrderDetailViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: Text(order.displayCorrelative),
          actions: [
            if (canPrint)
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Imprimir Orden de Trabajo (REG.GMC-MTN-001)',
                onPressed: _printWorkOrder,
              ),
          ],
        ),
        body: _WorkOrderDetail(
          order: order,
          isProcessing: _viewModel.isProcessing,
          onStart: () => _changeStatus(WorkOrderStatus.inProgress),
          onComplete: () async {
            await _changeStatus(WorkOrderStatus.completed);
          },
          onCancel: _confirmCancel,
          onEditExecution: _editExecutionDetails,
          onPrint: canPrint ? _printWorkOrder : null,
        ),
      ),
    );
  }
}

class _WorkOrderDetail extends StatelessWidget {
  const _WorkOrderDetail({
    required this.order,
    required this.isProcessing,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
    required this.onEditExecution,
    this.onPrint,
  });

  final WorkOrder order;
  final bool isProcessing;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onEditExecution;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (order.status) {
      WorkOrderStatus.pending => Colors.orange,
      WorkOrderStatus.inProgress => Colors.blue,
      WorkOrderStatus.completed => Colors.green,
      WorkOrderStatus.cancelled => Colors.grey,
    };
    final priorityColor = switch (order.priority) {
      WorkOrderPriority.low => Colors.green,
      WorkOrderPriority.medium => Colors.orange,
      WorkOrderPriority.high => Colors.red,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _Tag(label: order.statusLabel, color: statusColor),
                        const SizedBox(width: 6),
                        _Tag(label: 'Prioridad ${order.priorityLabel}', color: priorityColor),
                      ],
                    ),
                    Text(
                      'REG.GMC-MTN-001',
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'N° Correlativo', value: order.displayCorrelative),
                _InfoRow(label: 'Activo', value: '${order.assetId} — ${order.assetName}'),
                if (order.areaId != null) _InfoRow(label: 'Área', value: order.areaId!),
                _InfoRow(label: 'Falla / Trabajo', value: order.description),
                if (order.requestedWorkTypes.isNotEmpty)
                  _InfoRow(
                    label: 'Tipos de trabajo',
                    value: order.requestedWorkTypes.map((t) => kWorkTypeLabels[t] ?? t).join(', '),
                  ),
                if (order.assignedTo != null && order.assignedTo!.isNotEmpty)
                  _InfoRow(label: 'Técnico Asignado', value: order.assignedTo!),
                if (order.assignedStaffCount != null)
                  _InfoRow(label: 'Personal asignado', value: '${order.assignedStaffCount} persona(s)'),
                if (order.estimatedHours != null)
                  _InfoRow(label: 'Horas requeridas', value: '${order.estimatedHours} hrs'),
                if (order.createdByUserName != null)
                  _InfoRow(label: 'Creada por', value: order.createdByUserName!),
                if (order.createdAt != null)
                  _InfoRow(
                    label: 'Fecha Emisión',
                    value: '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // --- Materiales y Refacciones Registradas ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Materiales, Refacciones y Herramientas a utilizar',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (order.materials.isEmpty)
                  const Text('Sin refacciones registradas.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                else
                  Column(
                    children: order.materials.asMap().entries.map((e) {
                      final mat = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text('${e.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(child: Text(mat.description)),
                            Text('${mat.quantity} ${mat.unit}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // --- Informe de Mantenimiento ---
        if (order.workDoneDescription != null || order.isCompleted != null)
          Card(
            color: Colors.green.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informe de Mantenimiento Ejecutado',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (order.workDoneDescription != null)
                    _InfoRow(label: 'Trabajo Realizado', value: order.workDoneDescription!),
                  if (order.isCompleted != null)
                    _InfoRow(label: 'Cumplimiento', value: order.isCompleted! ? 'Sí' : 'No'),
                  if (order.unfulfillmentReason != null)
                    _InfoRow(label: 'Motivo No Cumplimiento', value: order.unfulfillmentReason!),
                  if (order.accHaccpResponsible != null && order.accHaccpResponsible!.isNotEmpty)
                    _InfoRow(label: '1. Resp. Calidad', value: order.accHaccpResponsible!),
                  if (order.maintenanceResponsible != null && order.maintenanceResponsible!.isNotEmpty)
                    _InfoRow(label: '2. Resp. Mantenimiento', value: order.maintenanceResponsible!),
                  if (order.areaHeadResponsible != null && order.areaHeadResponsible!.isNotEmpty)
                    _InfoRow(label: '3. Jefe de Área', value: order.areaHeadResponsible!),
                  if (order.maintenanceHeadResponsible != null && order.maintenanceHeadResponsible!.isNotEmpty)
                    _InfoRow(label: '4. Jefe Mantenimiento', value: order.maintenanceHeadResponsible!),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        if (onPrint != null) ...[
          FilledButton.icon(
            onPressed: onPrint,
            icon: const Icon(Icons.print),
            label: const Text('Imprimir Orden de Trabajo (REG.GMC-MTN-001)'),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
          ),
          const SizedBox(height: 8),
        ],

        if (order.status == WorkOrderStatus.inProgress) ...[
          OutlinedButton.icon(
            onPressed: onEditExecution,
            icon: const Icon(Icons.edit_note),
            label: const Text('Registrar informe de ejecución / firmas'),
          ),
          const SizedBox(height: 12),
        ],

        if (order.status == WorkOrderStatus.pending) ...[
          FilledButton.icon(
            onPressed: isProcessing ? null : onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar trabajo (En Progreso)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isProcessing ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar OT'),
          ),
        ],
        if (order.status == WorkOrderStatus.inProgress) ...[
          if (order.workDoneDescription == null ||
              order.workDoneDescription!.trim().isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Debes registrar el informe de ejecución antes de completar la OT.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: isProcessing ||
                    order.workDoneDescription == null ||
                    order.workDoneDescription!.trim().isEmpty
                ? null
                : onComplete,
            icon: const Icon(Icons.check),
            label: const Text('Marcar como completada'),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppInfoRow(
      label: label,
      value: Text(value),
      labelWidth: 140,
      labelStyle: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
