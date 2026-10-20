import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/entities/asset.dart';
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
      _viewModel.loadOpenWorkOrders();
    } else if (widget.report != null) {
      _viewModel.initFromReport(widget.report);
      _viewModel.loadOpenWorkOrders();
    } else {
      _viewModel.loadAreas();
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

              // 1. Selector de Área Operativa
              const Text(
                'ÁREA OPERATIVA DE UBICACIÓN *',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),

              if (isFromReport || isFromPreventive)
                _buildReadOnlyAreaCard(
                  areaId: vm.areaId,
                  areaName: vm.areaName,
                  isDark: isDark,
                  borderColor: borderColor,
                )
              else
                _buildAreaSelectorCard(
                  context: context,
                  theme: theme,
                  vm: vm,
                  isDark: isDark,
                  borderColor: borderColor,
                  onTapSearch: () => _openAreaSearchModal(context, vm),
                ),

              const SizedBox(height: 18),

              // 2. Selector de Activo / Equipo Afectado
              const Text(
                'ACTIVO O EQUIPO AFECTADO *',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),

              if (isFromReport || isFromPreventive)
                _buildReadOnlyAssetCard(
                  assetId: vm.assetId,
                  assetName: vm.assetName,
                  isDark: isDark,
                  borderColor: borderColor,
                )
              else if (vm.areaId.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    'Selecciona primero un área operativa para desplegar los equipos correspondientes.',
                    style: TextStyle(fontSize: 12, color: secondaryText),
                  ),
                )
              else if (vm.isLoadingAssets)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Consultando catálogo de equipos del área ${vm.areaName.isNotEmpty ? vm.areaName : vm.areaId}...',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (vm.assets.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'No se encontraron equipos registrados en esta área.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                _buildAssetSelectorCard(
                  context: context,
                  theme: theme,
                  vm: vm,
                  isDark: isDark,
                  borderColor: borderColor,
                  onTapSearch: () => _openAssetSearchModal(context, vm),
                ),

              if (vm.isAssetPending(vm.assetId)) ...[
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final pendingWo = vm.getOpenWorkOrderForAsset(vm.assetId);
                  final statusLabel = pendingWo?.status == WorkOrderStatus.inProgress
                      ? 'En Progreso'
                      : 'Pendiente';
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Orden de trabajo activa en este activo (${pendingWo?.id ?? ""})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Este equipo ya cuenta con la orden de trabajo ${pendingWo?.id ?? ""} en estado "$statusLabel". '
                          'Por norma operativa de mantenimiento, no se permite crear una nueva orden de trabajo sobre el mismo equipo hasta que la actual sea completada o cancelada.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.3),
                        ),
                      ],
                    ),
                  );
                }),
              ],

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
                  onPressed: (vm.isSubmitting || vm.isAssetPending(vm.assetId)) ? null : widget.onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0055A5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    disabledForegroundColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
                      : (vm.isAssetPending(vm.assetId)
                          ? const Icon(Icons.block_rounded, size: 20)
                          : const Icon(Icons.assignment_turned_in_outlined, size: 20)),
                  label: Text(
                    vm.isSubmitting
                        ? 'Emitiendo Orden de Trabajo...'
                        : (vm.isAssetPending(vm.assetId)
                            ? 'Activo con OT Pendiente (${vm.getOpenWorkOrderForAsset(vm.assetId)?.id ?? ""})'
                            : 'Emitir Orden de Trabajo (REG.GMC-MTN-001)'),
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

  Widget _buildReadOnlyAreaCard({
    required String areaId,
    required String areaName,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
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
            child: Text(
              areaId.isNotEmpty ? areaId : 'N/A',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0055A5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              areaName.isNotEmpty ? areaName : areaId,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyAssetCard({
    required String assetId,
    required String assetName,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
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
            child: Text(
              assetId.isNotEmpty ? assetId : 'N/A',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0055A5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              assetName.isNotEmpty ? assetName : assetId,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaSelectorCard({
    required BuildContext context,
    required ThemeData theme,
    required WorkOrderCreateViewModel vm,
    required bool isDark,
    required Color borderColor,
    required VoidCallback onTapSearch,
  }) {
    final hasArea = vm.areaId.isNotEmpty;
    final selectedArea = vm.areas.where((a) => a.id == vm.areaId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasArea ? const Color(0xFF0055A5).withValues(alpha: 0.6) : borderColor,
          width: hasArea ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: vm.isLoadingAreas ? null : onTapSearch,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (!hasArea) ...[
                  Expanded(
                    child: Text(
                      vm.isLoadingAreas
                          ? 'Cargando catálogo de áreas...'
                          : 'Buscar o seleccionar área operativa...',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ] else ...[
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
                    child: Text(
                      vm.areaId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0055A5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vm.areaName.isNotEmpty ? vm.areaName : vm.areaId,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedArea != null && selectedArea.costCenter.isNotEmpty)
                          Text(
                            'Centro de Costos: ${selectedArea.costCenter}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: vm.isLoadingAreas ? null : onTapSearch,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0055A5),
                    side: BorderSide(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.3),
                      width: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Text(
                    hasArea ? 'Cambiar' : 'Buscar Área',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetSelectorCard({
    required BuildContext context,
    required ThemeData theme,
    required WorkOrderCreateViewModel vm,
    required bool isDark,
    required Color borderColor,
    required VoidCallback onTapSearch,
  }) {
    final hasAsset = vm.assetId.isNotEmpty;
    final selectedAsset = vm.assets.where((a) => a.id == vm.assetId).firstOrNull;
    final serial = selectedAsset?.serial;
    final hasSerial = serial != null && serial.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: vm.isAssetPending(vm.assetId)
              ? const Color(0xFFF59E0B)
              : (hasAsset ? const Color(0xFF0055A5).withValues(alpha: 0.6) : borderColor),
          width: hasAsset ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapSearch,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (!hasAsset) ...[
                  Expanded(
                    child: Text(
                      'Buscar o seleccionar equipo (${vm.assets.length} disponibles)...',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ] else ...[
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
                    child: Text(
                      vm.assetId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0055A5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vm.assetName.isNotEmpty ? vm.assetName : vm.assetId,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasSerial)
                          Text(
                            'Serie: $serial',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onTapSearch,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0055A5),
                    side: BorderSide(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.3),
                      width: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Text(
                    hasAsset ? 'Cambiar' : 'Buscar Equipo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAreaSearchModal(BuildContext context, WorkOrderCreateViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => _AreaSearchDialog(
        areas: vm.areas,
        selectedAreaId: vm.areaId,
        onAreaSelected: (area) => vm.selectArea(area.id, areaName: area.name),
      ),
    );
  }

  void _openAssetSearchModal(BuildContext context, WorkOrderCreateViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => _AssetSearchDialog(
        assets: vm.assets,
        selectedAssetId: vm.assetId,
        getOpenWorkOrder: vm.getOpenWorkOrderForAsset,
        onAssetSelected: vm.selectAsset,
      ),
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

/// Diálogo Modal Ejecutivo para Búsqueda en Tiempo Real de Áreas Operativas
class _AreaSearchDialog extends StatefulWidget {
  const _AreaSearchDialog({
    required this.areas,
    required this.selectedAreaId,
    required this.onAreaSelected,
  });

  final List<Area> areas;
  final String? selectedAreaId;
  final ValueChanged<Area> onAreaSelected;

  @override
  State<_AreaSearchDialog> createState() => _AreaSearchDialogState();
}

class _AreaSearchDialogState extends State<_AreaSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _clean(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanQuery = _clean(_query);

    final filtered = widget.areas.where((a) {
      if (cleanQuery.isEmpty) return true;
      final idClean = _clean(a.id);
      final nameClean = _clean(a.name);
      final ccClean = _clean(a.costCenter);
      return idClean.contains(cleanQuery) ||
          nameClean.contains(cleanQuery) ||
          ccClean.contains(cleanQuery);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      color: Color(0xFF0055A5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Área Operativa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Filtra por código (ej. A003) o por nombre de área',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Escribe el código o nombre del área...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0055A5), width: 1.5),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mostrando ${filtered.length} de ${widget.areas.length} áreas operativas',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'No se encontraron áreas coincidentes con "$_query"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                      itemBuilder: (context, idx) {
                        final area = filtered[idx];
                        final isSelected = area.id == widget.selectedAreaId;

                        return Material(
                          color: isSelected
                              ? const Color(0xFF0055A5).withValues(alpha: 0.07)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0055A5)
                                    : const Color(0xFF0055A5).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                area.id,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF0055A5),
                                ),
                              ),
                            ),
                            title: Text(
                              area.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: area.costCenter.isNotEmpty
                                ? Text(
                                    'CC: ${area.costCenter}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF0055A5), size: 18)
                                : const Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFFCBD5E1), size: 18),
                            onTap: () {
                              widget.onAreaSelected(area);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo Modal Ejecutivo para Búsqueda en Tiempo Real de Equipos / Activos
class _AssetSearchDialog extends StatefulWidget {
  const _AssetSearchDialog({
    required this.assets,
    required this.selectedAssetId,
    required this.onAssetSelected,
    this.getOpenWorkOrder,
  });

  final List<Asset> assets;
  final String? selectedAssetId;
  final ValueChanged<Asset> onAssetSelected;
  final WorkOrder? Function(String assetId)? getOpenWorkOrder;

  @override
  State<_AssetSearchDialog> createState() => _AssetSearchDialogState();
}

class _AssetSearchDialogState extends State<_AssetSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _clean(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanQuery = _clean(_query);

    final filtered = widget.assets.where((a) {
      if (cleanQuery.isEmpty) return true;
      final idClean = _clean(a.id);
      final nameClean = _clean(a.name);
      final serialClean = _clean(a.serial ?? '');
      return idClean.contains(cleanQuery) ||
          nameClean.contains(cleanQuery) ||
          serialClean.contains(cleanQuery);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_outlined,
                      color: Color(0xFF0055A5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Equipo Afectado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Filtra por código de activo, nombre de equipo o serie',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Escribe el código, nombre o serie...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0055A5), width: 1.5),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mostrando ${filtered.length} de ${widget.assets.length} equipos disponibles',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'No se encontraron equipos coincidentes con "$_query"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                      itemBuilder: (context, idx) {
                        final asset = filtered[idx];
                        final isSelected = asset.id == widget.selectedAssetId;
                        final hasSerial = asset.serial != null && asset.serial!.isNotEmpty;

                        return Material(
                          color: isSelected
                              ? const Color(0xFF0055A5).withValues(alpha: 0.07)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0055A5)
                                    : const Color(0xFF0055A5).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                asset.id,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF0055A5),
                                ),
                              ),
                            ),
                            title: Text(
                              asset.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: hasSerial
                                ? Text(
                                    'Serie: ${asset.serial!}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Builder(builder: (context) {
                                  final openWo = widget.getOpenWorkOrder?.call(asset.id);
                                  if (openWo == null) return const SizedBox.shrink();
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFF59E0B)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFB45309)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'OT: ${openWo.id}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF0055A5), size: 18)
                                else
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFFCBD5E1), size: 18),
                              ],
                            ),
                            onTap: () {
                              widget.onAssetSelected(asset);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
