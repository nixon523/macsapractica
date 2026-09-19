import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../breakdown_reports/domain/entities/breakdown_report.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_create_viewmodel.dart';

/// Vista para crear u originar una Orden de Trabajo oficial (REG.GMC-MTN-001).
class WorkOrderCreateView extends StatefulWidget {
  const WorkOrderCreateView({
    super.key,
    this.report,
    this.preventiveSchedule,
  });

  /// Reporte de avería que origina la OT.
  final BreakdownReport? report;

  /// Plan preventivo que origina la OT.
  final dynamic preventiveSchedule;

  @override
  State<WorkOrderCreateView> createState() => _WorkOrderCreateViewState();
}

class _WorkOrderCreateViewState extends State<WorkOrderCreateView> {
  late final WorkOrderCreateViewModel _viewModel =
      getIt<WorkOrderCreateViewModel>();

  @override
  void initState() {
    super.initState();
    if (widget.preventiveSchedule != null) {
      _viewModel.initFromPreventiveSchedule(widget.preventiveSchedule);
    } else {
      _viewModel.initFromReport(widget.report);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final created = await _viewModel.submit(
      userId: user.userId,
      userName: user.username,
    );
    if (!mounted) return;

    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF16A34A),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Orden de Trabajo ${created.displayCorrelative} creada con éxito.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } else if (_viewModel.errorMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFFDC2626),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _viewModel.errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.report != null
        ? 'Generar OT desde Avería'
        : (widget.preventiveSchedule != null
            ? 'Generar OT desde Preventivo'
            : 'Nueva Orden de Trabajo');

    return ChangeNotifierProvider<WorkOrderCreateViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: _WorkOrderCreateForm(
              viewModel: _viewModel,
              onSubmit: _submit,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkOrderCreateForm extends StatefulWidget {
  const _WorkOrderCreateForm({required this.viewModel, this.onSubmit});

  final WorkOrderCreateViewModel viewModel;
  final Future<void> Function()? onSubmit;

  @override
  State<_WorkOrderCreateForm> createState() => _WorkOrderCreateFormState();
}

class _WorkOrderCreateFormState extends State<_WorkOrderCreateForm> {
  late final TextEditingController _assetIdCtrl;
  late final TextEditingController _assetNameCtrl;
  late final TextEditingController _areaIdCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _assignedToCtrl;
  late final TextEditingController _assignedStaffCountCtrl;
  late final TextEditingController _estimatedHoursCtrl;

  final TextEditingController _matDescCtrl = TextEditingController();
  final TextEditingController _matQtyCtrl = TextEditingController(text: '1');
  String _matUnit = 'pz';

  @override
  void initState() {
    super.initState();
    final vm = widget.viewModel;
    _assetIdCtrl = TextEditingController(text: vm.assetId);
    _assetNameCtrl = TextEditingController(text: vm.assetName);
    _areaIdCtrl = TextEditingController(text: vm.areaId);
    _descriptionCtrl = TextEditingController(text: vm.description);
    _assignedToCtrl = TextEditingController(text: vm.assignedTo);
    _assignedStaffCountCtrl = TextEditingController(
      text: vm.assignedStaffCount != null ? vm.assignedStaffCount.toString() : '',
    );
    _estimatedHoursCtrl = TextEditingController(
      text: vm.estimatedHours != null ? vm.estimatedHours.toString() : '',
    );
  }

  @override
  void dispose() {
    _assetIdCtrl.dispose();
    _assetNameCtrl.dispose();
    _areaIdCtrl.dispose();
    _descriptionCtrl.dispose();
    _assignedToCtrl.dispose();
    _assignedStaffCountCtrl.dispose();
    _estimatedHoursCtrl.dispose();
    _matDescCtrl.dispose();
    _matQtyCtrl.dispose();
    super.dispose();
  }

  void _addMaterial() {
    final desc = _matDescCtrl.text.trim();
    final qty = double.tryParse(_matQtyCtrl.text.trim()) ?? 1.0;
    if (desc.isNotEmpty) {
      widget.viewModel.addMaterial(desc, qty, unit: _matUnit);
      _matDescCtrl.clear();
      _matQtyCtrl.text = '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkOrderCreateViewModel>();
    final isFromReport = vm.report != null;
    final isFromPreventive = vm.preventiveSchedule != null;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Header Banner Oficial REG.GMC-MTN-001
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.08),
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Formulario de Orden de Trabajo',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.5,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'REG.GMC-MTN-001',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (isFromReport)
                      Text(
                        'Generando orden correctiva a partir de la Avería #${vm.report!.id}. El reporte se vinculará y se resolverá automáticamente al cerrar la OT.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                      )
                    else if (isFromPreventive)
                      Text(
                        'Generando orden a partir del Plan Preventivo PM-${vm.preventiveSchedule.id}.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                      )
                    else
                      Text(
                        'Completa los datos del equipo y las instrucciones de intervención para emitir la orden formal de mantenimiento.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Bloque 1: Datos del Solicitante y Equipo
        _FormCard(
          title: '1. Datos del Solicitante y Equipo',
          icon: Icons.precision_manufacturing_outlined,
          theme: theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const Key('ot-asset-id'),
                      enabled: !isFromReport && !isFromPreventive,
                      controller: _assetIdCtrl,
                      onChanged: vm.setAssetId,
                      decoration: InputDecoration(
                        labelText: 'ID del activo *',
                        hintText: 'Ej: A001-001',
                        prefixIcon: const Icon(Icons.tag, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      key: const Key('ot-asset-name'),
                      enabled: !isFromReport && !isFromPreventive,
                      controller: _assetNameCtrl,
                      onChanged: vm.setAssetName,
                      decoration: InputDecoration(
                        labelText: 'Nombre del activo',
                        hintText: 'Nombre o descripción',
                        prefixIcon: const Icon(Icons.settings_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _areaIdCtrl,
                enabled: !isFromReport && !isFromPreventive,
                onChanged: vm.setAreaId,
                decoration: InputDecoration(
                  labelText: 'Área de Trabajo / Ubicación',
                  hintText: 'Ej: A001 o PROCESO GENERAL',
                  prefixIcon: const Icon(Icons.business_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),

              // Naturaleza del Mantenimiento
              Text(
                'Naturaleza del Mantenimiento:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: (isFromReport || isFromPreventive)
                          ? null
                          : () => vm.setMaintenanceNature(isPreventive: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: vm.isCorrective
                              ? Colors.orange.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: vm.isCorrective
                                ? Colors.orange.shade700
                                : Colors.grey.shade300,
                            width: vm.isCorrective ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.build_circle_outlined,
                              size: 18,
                              color: vm.isCorrective
                                  ? Colors.orange.shade800
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Correctivo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: vm.isCorrective ? FontWeight.bold : FontWeight.w500,
                                color: vm.isCorrective
                                    ? Colors.orange.shade900
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: (isFromReport || isFromPreventive)
                          ? null
                          : () => vm.setMaintenanceNature(isPreventive: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: vm.isPreventive
                              ? const Color(0xFF0055A5).withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: vm.isPreventive
                                ? const Color(0xFF0055A5)
                                : Colors.grey.shade300,
                            width: vm.isPreventive ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_note_outlined,
                              size: 18,
                              color: vm.isPreventive
                                  ? const Color(0xFF0055A5)
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Preventivo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: vm.isPreventive ? FontWeight.bold : FontWeight.w500,
                                color: vm.isPreventive
                                    ? const Color(0xFF0055A5)
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Especialidad / Tipo de trabajo solicitado:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kWorkTypeLabels.entries
                    .where((entry) => !const {'urgency', 'corrective', 'preventive', 'scheduled'}.contains(entry.key))
                    .map((entry) {
                  final isSelected = vm.requestedWorkTypes.contains(entry.key);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : Colors.grey.shade800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (_) => vm.toggleWorkType(entry.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              TextField(
                key: const Key('ot-description'),
                maxLines: 4,
                minLines: 3,
                controller: _descriptionCtrl,
                onChanged: vm.setDescription,
                decoration: InputDecoration(
                  labelText: 'Descripción del trabajo / Falla a intervenir *',
                  hintText: 'Especifica con claridad los síntomas o las actividades a realizar...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bloque 2: Personal y Planificación de Mantenimiento
        _FormCard(
          title: '2. Asignación y Planificación de Mantenimiento',
          icon: Icons.engineering_outlined,
          theme: theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _assignedStaffCountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => vm.setAssignedStaffCount(int.tryParse(val)),
                      decoration: InputDecoration(
                        labelText: 'Personal asignado (cant.)',
                        hintText: 'Ej: 2',
                        prefixIcon: const Icon(Icons.people_outline, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _estimatedHoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => vm.setEstimatedHours(double.tryParse(val)),
                      decoration: InputDecoration(
                        labelText: 'Horas estimadas (hrs)',
                        hintText: 'Ej: 1.5',
                        prefixIcon: const Icon(Icons.access_time, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ot-assigned-to'),
                controller: _assignedToCtrl,
                onChanged: vm.setAssignedTo,
                decoration: InputDecoration(
                  labelText: 'Responsable / Técnico asignado',
                  hintText: 'Nombre del técnico o cuadrilla responsable',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bloque 3: Materiales, Refacciones y Herramientas
        _FormCard(
          title: '3. Materiales, Refacciones y Herramientas',
          icon: Icons.inventory_2_outlined,
          theme: theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _matDescCtrl,
                      decoration: InputDecoration(
                        labelText: 'Descripción del material / refacción',
                        hintText: 'Ej: Rodamiento 6204, Aceite ISO 68...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _matQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cant.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                      onPressed: _addMaterial,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (vm.materials.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    'No se han agregado materiales o refacciones a esta orden.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey.shade600),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: vm.materials.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final mat = entry.value;
                      return Container(
                        decoration: BoxDecoration(
                          border: idx > 0 ? Border(top: BorderSide(color: Colors.grey.shade200)) : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                mat.description,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${mat.quantity} ${mat.unit}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                              tooltip: 'Quitar',
                              onPressed: () => vm.removeMaterial(idx),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bloque 4: Prioridad de Atención
        _FormCard(
          title: '4. Prioridad de Atención',
          icon: Icons.flag_outlined,
          theme: theme,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;
              final cards = [
                _PriorityOptionCard(
                  priority: WorkOrderPriority.low,
                  label: 'Baja',
                  color: const Color(0xFF16A34A),
                  isSelected: vm.priority == WorkOrderPriority.low,
                  onTap: () => vm.setPriority(WorkOrderPriority.low),
                ),
                _PriorityOptionCard(
                  priority: WorkOrderPriority.medium,
                  label: 'Media',
                  color: const Color(0xFFD97706),
                  isSelected: vm.priority == WorkOrderPriority.medium,
                  onTap: () => vm.setPriority(WorkOrderPriority.medium),
                ),
                _PriorityOptionCard(
                  priority: WorkOrderPriority.high,
                  label: 'Alta / Urgente',
                  color: const Color(0xFFDC2626),
                  isSelected: vm.priority == WorkOrderPriority.high,
                  onTap: () => vm.setPriority(WorkOrderPriority.high),
                ),
              ];

              if (isCompact) {
                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      cards[i],
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // Botón Final de Guardar
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            key: const Key('ot-submit'),
            onPressed: vm.isSubmitting ? null : widget.onSubmit,
            icon: vm.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              vm.isSubmitting
                  ? 'Generando Orden de Trabajo...'
                  : 'Emitir Orden de Trabajo (REG.GMC-MTN-001)',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.icon,
    required this.theme,
    required this.child,
  });

  final String title;
  final IconData icon;
  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _PriorityOptionCard extends StatelessWidget {
  const _PriorityOptionCard({
    required this.priority,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final WorkOrderPriority priority;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.8 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? color : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12.5,
                  color: isSelected ? color : Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
