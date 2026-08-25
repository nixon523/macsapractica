import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../breakdown_reports/domain/entities/breakdown_report.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_create_viewmodel.dart';

class WorkOrderCreateView extends StatefulWidget {
  const WorkOrderCreateView({
    super.key,
    this.report,
    this.preventiveSchedule,
  });

  /// Reporte de avería que origina la OT (pre-rellena el formulario y, al
  /// guardar, la OT queda vinculada al reporte).
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
        SnackBar(content: Text('Orden de Trabajo ${created.displayCorrelative} creada con éxito.')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_viewModel.errorMessage}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WorkOrderCreateViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.report != null
                ? 'Generar OT desde Avería'
                : 'Nueva Orden de Trabajo (REG.GMC-MTN-001)',
          ),
        ),
        body: _WorkOrderCreateForm(
          viewModel: _viewModel,
          onSubmit: _submit,
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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isFromReport)
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: ListTile(
              leading: Icon(Icons.report_problem, color: theme.colorScheme.primary),
              title: const Text('Reporte de Avería vinculado'),
              subtitle: Text(
                'Activo: ${vm.report!.assetId} — ${vm.report!.assetName}\n'
                'Falla: ${vm.report!.description}',
              ),
            ),
          ),
        const SizedBox(height: 16),

        // --- Área para ser llenada por el SOLICITANTE ---
        _SectionHeader(
          title: 'Área para ser llenada por el SOLICITANTE',
          color: Colors.green.shade700,
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('ot-asset-id'),
                enabled: !isFromReport,
                controller: _assetIdCtrl,
                onChanged: vm.setAssetId,
                decoration: const InputDecoration(
                  labelText: 'ID del activo *',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('ot-asset-name'),
                enabled: !isFromReport,
                controller: _assetNameCtrl,
                onChanged: vm.setAssetName,
                decoration: const InputDecoration(
                  labelText: 'Nombre del activo',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _areaIdCtrl,
          onChanged: vm.setAreaId,
          decoration: const InputDecoration(
            labelText: 'Área de Trabajo / Ubicación',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Tipo de trabajo solicitado:',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: kWorkTypeLabels.entries
              .where((entry) => !const {'urgency', 'corrective', 'preventive', 'scheduled'}.contains(entry.key))
              .map((entry) {
            final isSelected = vm.requestedWorkTypes.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) => vm.toggleWorkType(entry.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        TextField(
          key: const Key('ot-description'),
          maxLines: 4,
          minLines: 3,
          controller: _descriptionCtrl,
          onChanged: vm.setDescription,
          decoration: const InputDecoration(
            labelText: 'Descripción detalle de la falla y/o trabajo requerido *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),

        // --- Área para ser llenada por personal de Mantenimiento ---
        _SectionHeader(
          title: 'Área para ser llenada por personal de Mantenimiento',
          color: Colors.green.shade800,
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _assignedStaffCountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (val) => vm.setAssignedStaffCount(int.tryParse(val)),
                decoration: const InputDecoration(
                  labelText: 'Personal asignado (cant.)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _estimatedHoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) => vm.setEstimatedHours(double.tryParse(val)),
                decoration: const InputDecoration(
                  labelText: 'Horas estimadas para la tarea',
                  border: OutlineInputBorder(),
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
          decoration: const InputDecoration(
            labelText: 'Responsable / Técnico asignado',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // --- Tabla de Materiales, Refacciones y Herramientas ---
        Text(
          'Material, Equipo, Herramienta y/o Refacciones a utilizar:',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _matDescCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción de la refacción/material',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _matQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cant.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add),
              tooltip: 'Agregar material',
              onPressed: _addMaterial,
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (vm.materials.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No se han agregado materiales o refacciones a esta OT.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vm.materials.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final mat = vm.materials[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 10)),
                  ),
                  title: Text(mat.description),
                  subtitle: Text('Cantidad: ${mat.quantity} ${mat.unit}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => vm.removeMaterial(index),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),

        Text('Prioridad de Atenciones', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<WorkOrderPriority>(
          segments: const [
            ButtonSegment(
              value: WorkOrderPriority.low,
              label: Text('Baja'),
            ),
            ButtonSegment(
              value: WorkOrderPriority.medium,
              label: Text('Media'),
            ),
            ButtonSegment(
              value: WorkOrderPriority.high,
              label: Text('Alta'),
            ),
          ],
          selected: {vm.priority},
          onSelectionChanged: (selection) => vm.setPriority(selection.first),
        ),
        const SizedBox(height: 24),

        if (vm.errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              vm.errorMessage,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),

        FilledButton.icon(
          key: const Key('ot-submit'),
          onPressed: vm.isSubmitting ? null : widget.onSubmit,
          icon: vm.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('Generar Orden de Trabajo (REG.GMC-MTN-001)'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
