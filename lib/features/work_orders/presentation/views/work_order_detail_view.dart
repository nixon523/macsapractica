import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../app/widgets/app_dialog.dart';
import '../../../../app/widgets/app_feedback.dart';
import '../../../assets/presentation/views/widgets/asset_image_widget.dart';
import '../../../auth_permissions/domain/entities/user_role.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../breakdown_reports/domain/usecases/resolve_breakdown_report.dart';
import '../../../employees/presentation/viewmodels/employee_list_viewmodel.dart';
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

  Future<void> _changeStatus(
    WorkOrderStatus status, {
    String? motivoPausa,
    String? motivoReprogramacion,
    DateTime? fechaReprogramacion,
    double? horasReales,
    String? trabajoRealizado,
    String? observaciones,
  }) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final ok = await _viewModel.updateStatus(
      order: _currentOrder,
      status: status,
      userId: user.userId,
      userName: user.username,
      motivoPausa: motivoPausa,
      motivoReprogramacion: motivoReprogramacion,
      fechaReprogramacion: fechaReprogramacion,
      horasReales: horasReales,
      trabajoRealizado: trabajoRealizado,
      observaciones: observaciones,
    );
    if (!mounted) return;

    if (ok) {
      setState(() {
        _currentOrder = _currentOrder.copyWith(
          status: status,
          motivoPausa: motivoPausa ?? (status == WorkOrderStatus.inProgress ? null : _currentOrder.motivoPausa),
          unfulfillmentReason: motivoReprogramacion ?? _currentOrder.unfulfillmentReason,
          reprogramDate: fechaReprogramacion ?? _currentOrder.reprogramDate,
          actualHours: horasReales ?? _currentOrder.actualHours,
          workDoneDescription: trabajoRealizado ?? _currentOrder.workDoneDescription,
          fechaInicioReal: (status == WorkOrderStatus.inProgress && _currentOrder.fechaInicioReal == null)
              ? DateTime.now()
              : _currentOrder.fechaInicioReal,
          fechaFinReal: (status == WorkOrderStatus.reviewPending || status == WorkOrderStatus.completed)
              ? DateTime.now()
              : _currentOrder.fechaFinReal,
          aprobadoPorNombreUsuario: status == WorkOrderStatus.completed
              ? (user.displayName != null && user.displayName!.isNotEmpty
                  ? user.displayName!
                  : user.username)
              : _currentOrder.aprobadoPorNombreUsuario,
          aprobadoEn: status == WorkOrderStatus.completed
              ? DateTime.now()
              : _currentOrder.aprobadoEn,
        );
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
      AppFeedback.showSuccess(
        context,
        'Estado de la OT actualizado a ${_currentOrder.statusLabel}.',
      );
    } else {
      AppFeedback.showError(
        context,
        'Error: ${_viewModel.errorMessage}',
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

  Future<void> _showPauseDialog() async {
    final reasons = [
      'Esperando refacción / material de almacén',
      'Equipo requerido por producción temporalmente',
      'Cambio de turno / hora de comida',
      'Atención a avería de mayor urgencia',
      'Otro motivo...',
    ];
    String selectedReason = reasons.first;
    final customCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.pause_circle_outline, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Pausar Trabajo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'El cronómetro de trabajo activo se detendrá. Selecciona o escribe el motivo:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: InputDecoration(
                  labelText: 'Motivo de la pausa',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
              ),
              if (selectedReason == 'Otro motivo...') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: customCtrl,
                  maxLines: 2,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Escribe el motivo específico *',
                    hintText: 'Describe brevemente la razón de la pausa...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              onPressed: () {
                if (selectedReason == 'Otro motivo...' && customCtrl.text.trim().isEmpty) {
                  AppFeedback.showWarning(ctx, 'Por favor escribe el motivo de la pausa.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Pausar Trabajo'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final reason = selectedReason == 'Otro motivo...' ? customCtrl.text.trim() : selectedReason;
      await _changeStatus(WorkOrderStatus.paused, motivoPausa: reason);
    }
  }

  Future<void> _showRescheduleDialog() async {
    DateTime selectedDate = _currentOrder.scheduledDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController(text: _currentOrder.unfulfillmentReason ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: Color(0xFF0055A5)),
              SizedBox(width: 8),
              Text('Reprogramar OT'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Indica la nueva fecha programada y el motivo:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  'Nueva Fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motivo de reprogramación *',
                  hintText: 'Ej: Falta de refacciones, línea en producción...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  AppFeedback.showWarning(ctx, 'Debes ingresar el motivo de la reprogramación.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Reprogramar OT'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await _changeStatus(
        WorkOrderStatus.rescheduled,
        fechaReprogramacion: selectedDate,
        motivoReprogramacion: reasonCtrl.text.trim(),
      );
    }
  }

  Future<void> _approveAndClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_outlined, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Aprobar y Cerrar OT'),
          ],
        ),
        content: Text(
          '¿Confirmas la aprobación del informe técnico y el cierre formal de la orden ${_currentOrder.displayCorrelative}? Esta acción quedará registrada en Kardex.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar y Cerrar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _changeStatus(WorkOrderStatus.completed);
    }
  }

  Future<void> _reopenOrder() async {
    final obsCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_return_outlined, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Reabrir Orden de Trabajo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Indica las observaciones o detalles que el personal técnico debe corregir o completar:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obsCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Observaciones / Pendientes *',
                hintText: 'Detalla qué falta por resolver...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              if (obsCtrl.text.trim().isEmpty) {
                AppFeedback.showWarning(ctx, 'Debes ingresar las observaciones.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Reabrir a En Progreso'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _changeStatus(WorkOrderStatus.inProgress, observaciones: obsCtrl.text.trim());
    }
  }

  Future<void> _editExecutionDetails() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    // Calcular horas reales automáticamente a partir de la fecha de inicio y pausas
    double calculatedHours = _currentOrder.actualHours ?? _currentOrder.estimatedHours ?? 1.0;
    if (_currentOrder.fechaInicioReal != null) {
      final now = DateTime.now();
      final totalMinutes = now.difference(_currentOrder.fechaInicioReal!).inMinutes - _currentOrder.minutosPausaAcumulados;
      final positiveMins = totalMinutes > 0 ? totalMinutes : 1;
      calculatedHours = double.parse((positiveMins / 60.0).toStringAsFixed(2));
    }

    final workDoneCtrl = TextEditingController(text: _currentOrder.workDoneDescription);
    final hoursCtrl = TextEditingController(text: calculatedHours.toStringAsFixed(2));

    final initialMtn = (_currentOrder.maintenanceResponsible != null && _currentOrder.maintenanceResponsible!.trim().isNotEmpty)
        ? _currentOrder.maintenanceResponsible!
        : (_currentOrder.assignedTo ?? '');
    final mtnCtrl = TextEditingController(text: initialMtn);
    final areaHeadCtrl = TextEditingController(text: _currentOrder.areaHeadResponsible);
    final mtnHeadCtrl = TextEditingController(text: _currentOrder.maintenanceHeadResponsible);

    bool isCompleted = _currentOrder.isCompleted ?? true;
    final unfulfillmentCtrl = TextEditingController(text: _currentOrder.unfulfillmentReason);

    int getTechCount() => mtnCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).length;

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
                  'Informe Técnico de Ejecución',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Resumen automático de tiempo y personal
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 20, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tiempo activo calculado: ${calculatedHours.toStringAsFixed(2)} h · Personal: ${getTechCount() > 0 ? getTechCount() : 1} técnico(s)',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: hoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Horas reales invertidas *',
                        hintText: 'Ej: 1.75',
                        suffixText: 'h',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
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
                    const Text('Técnicos Ejecutores y Firmas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: mtnCtrl,
                      decoration: InputDecoration(
                        labelText: 'Personal Mantenimiento (Ejecutores)',
                        hintText: 'Ej: Carlos Hernández, Jorge Morales...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF0055A5)),
                          tooltip: 'Seleccionar / Modificar técnicos del catálogo',
                          onPressed: () async {
                            final empVm = context.read<EmployeeListViewModel>();
                            if (empVm.employees.isEmpty) {
                              await empVm.loadEmployees();
                            }
                            final techList = empVm.maintenanceTechnicians;
                            if (techList.isEmpty || !context.mounted) return;

                            final currentTechs = mtnCtrl.text
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toSet();

                            await showDialog(
                              context: context,
                              builder: (ctx) => StatefulBuilder(
                                builder: (ctx, setMulti) => AppDialog(
                                  maxWidth: 440,
                                  icon: const Icon(Icons.engineering, color: Color(0xFF0055A5)),
                                  title: const Text('Asignar Técnicos Ejecutores'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: techList.map((t) {
                                      final isChecked = currentTechs.contains(t.fullName);
                                      return CheckboxListTile(
                                        value: isChecked,
                                        dense: true,
                                        activeColor: const Color(0xFF0055A5),
                                        title: Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        subtitle: Text(t.position, style: const TextStyle(fontSize: 11)),
                                        onChanged: (val) {
                                          setMulti(() {
                                            if (val == true) {
                                              currentTechs.add(t.fullName);
                                            } else {
                                              currentTechs.remove(t.fullName);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
                                      onPressed: () {
                                        setDialogState(() {
                                          mtnCtrl.text = currentTechs.join(', ');
                                        });
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Aceptar'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: areaHeadCtrl,
                      decoration: InputDecoration(
                        labelText: 'Jefe de Área (Recepción de conformidad)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: mtnHeadCtrl,
                      decoration: InputDecoration(
                        labelText: 'Jefe de Mantenimiento (Aprobación)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.send_rounded, size: 16),
              onPressed: () {
                if (workDoneCtrl.text.trim().isEmpty) {
                  AppFeedback.showWarning(
                    context,
                    'El campo "Trabajo realizado y observaciones" es obligatorio.',
                  );
                  return;
                }
                if (!isCompleted && unfulfillmentCtrl.text.trim().isEmpty) {
                  AppFeedback.showWarning(
                    context,
                    'Debes especificar el motivo del no cumplimiento.',
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              label: const Text('Enviar Informe a Revisión'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final hoursVal = double.tryParse(hoursCtrl.text.trim()) ?? calculatedHours;
      final staffCount = getTechCount() > 0 ? getTechCount() : 1;
      final updated = _currentOrder.copyWith(
        assignedStaffCount: staffCount,
        actualHours: hoursVal,
        workDoneDescription: workDoneCtrl.text.trim(),
        isCompleted: isCompleted,
        unfulfillmentReason: !isCompleted ? unfulfillmentCtrl.text.trim() : null,
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
        // Transicionar automáticamente a reviewPending (enviada a revisión)
        await _changeStatus(
          WorkOrderStatus.reviewPending,
          horasReales: hoursVal,
          trabajoRealizado: workDoneCtrl.text.trim(),
        );
      } else if (mounted) {
        AppFeedback.showError(
          context,
          _viewModel.errorMessage.isNotEmpty
              ? 'Error al guardar el informe: ${_viewModel.errorMessage}'
              : 'No se pudo guardar el informe de mantenimiento en el servidor.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;
    final authVm = context.watch<AuthViewModel>();
    final canPrint = authVm.hasPermission(AppPermissions.workOrderPrint);
    final canExecute = authVm.hasPermission(AppPermissions.workOrderExecute) ||
        authVm.hasPermission(AppPermissions.workOrderCreate);
    final canApprove = authVm.hasPermission(AppPermissions.workOrderApprove) ||
        authVm.currentUser?.role == UserRole.admin ||
        authVm.currentUser?.role == UserRole.jefe;
    final canCancel = authVm.hasPermission(AppPermissions.workOrderCreate);

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
              canExecute: canExecute,
              canApprove: canApprove,
              canCancel: canCancel,
              onStart: () => _changeStatus(WorkOrderStatus.inProgress),
              onPause: _showPauseDialog,
              onResume: () => _changeStatus(WorkOrderStatus.inProgress),
              onFinishReport: _editExecutionDetails,
              onReschedule: _showRescheduleDialog,
              onApprove: _approveAndClose,
              onReopen: _reopenOrder,
              onCancel: _confirmCancel,
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
    required this.canExecute,
    required this.canApprove,
    required this.canCancel,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinishReport,
    required this.onReschedule,
    required this.onApprove,
    required this.onReopen,
    required this.onCancel,
    this.onPrint,
  });

  final WorkOrder order;
  final bool isProcessing;
  final bool canExecute;
  final bool canApprove;
  final bool canCancel;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinishReport;
  final VoidCallback onReschedule;
  final VoidCallback onApprove;
  final VoidCallback onReopen;
  final VoidCallback onCancel;
  final VoidCallback? onPrint;

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black87,
                  constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
                  child: AssetImageWidget(
                    imageData: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (order.status) {
      WorkOrderStatus.pending => const Color(0xFFD97706),
      WorkOrderStatus.inProgress => const Color(0xFF0284C7),
      WorkOrderStatus.paused => const Color(0xFFE65100),
      WorkOrderStatus.reviewPending => const Color(0xFF7C3AED),
      WorkOrderStatus.completed => const Color(0xFF16A34A),
      WorkOrderStatus.cancelled => const Color(0xFF64748B),
      WorkOrderStatus.unfulfilled => const Color(0xFFDC2626),
      WorkOrderStatus.rescheduled => const Color(0xFF0284C7),
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
              if (order.breakdownImageData != null && order.breakdownImageData!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _showImageDialog(context, order.breakdownImageData!),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0055A5).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 58,
                            height: 58,
                            child: AssetImageWidget(
                              imageData: order.breakdownImageData,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.photo_camera_outlined, size: 15, color: Color(0xFF0055A5)),
                                  const SizedBox(width: 6),
                                  Text(
                                    order.reportId != null && order.reportId!.isNotEmpty
                                        ? 'Evidencia de Avería #${order.reportId}'
                                        : 'Evidencia Fotográfica de la Falla',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0055A5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Fotografía capturada al reportar la incidencia. Toca para examinar en detalle.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.zoom_in, color: Color(0xFF0055A5), size: 22),
                      ],
                    ),
                  ),
                ),
              ],
              if (order.requestedWorkTypes.isNotEmpty)
                _InfoTile(
                  icon: Icons.build_circle_outlined,
                  label: 'Tipos de Trabajo',
                  value: order.requestedWorkTypes.map((t) => kWorkTypeLabels[t] ?? t).join(', '),
                ),
              if (order.assignedTo != null && order.assignedTo!.isNotEmpty)
                _InfoTile(icon: Icons.person_outline, label: 'Técnico(s) Asignado(s)', value: order.assignedTo!),
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
                  if (order.actualHours != null && order.actualHours! > 0)
                    _InfoTile(
                      icon: Icons.timer_outlined,
                      label: 'Tiempo Real Invertido',
                      value: '${order.actualHours} horas' +
                          (order.minutosPausaAcumulados > 0
                              ? ' (${order.minutosPausaAcumulados} min pausados)'
                              : ''),
                    ),
                  if (order.fechaInicioReal != null)
                    _InfoTile(
                      icon: Icons.play_circle_outline,
                      label: 'Inicio Real',
                      value: _formatDateTime(order.fechaInicioReal),
                    ),
                  if (order.fechaFinReal != null)
                    _InfoTile(
                      icon: Icons.flag_outlined,
                      label: 'Fin Real',
                      value: _formatDateTime(order.fechaFinReal),
                    ),
                  if (order.aprobadoPorNombreUsuario != null)
                    _InfoTile(
                      icon: Icons.verified_user_outlined,
                      label: 'Aprobado Por',
                      value: '${order.aprobadoPorNombreUsuario!}${order.aprobadoEn != null ? " (${_formatDateTime(order.aprobadoEn)})" : ""}',
                    ),
                  if (order.unfulfillmentReason != null)
                    _InfoTile(icon: Icons.warning_amber_outlined, label: 'Motivo No Cumplimiento', value: order.unfulfillmentReason!),
                  if (order.maintenanceResponsible != null && order.maintenanceResponsible!.isNotEmpty)
                    _InfoTile(icon: Icons.engineering_outlined, label: '1. Ejecutor(es) Mantenimiento', value: order.maintenanceResponsible!),
                  if (order.areaHeadResponsible != null && order.areaHeadResponsible!.isNotEmpty)
                    _InfoTile(icon: Icons.person_pin_outlined, label: '2. Jefe de Área', value: order.areaHeadResponsible!),
                  if (order.maintenanceHeadResponsible != null && order.maintenanceHeadResponsible!.isNotEmpty)
                    _InfoTile(icon: Icons.admin_panel_settings_outlined, label: '3. Jefe Mantenimiento', value: order.maintenanceHeadResponsible!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Botones de Acción y Estados de Flujo
        if (onPrint != null) ...[
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Imprimir Orden de Trabajo Oficial (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 1. Estado: PENDIENTE
        if (order.status == WorkOrderStatus.pending) ...[
          if (canExecute) ...[
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
                onPressed: isProcessing ? null : onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Iniciar Trabajo (Pasar a En Progreso)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : onReschedule,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Reprogramar Trabajo'),
              ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                onPressed: isProcessing ? null : onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancelar Orden de Trabajo'),
              ),
            ),
          ],
        ],

        // 2. Estado: EN PROGRESO
        if (order.status == WorkOrderStatus.inProgress) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF7DD3FC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFF0369A1), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trabajo en progreso activo',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0369A1), fontSize: 13),
                      ),
                      Text(
                        order.fechaInicioReal != null
                            ? 'Iniciado: ${_formatDateTime(order.fechaInicioReal)}' +
                                (order.minutosPausaAcumulados > 0
                                    ? ' (${order.minutosPausaAcumulados} min pausados)'
                                    : '')
                            : 'El contador de tiempo está corriendo.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canExecute) ...[
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                onPressed: isProcessing ? null : onFinishReport,
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 20),
                label: const Text(
                  'Finalizar Informe Técnico (Enviar a Revisión)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE65100)),
                      onPressed: isProcessing ? null : onPause,
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: const Text('Pausar Trabajo'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : onReschedule,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('Reprogramar'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],

        // 3. Estado: PAUSADO
        if (order.status == WorkOrderStatus.paused) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pause_circle_filled, color: Color(0xFFC2410C), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trabajo Pausado',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2410C), fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Motivo: ${order.motivoPausa ?? "Sin motivo especificado"}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      if (order.fechaUltimaPausa != null)
                        Text(
                          'Pausado desde: ${_formatDateTime(order.fechaUltimaPausa)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canExecute) ...[
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
                onPressed: isProcessing ? null : onResume,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Reanudar Trabajo', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : onReschedule,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Reprogramar Trabajo'),
              ),
            ),
          ],
        ],

        // 4. Estado: REVISIÓN PENDIENTE (POR VALIDAR)
        if (order.status == WorkOrderStatus.reviewPending) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_top_rounded, color: Color(0xFF7C3AED), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informe Técnico Enviado — Pendiente de Aprobación',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B21A8), fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'El trabajo fue concluido por el personal técnico. Requiere validación y cierre formal por parte de la Jefatura de Mantenimiento.',
                        style: TextStyle(color: Color(0xFF581C87), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canApprove) ...[
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                onPressed: isProcessing ? null : onApprove,
                icon: const Icon(Icons.check_circle_outline, size: 22),
                label: const Text(
                  'Aprobar y Cerrar Orden de Trabajo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                      onPressed: isProcessing ? null : onReopen,
                      icon: const Icon(Icons.replay_outlined, size: 18),
                      label: const Text('Reabrir / Devolver'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : onFinishReport,
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Editar Informe'),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu informe técnico fue registrado. Espera a que el Jefe de Mantenimiento revise y apruebe el cierre.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        // 5. Estado: REPROGRAMADO
        if (order.status == WorkOrderStatus.rescheduled) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_repeat_outlined, color: Color(0xFF0284C7), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orden de Trabajo Reprogramada',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0369A1), fontSize: 13),
                      ),
                      if (order.scheduledDate != null)
                        Text(
                          'Nueva Fecha: ${_formatDateTime(order.scheduledDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canExecute) ...[
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
                onPressed: isProcessing ? null : onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Iniciar Trabajo Reprogramado', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : onReschedule,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Reprogramar Nuevamente'),
              ),
            ),
          ],
        ],

        // 6. Estado: COMPLETADO
        if (order.status == WorkOrderStatus.completed) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFF16A34A), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orden de Trabajo Aprobada y Cerrada',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14532D), fontSize: 13),
                      ),
                      if (order.aprobadoPorNombreUsuario != null)
                        Text(
                          'Aprobada por: ${order.aprobadoPorNombreUsuario}${order.aprobadoEn != null ? " el ${_formatDateTime(order.aprobadoEn)}" : ""}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                        ),
                    ],
                  ),
                ),
              ],
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

String _formatDateTime(DateTime? dt) {
  if (dt == null) return '';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $hh:$mm';
}
