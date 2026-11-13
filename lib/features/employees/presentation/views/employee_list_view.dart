import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../app/widgets/app_dialog.dart';
import '../../../../app/widgets/app_feedback.dart';
import '../../../../app/widgets/outlined_card.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/usecases/get_areas_usecase.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_position.dart';
import '../viewmodels/employee_list_viewmodel.dart';

class EmployeeListView extends StatefulWidget {
  const EmployeeListView({super.key});

  @override
  State<EmployeeListView> createState() => _EmployeeListViewState();
}

class _EmployeeListViewState extends State<EmployeeListView> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Area> _areas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmployeeListViewModel>().loadEmployees();
      _loadAreas();
    });
  }

  Future<void> _loadAreas() async {
    try {
      final areas = await getIt<GetAreasUseCase>().call(const NoParams());
      if (mounted) setState(() => _areas = areas);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openEmployeeDialog([Employee? employee]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EmployeeFormDialog(
        employee: employee,
        areas: _areas,
      ),
    );
  }

  void _openManagePositionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _ManagePositionsDialog(),
    );
  }

  Future<void> _confirmToggleStatus(Employee employee) async {
    final willDeactivate = employee.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willDeactivate ? 'Dar de baja a empleado' : 'Reactivar empleado'),
        content: Text(
          willDeactivate
              ? '¿Estás seguro de que deseas dar de baja a "${employee.fullName}"?\n\n'
                'Ya no aparecerá disponible para ser asignado a nuevas Órdenes de Trabajo, pero se preservará su historial en el sistema.'
              : '¿Deseas reactivar a "${employee.fullName}" para permitir asignarlo nuevamente en órdenes de trabajo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: willDeactivate ? const Color(0xFFDC2626) : const Color(0xFF0055A5),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willDeactivate ? 'Dar de baja' : 'Reactivar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vm = context.read<EmployeeListViewModel>();
      final ok = await vm.toggleEmployeeStatus(employee.id, active: !employee.isActive);
      if (!mounted) return;
      if (ok) {
        AppFeedback.showSuccess(
          context,
          willDeactivate
              ? 'Empleado dado de baja exitosamente.'
              : 'Empleado reactivado en el sistema.',
        );
      } else {
        AppFeedback.showError(context, 'Error: ${vm.errorMessage}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vm = context.watch<EmployeeListViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final canManage = authVm.currentUser?.isAdmin == true ||
        authVm.currentUser?.role.code == 'jefe';

    final employees = vm.filteredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Empleados y Personal Técnico'),
        actions: [
          if (canManage)
            TextButton.icon(
              onPressed: _openManagePositionsDialog,
              icon: const Icon(Icons.work_history_outlined, size: 18),
              label: const Text('Puestos'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0055A5),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () => vm.loadEmployees(),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0055A5),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo Empleado'),
              onPressed: () => _openEmployeeDialog(),
            )
          : null,
      body: Column(
        children: [
          // Barra de Búsqueda y Filtros
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: vm.setSearchQuery,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, puesto o área...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    vm.setSearchQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      selected: vm.showOnlyActive,
                      label: const Text('Solo Activos'),
                      onSelected: (_) => vm.toggleShowOnlyActive(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Todos (${vm.employees.length})'),
                        selected: vm.selectedCategory == EmployeeFilterCategory.all,
                        onSelected: (_) => vm.setCategory(EmployeeFilterCategory.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Mantenimiento (${vm.employees.where((e) => e.isMaintenance).length})'),
                        selected: vm.selectedCategory == EmployeeFilterCategory.maintenance,
                        onSelected: (_) => vm.setCategory(EmployeeFilterCategory.maintenance),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Planta / Otros (${vm.employees.where((e) => !e.isMaintenance).length})'),
                        selected: vm.selectedCategory == EmployeeFilterCategory.other,
                        onSelected: (_) => vm.setCategory(EmployeeFilterCategory.other),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Listado
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : employees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron empleados coincidentes.',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                            if (canManage) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
                                onPressed: () => _openEmployeeDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Registrar Primer Empleado'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: employees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final emp = employees[index];
                          return _EmployeeCard(
                            employee: emp,
                            canManage: canManage,
                            onEdit: () => _openEmployeeDialog(emp),
                            onToggleStatus: () => _confirmToggleStatus(emp),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.canManage,
    required this.onEdit,
    required this.onToggleStatus,
  });

  final Employee employee;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initials = employee.fullName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return OutlinedCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: employee.isMaintenance
                ? const Color(0xFF0055A5).withValues(alpha: 0.15)
                : Colors.grey.shade200,
            child: Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: employee.isMaintenance ? const Color(0xFF0055A5) : Colors.grey.shade700,
              ),
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
                        employee.fullName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          decoration: !employee.isActive ? TextDecoration.lineThrough : null,
                          color: !employee.isActive ? Colors.grey : null,
                        ),
                      ),
                    ),
                    if (!employee.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'INACTIVO / BAJA',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  employee.position,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (employee.isMaintenance)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF0055A5).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.engineering, size: 12, color: Color(0xFF0055A5)),
                            SizedBox(width: 4),
                            Text(
                              'Técnico Mantenimiento',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0055A5)),
                            ),
                          ],
                        ),
                      ),
                    if (employee.areaName != null && employee.areaName!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                employee.areaName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
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
          if (canManage) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'toggle') onToggleStatus();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Editar Datos'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        employee.isActive ? Icons.person_off_outlined : Icons.person_outline,
                        size: 18,
                        color: employee.isActive ? const Color(0xFFDC2626) : const Color(0xFF0055A5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        employee.isActive ? 'Dar de baja' : 'Reactivar',
                        style: TextStyle(
                          color: employee.isActive ? const Color(0xFFDC2626) : const Color(0xFF0055A5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeFormDialog extends StatefulWidget {
  const _EmployeeFormDialog({
    this.employee,
    required this.areas,
  });

  final Employee? employee;
  final List<Area> areas;

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _positionCtrl;
  String? _selectedAreaId;
  late bool _isMaintenance;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _nameCtrl = TextEditingController(text: emp?.fullName ?? '');
    _positionCtrl = TextEditingController(text: emp?.position ?? '');
    _selectedAreaId = emp?.areaId;
    _isMaintenance = emp?.isMaintenance ?? true;
    _isActive = emp?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<EmployeeListViewModel>();
    final isEditing = widget.employee != null;

    bool ok = false;
    if (isEditing) {
      ok = await vm.updateEmployee(
        id: widget.employee!.id,
        fullName: _nameCtrl.text.trim(),
        areaId: _selectedAreaId,
        position: _positionCtrl.text.trim(),
        isMaintenance: _isMaintenance,
        isActive: _isActive,
      );
    } else {
      ok = await vm.createEmployee(
        fullName: _nameCtrl.text.trim(),
        areaId: _selectedAreaId,
        position: _positionCtrl.text.trim(),
        isMaintenance: _isMaintenance,
      );
    }

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      AppFeedback.showSuccess(
        context,
        isEditing
            ? 'Empleado actualizado con éxito.'
            : 'Empleado registrado exitosamente.',
      );
    } else {
      AppFeedback.showError(
        context,
        vm.errorMessage.isNotEmpty
            ? vm.errorMessage
            : 'Ocurrió un error al guardar el empleado.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employee != null;
    final vm = context.watch<EmployeeListViewModel>();

    return AppDialog(
      maxWidth: 480,
      icon: const Icon(Icons.badge, color: Color(0xFF0055A5)),
      title: Text(isEditing ? 'Editar Empleado' : 'Registrar Nuevo Empleado'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo *',
                hintText: 'Ej: Carlos Hernández',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _positionCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Puesto o Cargo *',
                hintText: 'Ej: Técnico Mecánico Industrial',
                prefixIcon: const Icon(Icons.work_outline),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF0055A5)),
                      tooltip: 'Agregar, editar o eliminar puestos',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const _ManagePositionsDialog(),
                        );
                      },
                    ),
                    PopupMenuButton<EmployeePosition>(
                      icon: const Icon(Icons.arrow_drop_down),
                      tooltip: 'Seleccionar puesto del catálogo',
                      onSelected: (pos) {
                        setState(() {
                          _positionCtrl.text = pos.name;
                          _isMaintenance = pos.isMaintenance;
                        });
                      },
                      itemBuilder: (ctx) {
                        final list = vm.positions.isNotEmpty
                            ? vm.positions
                            : EmployeeListViewModel.defaultPositionsFallback;
                        return [
                          ...list.map(
                            (p) => PopupMenuItem<EmployeePosition>(
                              value: p,
                              child: Row(
                                children: [
                                  Icon(
                                    p.isMaintenance
                                        ? Icons.engineering_outlined
                                        : Icons.badge_outlined,
                                    size: 16,
                                    color: p.isMaintenance
                                        ? const Color(0xFF0055A5)
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<EmployeePosition>(
                            enabled: false,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                showDialog(
                                  context: context,
                                  builder: (dCtx) => const _ManagePositionsDialog(),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.settings_outlined,
                                        size: 16, color: Color(0xFF0055A5)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Administrar Puestos...',
                                      style: TextStyle(
                                        color: Color(0xFF0055A5),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El puesto es obligatorio.' : null,
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(
                    'Área de Asignación',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                _buildAreaSelectorCard(context),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Personal de Mantenimiento',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              subtitle: const Text(
                'Habilita al empleado para ser seleccionado como técnico responsable en Órdenes de Trabajo.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              value: _isMaintenance,
              activeThumbColor: const Color(0xFF0055A5),
              onChanged: (v) => setState(() => _isMaintenance = v),
            ),
            if (isEditing) ...[
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Estado Activo en el Sistema',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Si se desactiva, el empleado pasa a baja lógica.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                value: _isActive,
                activeThumbColor: const Color(0xFF0055A5),
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
          onPressed: vm.isSaving ? null : _save,
          child: vm.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Guardar Cambios' : 'Registrar Empleado'),
        ),
      ],
    );
  }

  Widget _buildAreaSelectorCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final selectedArea = _selectedAreaId == null
        ? null
        : widget.areas.where((a) => a.id == _selectedAreaId).firstOrNull;
    final hasArea = selectedArea != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasArea
              ? const Color(0xFF0055A5).withValues(alpha: 0.6)
              : borderColor,
          width: hasArea ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAreaSearchDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (!hasArea) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF64748B).withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'TALLER',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Taller Central / Sin área fija',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Personal de base o asignación itinerante',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
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
                      selectedArea.id,
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
                          selectedArea.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedArea.costCenter.isNotEmpty)
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
                  onPressed: () => _openAreaSearchDialog(context),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0055A5),
                    side: BorderSide(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.35),
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

  void _openAreaSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _EmployeeAreaSearchDialog(
        areas: widget.areas,
        selectedAreaId: _selectedAreaId,
        onAreaSelected: (areaId) {
          setState(() => _selectedAreaId = areaId);
        },
      ),
    );
  }
}

/// Diálogo buscador de Áreas con el mismo diseño estándar de Macsa CMMS.
class _EmployeeAreaSearchDialog extends StatefulWidget {
  const _EmployeeAreaSearchDialog({
    required this.areas,
    required this.selectedAreaId,
    required this.onAreaSelected,
  });

  final List<Area> areas;
  final String? selectedAreaId;
  final ValueChanged<String?> onAreaSelected;

  @override
  State<_EmployeeAreaSearchDialog> createState() =>
      _EmployeeAreaSearchDialogState();
}

class _EmployeeAreaSearchDialogState extends State<_EmployeeAreaSearchDialog> {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cleanQuery = _clean(_query);

    final showWorkshop = cleanQuery.isEmpty ||
        'taller central sin area fija'.contains(cleanQuery);

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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 580),
        child: Column(
          children: [
            // Cabecera
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
                          'Seleccionar Área de Asignación',
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

            // Buscador
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
                  fillColor:
                      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color:
                          isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF0055A5), width: 1.5),
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
                    'Áreas disponibles: ${filtered.length + (showWorkshop ? 1 : 0)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Lista filtrada
            Expanded(
              child: (filtered.isEmpty && !showWorkshop)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 38, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'No se encontraron áreas para "$_query"',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                      children: [
                        if (showWorkshop) ...[
                          _buildAreaTile(
                            context: context,
                            isDark: isDark,
                            code: 'TALLER',
                            title: 'Taller Central / Sin área fija',
                            subtitle: 'Personal de base o asignación itinerante',
                            isSelected: widget.selectedAreaId == null,
                            isWorkshop: true,
                            onTap: () {
                              widget.onAreaSelected(null);
                              Navigator.of(context).pop();
                            },
                          ),
                          const Divider(height: 12),
                        ],
                        ...filtered.map((area) {
                          return _buildAreaTile(
                            context: context,
                            isDark: isDark,
                            code: area.id,
                            title: area.name,
                            subtitle: area.costCenter.isNotEmpty
                                ? 'Centro de Costos: ${area.costCenter}'
                                : 'Área Operativa',
                            isSelected: widget.selectedAreaId == area.id,
                            onTap: () {
                              widget.onAreaSelected(area.id);
                              Navigator.of(context).pop();
                            },
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaTile({
    required BuildContext context,
    required bool isDark,
    required String code,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool isWorkshop = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected
            ? const Color(0xFF0055A5).withValues(alpha: 0.08)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF0055A5).withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isWorkshop
                  ? const Color(0xFF64748B).withValues(alpha: 0.12)
                  : const Color(0xFF0055A5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isWorkshop
                    ? (isDark ? Colors.grey.shade300 : const Color(0xFF475569))
                    : const Color(0xFF0055A5),
              ),
            ),
          ),
          title: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? const Color(0xFF0055A5) : null,
            ),
          ),
          subtitle: Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Color(0xFF0055A5), size: 20)
              : const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

/// Diálogo completo para Agregar, Editar y Eliminar Puestos / Cargos.
class _ManagePositionsDialog extends StatefulWidget {
  const _ManagePositionsDialog();

  @override
  State<_ManagePositionsDialog> createState() => _ManagePositionsDialogState();
}

class _ManagePositionsDialogState extends State<_ManagePositionsDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmployeeListViewModel>().loadPositions();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openEditPositionDialog([EmployeePosition? position]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PositionEditDialog(position: position),
    );
  }

  Future<void> _confirmDelete(EmployeePosition position) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Puesto'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el puesto "${position.name}" del catálogo?\n\n'
          'Los empleados que ya tienen este cargo lo conservarán en su ficha, pero dejará de aparecer como opción al registrar nuevos empleados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vm = context.read<EmployeeListViewModel>();
      final ok = await vm.deletePosition(position.id);
      if (!mounted) return;
      if (ok) {
        AppFeedback.showSuccess(context, 'Puesto eliminado del catálogo.');
      } else {
        AppFeedback.showError(
          context,
          vm.errorMessage.isNotEmpty
              ? vm.errorMessage
              : 'No se pudo eliminar el puesto.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vm = context.watch<EmployeeListViewModel>();

    final positions = vm.positions.where((p) {
      if (_query.isEmpty) return true;
      return p.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Column(
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.work_history_outlined,
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
                          'Catálogo de Puestos y Cargos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Agrega, edita o elimina los puestos disponibles para el personal',
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

            // Barra de búsqueda y botón Agregar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Buscar puesto o cargo...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 19),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0055A5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openEditPositionDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo Puesto'),
                  ),
                ],
              ),
            ),

            // Lista de Puestos
            Expanded(
              child: vm.isLoadingPositions && positions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : positions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.work_off_outlined,
                                  size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text(
                                'No se encontraron puestos registrados.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: positions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final pos = positions[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: pos.isMaintenance
                                    ? const Color(0xFF0055A5).withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.12),
                                child: Icon(
                                  pos.isMaintenance
                                      ? Icons.engineering_outlined
                                      : Icons.badge_outlined,
                                  size: 18,
                                  color: pos.isMaintenance
                                      ? const Color(0xFF0055A5)
                                      : Colors.grey.shade700,
                                ),
                              ),
                              title: Text(
                                pos.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: pos.isMaintenance
                                            ? const Color(0xFF0055A5)
                                                .withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pos.isMaintenance
                                            ? 'Personal de Mantenimiento'
                                            : 'General / Planta',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: pos.isMaintenance
                                              ? const Color(0xFF0055A5)
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19),
                                    tooltip: 'Editar puesto',
                                    color: const Color(0xFF0055A5),
                                    onPressed: () => _openEditPositionDialog(pos),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 19),
                                    tooltip: 'Eliminar puesto',
                                    color: const Color(0xFFDC2626),
                                    onPressed: () => _confirmDelete(pos),
                                  ),
                                ],
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

/// Diálogo para crear o editar un Puesto específico.
class _PositionEditDialog extends StatefulWidget {
  const _PositionEditDialog({this.position});

  final EmployeePosition? position;

  @override
  State<_PositionEditDialog> createState() => _PositionEditDialogState();
}

class _PositionEditDialogState extends State<_PositionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late bool _isMaintenance;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.position?.name ?? '');
    _isMaintenance = widget.position?.isMaintenance ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<EmployeeListViewModel>();
    final isEditing = widget.position != null;

    bool ok;
    if (isEditing) {
      ok = await vm.updatePosition(
        id: widget.position!.id,
        name: _nameCtrl.text.trim(),
        isMaintenance: _isMaintenance,
      );
    } else {
      ok = await vm.createPosition(
        name: _nameCtrl.text.trim(),
        isMaintenance: _isMaintenance,
      );
    }

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      AppFeedback.showSuccess(
        context,
        isEditing
            ? 'Puesto actualizado exitosamente.'
            : 'Puesto agregado al catálogo.',
      );
    } else {
      AppFeedback.showError(
        context,
        vm.errorMessage.isNotEmpty
            ? vm.errorMessage
            : 'No se pudo guardar el puesto.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.position != null;
    final vm = context.watch<EmployeeListViewModel>();

    return AppDialog(
      maxWidth: 420,
      icon: const Icon(Icons.work_outline, color: Color(0xFF0055A5)),
      title: Text(isEditing ? 'Editar Puesto / Cargo' : 'Nuevo Puesto / Cargo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del Puesto *',
                hintText: 'Ej: Técnico Electrónico Senior',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Personal de Mantenimiento',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              subtitle: const Text(
                'Marca si este cargo pertenece al equipo técnico asignable en Órdenes de Trabajo.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              value: _isMaintenance,
              activeThumbColor: const Color(0xFF0055A5),
              onChanged: (v) => setState(() => _isMaintenance = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
          onPressed: vm.isSaving ? null : _save,
          child: vm.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Guardar Cambios' : 'Agregar Puesto'),
        ),
      ],
    );
  }
}

