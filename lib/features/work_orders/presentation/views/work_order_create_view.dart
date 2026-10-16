import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../breakdown_reports/domain/entities/breakdown_report.dart';
import '../../domain/entities/work_order.dart';
import '../viewmodels/work_order_create_viewmodel.dart';

/// Vista ejecutiva, uniforme y formal para emitir Órdenes de Trabajo (REG.GMC-MTN-001).
/// Alineada con el estándar corporativo de Grupo Macsa y optimizada para Android y Web.
class WorkOrderCreateView extends StatefulWidget {
  const WorkOrderCreateView({
    super.key,
    this.report,
    this.preventiveSchedule,
  });

  /// Reporte de avería que origina la OT (correctivo).
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFF0F766E),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Orden de Trabajo ${created.displayCorrelative} emitida y registrada en Kardex.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFFB91C1C),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _viewModel.errorMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = widget.report != null
        ? 'Generar OT desde Avería'
        : (widget.preventiveSchedule != null
            ? 'Generar OT desde Preventivo'
            : 'Nueva Orden de Trabajo');

    return ChangeNotifierProvider<WorkOrderCreateViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16.5,
              letterSpacing: -0.2,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              height: 1,
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
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
  final String _matUnit = 'pz';

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
      text: vm.estimatedHours != null ? vm.estimatedHours!.toInt().toString() : '',
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
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      children: [
        // ==========================================
        // BANNER OFICIAL DE ORDEN DE TRABAJO
        // ==========================================
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior de acento corporativo
              Container(
                height: 4,
                color: const Color(0xFF0055A5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0055A5).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: Color(0xFF0055A5),
                        size: 22,
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
                                  isFromReport
                                      ? 'Orden de Trabajo Correctiva'
                                      : (isFromPreventive
                                          ? 'Orden de Trabajo Preventiva'
                                          : 'Emisión de Orden de Trabajo'),
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF0055A5).withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'REG.GMC-MTN-001',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF0055A5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            isFromReport
                                ? 'Generando OT para solventar la Avería #${vm.report!.id}. El reporte quedará vinculado y se marcará como resuelto al completar esta orden.'
                                : (isFromPreventive
                                    ? 'Generando orden a partir del Plan Preventivo PM-${vm.preventiveSchedule.id}.'
                                    : 'Completa los requerimientos técnicos, asignación y materiales para la ejecución del mantenimiento.'),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ==========================================
        // TARJETA PRINCIPAL DEL FORMULARIO
        // ==========================================
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // SECCIÓN 1: DATOS DEL EQUIPO Y NATURALEZA
              // ==========================================
              _buildSectionHeader(
                stepNumber: '01',
                title: 'Equipo Afectado y Naturaleza del Trabajo',
                subtitle: 'Identificación del activo, especialidad técnica y motivo de la intervención.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Fila de Activo (ID y Nombre)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 500;
                  final assetIdField = TextField(
                    key: const Key('ot-asset-id'),
                    enabled: !isFromReport && !isFromPreventive,
                    controller: _assetIdCtrl,
                    onChanged: vm.setAssetId,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'ID DEL ACTIVO *',
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      hintText: 'Ej: A003-001',
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  );

                  final assetNameField = TextField(
                    key: const Key('ot-asset-name'),
                    enabled: !isFromReport && !isFromPreventive,
                    controller: _assetNameCtrl,
                    onChanged: vm.setAssetName,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'NOMBRE DEL EQUIPO',
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      hintText: 'Nombre de máquina o componente',
                      prefixIcon: const Icon(Icons.precision_manufacturing_outlined, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        assetIdField,
                        const SizedBox(height: 10),
                        assetNameField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 2, child: assetIdField),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: assetNameField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Campo de Área
              TextField(
                controller: _areaIdCtrl,
                enabled: !isFromReport && !isFromPreventive,
                onChanged: vm.setAreaId,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'ÁREA DE UBICACIÓN OPERATIVA',
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  hintText: 'Ej: A003 o CLASIFICADO',
                  prefixIcon: const Icon(Icons.business_outlined, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),

              // Selector de Naturaleza (Correctivo vs Preventivo)
              const Text(
                'NATURALEZA DEL MANTENIMIENTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF475569),
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                        decoration: BoxDecoration(
                          color: vm.isCorrective
                              ? const Color(0xFFD97706).withValues(alpha: isDark ? 0.18 : 0.08)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: vm.isCorrective ? const Color(0xFFD97706) : borderColor,
                            width: vm.isCorrective ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.build_circle_outlined,
                              size: 17,
                              color: vm.isCorrective ? const Color(0xFFD97706) : secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Correctivo (Atención a Fallas)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: vm.isCorrective ? FontWeight.w700 : FontWeight.w500,
                                color: vm.isCorrective
                                    ? (isDark ? Colors.white : const Color(0xFFB45309))
                                    : secondaryText,
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                        decoration: BoxDecoration(
                          color: vm.isPreventive
                              ? const Color(0xFF0055A5).withValues(alpha: isDark ? 0.2 : 0.08)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: vm.isPreventive ? const Color(0xFF0055A5) : borderColor,
                            width: vm.isPreventive ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_note_outlined,
                              size: 17,
                              color: vm.isPreventive ? const Color(0xFF0055A5) : secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Preventivo (Planificado)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: vm.isPreventive ? FontWeight.w700 : FontWeight.w500,
                                color: vm.isPreventive
                                    ? (isDark ? Colors.white : const Color(0xFF0055A5))
                                    : secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Especialidad / Tipo de trabajo solicitado
              const Text(
                'ESPECIALIDAD / TIPO DE TRABAJO SOLICITADO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF475569),
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
                    selectedColor: const Color(0xFF0055A5).withValues(alpha: 0.12),
                    checkmarkColor: const Color(0xFF0055A5),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0055A5) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF0055A5) : borderColor,
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    onSelected: (_) => vm.toggleWorkType(entry.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Descripción de la Falla / Actividad
              TextField(
                key: const Key('ot-description'),
                maxLines: 4,
                minLines: 3,
                controller: _descriptionCtrl,
                onChanged: vm.setDescription,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'DESCRIPCIÓN TÉCNICA DEL TRABAJO O FALLA *',
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  hintText: 'Especifica las tareas a realizar, ajustes o piezas a revisar...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(height: 28),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 24),

              // ==========================================
              // SECCIÓN 2: ASIGNACIÓN Y PLANIFICACIÓN
              // ==========================================
              _buildSectionHeader(
                stepNumber: '02',
                title: 'Asignación y Planificación de Mantenimiento',
                subtitle: 'Personal técnico asignado y estimación de tiempo de intervención.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 480;

                  // Campo Personal Asignado (Solo Números Enteros)
                  final staffCountField = TextField(
                    controller: _assignedStaffCountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (val) => vm.setAssignedStaffCount(int.tryParse(val)),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'PERSONAL ASIGNADO (CANTIDAD)',
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      hintText: 'Ej: 2',
                      prefixIcon: const Icon(Icons.people_outline, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  );

                  // Campo Horas Estimadas (Solo Números Enteros)
                  final hoursField = TextField(
                    controller: _estimatedHoursCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (val) {
                      final intVal = int.tryParse(val);
                      vm.setEstimatedHours(intVal?.toDouble());
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'HORAS ESTIMADAS (HRS ENTERAS)',
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      hintText: 'Ej: 2',
                      prefixIcon: const Icon(Icons.access_time, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        staffCountField,
                        const SizedBox(height: 12),
                        hoursField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: staffCountField),
                      const SizedBox(width: 12),
                      Expanded(child: hoursField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Técnico o cuadrilla asignada
              TextField(
                key: const Key('ot-assigned-to'),
                controller: _assignedToCtrl,
                onChanged: vm.setAssignedTo,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'RESPONSABLE / TÉCNICO ASIGNADO',
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  hintText: 'Nombre del técnico mecánico/eléctrico o cuadrilla',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              const SizedBox(height: 28),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 24),

              // ==========================================
              // SECCIÓN 3: MATERIALES Y REFACCIONES
              // ==========================================
              _buildSectionHeader(
                stepNumber: '03',
                title: 'Materiales, Refacciones y Herramientas',
                subtitle: 'Registro de repuestos e insumos requeridos para la orden.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 540;

                  final descField = TextField(
                    controller: _matDescCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Descripción del repuesto o insumo...',
                      hintStyle: TextStyle(fontSize: 12.5, color: secondaryText),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  );

                  final qtyField = SizedBox(
                    width: isCompact ? 100 : 90,
                    child: TextField(
                      controller: _matQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cant.',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      ),
                    ),
                  );

                  final addBtn = SizedBox(
                    height: 42,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0055A5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Agregar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onPressed: _addMaterial,
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        descField,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            qtyField,
                            const SizedBox(width: 8),
                            Expanded(child: addBtn),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: descField),
                      const SizedBox(width: 8),
                      qtyField,
                      const SizedBox(width: 8),
                      addBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              if (vm.materials.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    'No se han agregado materiales o refacciones a esta orden.',
                    style: TextStyle(fontSize: 12, color: secondaryText, fontStyle: FontStyle.italic),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: vm.materials.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final mat = entry.value;
                      return Container(
                        decoration: BoxDecoration(
                          border: idx > 0 ? Border(top: BorderSide(color: borderColor)) : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0055A5),
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
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${mat.quantity} ${mat.unit}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
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

              const SizedBox(height: 28),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 24),

              // ==========================================
              // SECCIÓN 4: PRIORIDAD DE ATENCIÓN
              // ==========================================
              _buildSectionHeader(
                stepNumber: '04',
                title: 'Prioridad de Atención y Urgencia',
                subtitle: 'Determina el orden de prelación en el plan de trabajo diario.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 460;
                  final cards = [
                    _PriorityOptionCard(
                      priority: WorkOrderPriority.low,
                      badgeText: 'Nivel 1',
                      label: 'Baja Prioridad',
                      color: const Color(0xFF059669),
                      isSelected: vm.priority == WorkOrderPriority.low,
                      onTap: () => vm.setPriority(WorkOrderPriority.low),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    _PriorityOptionCard(
                      priority: WorkOrderPriority.medium,
                      badgeText: 'Nivel 2',
                      label: 'Media / Atención',
                      color: const Color(0xFFD97706),
                      isSelected: vm.priority == WorkOrderPriority.medium,
                      onTap: () => vm.setPriority(WorkOrderPriority.medium),
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                    _PriorityOptionCard(
                      priority: WorkOrderPriority.high,
                      badgeText: 'Nivel 3',
                      label: 'Alta / Urgente',
                      color: const Color(0xFFDC2626),
                      isSelected: vm.priority == WorkOrderPriority.high,
                      onTap: () => vm.setPriority(WorkOrderPriority.high),
                      isDark: isDark,
                      borderColor: borderColor,
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

              const SizedBox(height: 32),

              // Botón Final de Emisión Oficial
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  key: const Key('ot-submit'),
                  onPressed: vm.isSubmitting ? null : widget.onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0055A5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: vm.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.assignment_turned_in_outlined, size: 20),
                  label: Text(
                    vm.isSubmitting
                        ? 'Emitiendo Orden de Trabajo...'
                        : 'Emitir Orden de Trabajo (REG.GMC-MTN-001)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String stepNumber,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0055A5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF0055A5).withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0055A5),
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de Prioridad Ejecutiva
class _PriorityOptionCard extends StatelessWidget {
  const _PriorityOptionCard({
    required this.priority,
    required this.badgeText,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.borderColor,
  });

  final WorkOrderPriority priority;
  final String badgeText;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.15 : 0.06)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 16,
                color: isSelected ? color : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                    color: isSelected ? (isDark ? Colors.white : color) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
