import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../breakdown_reports/domain/usecases/resolve_breakdown_report.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_create_viewmodel.dart';
import '../viewmodels/work_order_detail_viewmodel.dart';
import 'work_order_pdf_builder.dart';

/// Vista ejecutiva de detalle y control de una Orden de Trabajo (REG.GMC-MTN-001).
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
          // La OT se completó correctamente
        }
      }

      if (!mounted) return;
      final statusLabel = switch (status) {
        WorkOrderStatus.pending => 'Pendiente',
        WorkOrderStatus.inProgress => 'En Progreso',
        WorkOrderStatus.completed => 'Completada',
        WorkOrderStatus.cancelled => 'Cancelada',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text('Estado de la OT actualizado a $statusLabel.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Error: ${_viewModel.errorMessage}'),
        ),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar orden de trabajo'),
        content: const Text('La OT se marcará como cancelada en el sistema. ¿Deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF0055A5)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Informe de Ejecución de Mantenimiento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: staffCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Personal asignado',
                            hintText: 'Cant. técnicos',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hoursCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Horas reales',
                            hintText: 'Ej: 2.0',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: workDoneCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Trabajo realizado y observaciones *',
                      hintText: 'Detalla las reparaciones, ajustes o cambios de piezas ejecutados...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      title: const Text('¿Trabajo 100% Completado?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isCompleted
                            ? 'La orden cumplió a cabalidad con lo solicitado.'
                            : 'Hubo pendientes o no se completó totalmente.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                      value: isCompleted,
                      onChanged: (val) => setDialogState(() => isCompleted = val),
                    ),
                  ),
                  if (!isCompleted) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: unfulfillmentCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Motivo del no cumplimiento *',
                        hintText: 'Falta de repuestos, tiempo insuficiente...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Firmas y Responsables:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: accCtrl,
                    decoration: InputDecoration(
                      labelText: '1. Responsable Calidad / HACCP',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mtnCtrl,
                    decoration: InputDecoration(
                      labelText: '2. Responsable Mantenimiento (Ejecutor)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: areaHeadCtrl,
                    decoration: InputDecoration(
                      labelText: '3. Jefe de Área (Recepción)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mtnHeadCtrl,
                    decoration: InputDecoration(
                      labelText: '4. Jefe de Mantenimiento (Aprobación)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar Informe'),
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
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: const Color(0xFF16A34A),
            content: const Text('Informe de mantenimiento guardado.'),
          ),
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
          title: Row(
            children: [
              Text(order.displayCorrelative, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'REG.GMC-MTN-001',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            if (canPrint)
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: 'Imprimir Orden de Trabajo (PDF)',
                onPressed: _printWorkOrder,
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: _WorkOrderDetail(
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
      WorkOrderStatus.pending => const Color(0xFFD97706),
      WorkOrderStatus.inProgress => const Color(0xFF0284C7),
      WorkOrderStatus.completed => const Color(0xFF16A34A),
      WorkOrderStatus.cancelled => const Color(0xFF64748B),
    };
    final priorityColor = switch (order.priority) {
      WorkOrderPriority.low => const Color(0xFF16A34A),
      WorkOrderPriority.medium => const Color(0xFFD97706),
      WorkOrderPriority.high => const Color(0xFFDC2626),
    };

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Header Card Principal de la OT
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: statusColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              order.displayCorrelative,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            _Tag(label: order.statusLabel, color: statusColor),
                            _Tag(label: 'Prioridad ${order.priorityLabel}', color: priorityColor),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (order.isPreventive)
                              _Tag(
                                label: order.preventiveScheduleId != null && order.preventiveScheduleId!.isNotEmpty
                                    ? 'Preventivo: ${order.preventiveScheduleId}'
                                    : 'Mantenimiento Preventivo',
                                color: const Color(0xFF0055A5),
                              )
                            else
                              _Tag(
                                label: order.reportId != null && order.reportId!.isNotEmpty
                                    ? 'Avería #${order.reportId}'
                                    : 'Mantenimiento Correctivo',
                                color: const Color(0xFFD97706),
                              ),
                            if (order.createdAt != null)
                              Text(
                                'Emitida: ${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Información del Activo y Solicitud
              _InfoTile(icon: Icons.precision_manufacturing_outlined, label: 'Activo / Equipo', value: '${order.assetId} — ${order.assetName}'),
              if (order.areaId != null && order.areaId!.isNotEmpty)
                _InfoTile(icon: Icons.business_outlined, label: 'Área Operativa', value: order.areaId!),
              _InfoTile(icon: Icons.notes_outlined, label: 'Falla o Trabajo', value: order.description),
              if (order.requestedWorkTypes.isNotEmpty)
                _InfoTile(
                  icon: Icons.build_circle_outlined,
                  label: 'Tipos de Trabajo',
                  value: order.requestedWorkTypes.map((t) => kWorkTypeLabels[t] ?? t).join(', '),
                ),
              if (order.assignedTo != null && order.assignedTo!.isNotEmpty)
                _InfoTile(icon: Icons.person_outline, label: 'Técnico Asignado', value: order.assignedTo!),
              if (order.assignedStaffCount != null || order.estimatedHours != null)
                _InfoTile(
                  icon: Icons.access_time_outlined,
                  label: 'Estimación',
                  value: '${order.assignedStaffCount ?? 0} personas | ${order.estimatedHours ?? 0} hrs estimadas',
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tarjeta de Materiales y Refacciones
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade300, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Materiales, Refacciones y Herramientas',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (order.materials.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      'Sin materiales ni refacciones registrados en esta orden.',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey.shade600),
                    ),
                  )
                else
                  Column(
                    children: order.materials.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final mat = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: idx > 0 ? Border(top: BorderSide(color: Colors.grey.shade200)) : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(mat.description, style: const TextStyle(fontSize: 13))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${mat.quantity} ${mat.unit}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Informe de Mantenimiento Ejecutado
        if (order.workDoneDescription != null || order.isCompleted != null) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
            ),
            color: const Color(0xFFF0FDF4),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF16A34A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Informe de Mantenimiento Ejecutado',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (order.workDoneDescription != null)
                    _InfoTile(icon: Icons.task_alt, label: 'Trabajo Realizado', value: order.workDoneDescription!),
                  if (order.isCompleted != null)
                    _InfoTile(
                      icon: Icons.check_circle_outline,
                      label: 'Cumplimiento',
                      value: order.isCompleted! ? '100% Completado' : 'Incompleto / Pendiente',
                    ),
                  if (order.unfulfillmentReason != null)
                    _InfoTile(icon: Icons.warning_amber_outlined, label: 'Motivo No Cumplimiento', value: order.unfulfillmentReason!),
                  if (order.accHaccpResponsible != null && order.accHaccpResponsible!.isNotEmpty)
                    _InfoTile(icon: Icons.verified_user_outlined, label: '1. Calidad / HACCP', value: order.accHaccpResponsible!),
                  if (order.maintenanceResponsible != null && order.maintenanceResponsible!.isNotEmpty)
                    _InfoTile(icon: Icons.engineering_outlined, label: '2. Ejecutor Mantenimiento', value: order.maintenanceResponsible!),
                  if (order.areaHeadResponsible != null && order.areaHeadResponsible!.isNotEmpty)
                    _InfoTile(icon: Icons.person_pin_outlined, label: '3. Jefe de Área', value: order.areaHeadResponsible!),
                  if (order.maintenanceHeadResponsible != null && order.maintenanceHeadResponsible!.isNotEmpty)
                    _InfoTile(icon: Icons.admin_panel_settings_outlined, label: '4. Jefe Mantenimiento', value: order.maintenanceHeadResponsible!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Botones de Acción
        if (onPrint != null)
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Imprimir Orden de Trabajo Oficial (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

        const SizedBox(height: 10),

        if (order.status == WorkOrderStatus.inProgress) ...[
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onEditExecution,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Registrar Informe de Ejecución / Firmas'),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (order.status == WorkOrderStatus.pending) ...[
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: isProcessing ? null : onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Iniciar Trabajo (Pasar a En Progreso)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              onPressed: isProcessing ? null : onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancelar Orden de Trabajo'),
            ),
          ),
        ],

        if (order.status == WorkOrderStatus.inProgress) ...[
          if (order.workDoneDescription == null || order.workDoneDescription!.trim().isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Debes registrar el informe de ejecución antes de marcar la OT como completada.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: isProcessing ||
                      order.workDoneDescription == null ||
                      order.workDoneDescription!.trim().isEmpty
                  ? null
                  : onComplete,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Completar y Cerrar Orden de Trabajo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
