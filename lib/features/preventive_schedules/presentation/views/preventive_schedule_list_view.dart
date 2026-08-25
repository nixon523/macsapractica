import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/repositories/area_repository.dart';
import '../../../assets/domain/repositories/asset_repository.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../work_orders/presentation/views/work_order_create_view.dart';
import '../../domain/entities/preventive_schedule.dart';
import '../states/preventive_schedule_state.dart';
import '../viewmodels/preventive_schedule_viewmodel.dart';

enum _PreventiveFilterTab {
  all('Todos'),
  urgent('Urgentes (<48h)'),
  upcoming('Próximos (3-7d)'),
  onSchedule('Al día'),
  overdue('Vencidos'),
  paused('Pausados');

  const _PreventiveFilterTab(this.label);
  final String label;
}

class PreventiveScheduleListView extends StatefulWidget {
  const PreventiveScheduleListView({super.key});

  @override
  State<PreventiveScheduleListView> createState() =>
      _PreventiveScheduleListViewState();
}

class _PreventiveScheduleListViewState
    extends State<PreventiveScheduleListView> {
  _PreventiveFilterTab _tab = _PreventiveFilterTab.all;
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
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<PreventiveScheduleViewModel>().loadSchedules(
          startDate: _startDate,
          endDate: _endDate,
        );
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

  Future<void> _openCreateDialog() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<PreventiveScheduleViewModel>(),
        child: const _CreatePreventivePlanDialog(),
      ),
    );

    if (created == true && mounted) {
      final vm = context.read<PreventiveScheduleViewModel>();
      if (vm.successMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.successMessage)),
        );
      }
    }
  }

  Future<void> _openAmendDialog(PreventiveSchedule schedule) async {
    final amended = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<PreventiveScheduleViewModel>(),
        child: _AmendPreventivePlanDialog(schedule: schedule),
      ),
    );

    if (amended == true && mounted) {
      final vm = context.read<PreventiveScheduleViewModel>();
      if (vm.successMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.successMessage)),
        );
      }
    }
  }

  Future<void> _generateWorkOrder(PreventiveSchedule schedule) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderCreateView(preventiveSchedule: schedule),
      ),
    );

    if (created == true && mounted) {
      _loadData();
    }
  }

  Future<void> _toggleStatus(PreventiveSchedule schedule) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final newStatus = schedule.status == ScheduleStatus.active
        ? ScheduleStatus.paused
        : ScheduleStatus.active;

    final authorized = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<PreventiveScheduleViewModel>(),
        child: _AuthorizeStatusChangeDialog(
          schedule: schedule,
          newStatus: newStatus,
        ),
      ),
    );

    if (authorized == true && mounted) {
      final vm = context.read<PreventiveScheduleViewModel>();
      if (vm.successMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.successMessage)),
        );
      }
    }
  }

  List<PreventiveSchedule> _filterSchedules(List<PreventiveSchedule> list) {
    return list.where((s) {
      switch (_tab) {
        case _PreventiveFilterTab.all:
          if (s.status == ScheduleStatus.paused) return false;
          break;
        case _PreventiveFilterTab.urgent:
          if (s.status != ScheduleStatus.active || s.alertLevel != PreventiveAlertLevel.urgent) {
            return false;
          }
          break;
        case _PreventiveFilterTab.upcoming:
          if (s.status != ScheduleStatus.active || s.alertLevel != PreventiveAlertLevel.upcoming) {
            return false;
          }
          break;
        case _PreventiveFilterTab.onSchedule:
          if (s.status != ScheduleStatus.active || s.alertLevel != PreventiveAlertLevel.onSchedule) {
            return false;
          }
          break;
        case _PreventiveFilterTab.overdue:
          if (s.status != ScheduleStatus.active || s.alertLevel != PreventiveAlertLevel.overdue) {
            return false;
          }
          break;
        case _PreventiveFilterTab.paused:
          if (s.status != ScheduleStatus.paused) return false;
          break;
      }

      if (_searchQuery.isNotEmpty) {
        final matches = s.id.toLowerCase().contains(_searchQuery) ||
            s.title.toLowerCase().contains(_searchQuery) ||
            s.assetName.toLowerCase().contains(_searchQuery) ||
            s.assetId.toLowerCase().contains(_searchQuery) ||
            s.areaName.toLowerCase().contains(_searchQuery) ||
            s.areaId.toLowerCase().contains(_searchQuery) ||
            s.description.toLowerCase().contains(_searchQuery) ||
            s.maintenanceType.toLowerCase().contains(_searchQuery);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreventiveScheduleViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final canManage = authVm.hasPermission('preventive.manage');
    final isAdmin = authVm.currentUser?.role.code == 'admin';

    final dateLabel = _startDate == null
        ? 'Filtrar fecha'
        : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';

    final allSchedules = vm.state.schedules;
    final urgentCount = allSchedules
        .where((s) => s.status == ScheduleStatus.active && s.alertLevel == PreventiveAlertLevel.urgent)
        .length;
    final overdueCount = allSchedules
        .where((s) => s.status == ScheduleStatus.active && s.alertLevel == PreventiveAlertLevel.overdue)
        .length;

    final filteredList = _filterSchedules(allSchedules);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;

                final segmented = SegmentedButton<_PreventiveFilterTab>(
                  segments: [
                    const ButtonSegment(
                      value: _PreventiveFilterTab.all,
                      label: Text('Todos'),
                    ),
                    ButtonSegment(
                      value: _PreventiveFilterTab.urgent,
                      label: Text(
                        'Urgentes ($urgentCount)',
                        style: TextStyle(
                          color: urgentCount > 0 ? Colors.orange.shade800 : null,
                          fontWeight: urgentCount > 0 ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    const ButtonSegment(
                      value: _PreventiveFilterTab.upcoming,
                      label: Text('Próximos'),
                    ),
                    const ButtonSegment(
                      value: _PreventiveFilterTab.onSchedule,
                      label: Text('Al día'),
                    ),
                    ButtonSegment(
                      value: _PreventiveFilterTab.overdue,
                      label: Text(
                        'Vencidos ($overdueCount)',
                        style: TextStyle(
                          color: overdueCount > 0 ? Colors.red : null,
                          fontWeight: overdueCount > 0 ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    const ButtonSegment(
                      value: _PreventiveFilterTab.paused,
                      label: Text('Pausados'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (set) => setState(() => _tab = set.first),
                );

                final searchField = TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por equipo, plan, tipo o tarea...',
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

                final createBtn = canManage
                    ? FilledButton.icon(
                        onPressed: _openCreateDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nuevo Plan PM'),
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: segmented,
                    ),
                    const SizedBox(width: 10),
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

          Expanded(
            child: switch (vm.state.viewState) {
              ViewState.loading =>
                const Center(child: CircularProgressIndicator()),
              ViewState.error =>
                Center(child: Text('Error: ${vm.state.errorMessage}')),
              ViewState.initial || ViewState.success => filteredList.isEmpty
                  ? Center(
                      child: Text(
                        'No hay planes preventivos para el filtro seleccionado.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadData(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final schedule = filteredList[index];
                          return _PreventiveCard(
                            schedule: schedule,
                            canGenerateOt: canManage,
                            isAdmin: isAdmin,
                            onGenerateOt: () => _generateWorkOrder(schedule),
                            onAmend: () => _openAmendDialog(schedule),
                            onToggleStatus: () => _toggleStatus(schedule),
                          );
                        },
                      ),
                    ),
            },
          ),
        ],
      ),
    );
  }
}

class _PreventiveCard extends StatelessWidget {
  const _PreventiveCard({
    required this.schedule,
    required this.canGenerateOt,
    required this.isAdmin,
    required this.onGenerateOt,
    required this.onAmend,
    required this.onToggleStatus,
  });

  final PreventiveSchedule schedule;
  final bool canGenerateOt;
  final bool isAdmin;
  final VoidCallback onGenerateOt;
  final VoidCallback onAmend;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final (alertBg, alertTextColor, alertLabel) = switch (schedule.alertLevel) {
      PreventiveAlertLevel.overdue => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
          'Vencido hace ${schedule.daysRemaining.abs()} día(s)',
        ),
      PreventiveAlertLevel.urgent => (
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C),
          'Urgente: Vence en ${schedule.daysRemaining} día(s)',
        ),
      PreventiveAlertLevel.upcoming => (
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
          'Próximo: Vence en ${schedule.daysRemaining} día(s)',
        ),
      PreventiveAlertLevel.onSchedule => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          'Al día: Vence en ${schedule.daysRemaining} día(s)',
        ),
    };

    final isPaused = schedule.status == ScheduleStatus.paused;
    final nextDateStr = '${schedule.nextDate.day}/${schedule.nextDate.month}/${schedule.nextDate.year}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isPaused
              ? Colors.grey.shade300
              : schedule.alertLevel == PreventiveAlertLevel.overdue
                  ? Colors.red.shade300
                  : schedule.alertLevel == PreventiveAlertLevel.urgent
                      ? Colors.orange.shade300
                      : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        schedule.id,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '— ${schedule.assetId} (${schedule.assetName.isNotEmpty ? schedule.assetName : "Equipo"})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '· Área: ${schedule.areaName.isNotEmpty ? schedule.areaName : schedule.areaId}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        schedule.frequency.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    if (isPaused)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Pausado',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: alertBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alertLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: alertTextColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              schedule.title.isNotEmpty ? schedule.title : schedule.maintenanceType,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),

            if (schedule.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                schedule.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],

            if (schedule.materials.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: schedule.materials.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${m.quantity} ${m.unit} - ${m.name}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (schedule.amendmentDocNumber != null && schedule.amendmentDocNumber!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Modificado con Autorización Gerencial: Doc. ${schedule.amendmentDocNumber} '
                        '(${schedule.amendedBy ?? ""})',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  'Próxima fecha: $nextDateStr'
                  '${schedule.estimatedHours != null ? " · Est: ${schedule.estimatedHours}h" : ""}'
                  '${schedule.lastWorkOrderId != null ? " · Última OT: ${schedule.lastWorkOrderId}" : ""}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canGenerateOt && !isPaused)
                      if (schedule.canGenerateWorkOrder)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: onGenerateOt,
                          icon: const Icon(Icons.assignment_add, size: 16),
                          label: const Text('Generar OT', style: TextStyle(fontSize: 12)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_clock, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Habilita en ${schedule.daysRemaining - 7}d ($nextDateStr)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        tooltip: 'Opciones de Administrador',
                        onSelected: (value) {
                          if (value == 'amend') onAmend();
                          if (value == 'toggle') onToggleStatus();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'amend',
                            child: Row(
                              children: [
                                Icon(Icons.security_update_good, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Modificar con Autorización Gerencial',
                                    style: TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isPaused ? 'Reactivar Plan' : 'Pausar Plan',
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePreventivePlanDialog extends StatefulWidget {
  const _CreatePreventivePlanDialog();

  @override
  State<_CreatePreventivePlanDialog> createState() =>
      _CreatePreventivePlanDialogState();
}

class _CreatePreventivePlanDialogState
    extends State<_CreatePreventivePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: 'Inspección y Lubricación');
  final _descCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '2.0');

  List<Area> _areas = [];
  List<Asset> _assets = [];
  Area? _selectedArea;
  Asset? _selectedAsset;
  ScheduleFrequency _selectedFrequency = ScheduleFrequency.monthly;
  DateTime _startDate = DateTime.now().add(const Duration(days: 30));

  final List<PreventiveMaterial> _materials = [];
  final _matNameCtrl = TextEditingController();
  final _matQtyCtrl = TextEditingController(text: '1');
  final _matUnitCtrl = TextEditingController(text: 'pza');

  bool _loadingDependencies = true;

  @override
  void initState() {
    super.initState();
    _loadAreasAndAssets();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _typeCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _matNameCtrl.dispose();
    _matQtyCtrl.dispose();
    _matUnitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAreasAndAssets() async {
    try {
      final areaRepo = getIt<AreaRepository>();
      final areas = await areaRepo.getAreas();
      if (mounted) {
        setState(() {
          _areas = areas;
          if (areas.isNotEmpty) {
            _selectedArea = areas.first;
            _loadAssetsForArea(areas.first.id);
          } else {
            _loadingDependencies = false;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDependencies = false);
    }
  }

  Future<void> _loadAssetsForArea(String areaId) async {
    try {
      final assetRepo = getIt<AssetRepository>();
      final assets = (await assetRepo.getAssetsByArea(areaId))
          .where((a) => a.status == AssetStatus.active)
          .toList();
      if (mounted) {
        setState(() {
          _assets = assets;
          _selectedAsset = assets.isNotEmpty ? assets.first : null;
          _loadingDependencies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDependencies = false);
    }
  }

  void _addMaterial() {
    final name = _matNameCtrl.text.trim();
    final qty = double.tryParse(_matQtyCtrl.text.trim()) ?? 1.0;
    final unit = _matUnitCtrl.text.trim().isEmpty ? 'pza' : _matUnitCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _materials.add(PreventiveMaterial(name: name, quantity: qty, unit: unit));
      _matNameCtrl.clear();
      _matQtyCtrl.text = '1';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null || _selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el área y el equipo para el plan.')),
      );
      return;
    }

    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final schedule = PreventiveSchedule(
      id: '',
      title: _titleCtrl.text.trim(),
      assetId: _selectedAsset!.id,
      assetName: _selectedAsset!.name,
      areaId: _selectedArea!.id,
      areaName: _selectedArea!.name,
      maintenanceType: _typeCtrl.text.trim(),
      frequency: _selectedFrequency,
      description: _descCtrl.text.trim(),
      materials: _materials,
      estimatedHours: double.tryParse(_hoursCtrl.text.trim()),
      startDate: DateTime.now(),
      nextDate: _startDate,
      status: ScheduleStatus.active,
    );

    final vm = context.read<PreventiveScheduleViewModel>();
    final success = await vm.createSchedule(
      schedule: schedule,
      userId: user.userId,
      userName: user.username,
    );

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreventiveScheduleViewModel>();

    return AlertDialog(
      title: const Text('Definir Nuevo Plan Preventivo'),
      content: SizedBox(
        width: 580,
        child: _loadingDependencies
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;

                    final areaField = DropdownButtonFormField<Area>(
                      value: _selectedArea,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Área *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _areas.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text(
                            '${a.id} - ${a.name}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (area) {
                        if (area != null) {
                          setState(() {
                            _selectedArea = area;
                            _loadAssetsForArea(area.id);
                          });
                        }
                      },
                    );

                    final assetField = DropdownButtonFormField<Asset>(
                      value: _selectedAsset,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Equipo / Activo a intervenir *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _assets.map((ast) {
                        return DropdownMenuItem(
                          value: ast,
                          child: Text(
                            '${ast.id} - ${ast.name}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (ast) => setState(() => _selectedAsset = ast),
                    );

                    final freqField = DropdownButtonFormField<ScheduleFrequency>(
                      value: _selectedFrequency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Frecuencia *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ScheduleFrequency.values.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(
                            f.label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (f) {
                        if (f != null) {
                          setState(() {
                            _selectedFrequency = f;
                            _startDate = f.calculateNextDate(DateTime.now());
                          });
                        }
                      },
                    );

                    final typeField = TextFormField(
                      controller: _typeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tipo Intervención *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    );

                    final dateField = OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        '1ª Fecha: ${_startDate.day}/${_startDate.month}/${_startDate.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );

                    final hoursField = TextFormField(
                      controller: _hoursCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Horas Est.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    );

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Título del Plan *',
                              hintText: 'Ej: Mantenimiento Mensual de Compresor A1',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa el título del plan'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          if (isNarrow) ...[
                            areaField,
                            const SizedBox(height: 10),
                            freqField,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(flex: 3, child: areaField),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: freqField),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          assetField,
                          const SizedBox(height: 12),
                          if (isNarrow) ...[
                            typeField,
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: dateField),
                            const SizedBox(height: 10),
                            hoursField,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(flex: 3, child: typeField),
                                const SizedBox(width: 8),
                                Expanded(flex: 3, child: dateField),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: hoursField),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Procedimiento / Actividades a Realizar *',
                              hintText: 'Paso 1: Bloqueo de energía.\nPaso 2: Inspección y lubricación...',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Describe las actividades del mantenimiento'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Materiales y Repuestos Necesarios:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _matNameCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Nombre de insumo/repuesto',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _matQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Cant.',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _matUnitCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Unidad',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _addMaterial,
                                icon: const Icon(Icons.add_circle, color: Colors.blue),
                                tooltip: 'Agregar insumo',
                              ),
                            ],
                          ),
                          if (_materials.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _materials.map((m) {
                                return Chip(
                                  label: Text('${m.quantity} ${m.unit} - ${m.name}', style: const TextStyle(fontSize: 11)),
                                  onDeleted: () => setState(() => _materials.remove(m)),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: vm.isSaving ? null : _submit,
          child: const Text('Guardar Plan'),
        ),
      ],
    );
  }
}

class _AmendPreventivePlanDialog extends StatefulWidget {
  const _AmendPreventivePlanDialog({required this.schedule});

  final PreventiveSchedule schedule;

  @override
  State<_AmendPreventivePlanDialog> createState() =>
      _AmendPreventivePlanDialogState();
}

class _AmendPreventivePlanDialogState
    extends State<_AmendPreventivePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _docNumberCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _hoursCtrl;
  late ScheduleFrequency _selectedFrequency;
  late DateTime _nextDate;
  late List<PreventiveMaterial> _materials;

  final _matNameCtrl = TextEditingController();
  final _matQtyCtrl = TextEditingController(text: '1');
  final _matUnitCtrl = TextEditingController(text: 'pza');

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.schedule.title);
    _descCtrl = TextEditingController(text: widget.schedule.description);
    _hoursCtrl = TextEditingController(
      text: widget.schedule.estimatedHours?.toString() ?? '2.0',
    );
    _selectedFrequency = widget.schedule.frequency;
    _nextDate = widget.schedule.nextDate;
    _materials = List.from(widget.schedule.materials);
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _managerCtrl.dispose();
    _reasonCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _matNameCtrl.dispose();
    _matQtyCtrl.dispose();
    _matUnitCtrl.dispose();
    super.dispose();
  }

  void _addMaterial() {
    final name = _matNameCtrl.text.trim();
    final qty = double.tryParse(_matQtyCtrl.text.trim()) ?? 1.0;
    final unit = _matUnitCtrl.text.trim().isEmpty ? 'pza' : _matUnitCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _materials.add(PreventiveMaterial(name: name, quantity: qty, unit: unit));
      _matNameCtrl.clear();
      _matQtyCtrl.text = '1';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final updated = PreventiveSchedule(
      id: widget.schedule.id,
      title: _titleCtrl.text.trim(),
      assetId: widget.schedule.assetId,
      assetName: widget.schedule.assetName,
      areaId: widget.schedule.areaId,
      areaName: widget.schedule.areaName,
      maintenanceType: widget.schedule.maintenanceType,
      frequency: _selectedFrequency,
      description: _descCtrl.text.trim(),
      materials: _materials,
      estimatedHours: double.tryParse(_hoursCtrl.text.trim()),
      startDate: widget.schedule.startDate,
      nextDate: _nextDate,
      lastCompleted: widget.schedule.lastCompleted,
      lastWorkOrderId: widget.schedule.lastWorkOrderId,
      status: widget.schedule.status,
    );

    final vm = context.read<PreventiveScheduleViewModel>();
    final success = await vm.amendSchedule(
      scheduleId: widget.schedule.id,
      amendmentDocNumber: _docNumberCtrl.text.trim(),
      authorizedByManager: _managerCtrl.text.trim(),
      amendmentReason: _reasonCtrl.text.trim(),
      updatedSchedule: updated,
      userId: user.userId,
      userName: user.username,
    );

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreventiveScheduleViewModel>();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Modificar Plan: ${widget.schedule.id}'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;

              final docField = TextFormField(
                controller: _docNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nº Oficio / Doc. Gerencial *',
                  hintText: 'Ej: OF-GER-2026-089',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nº Documento obligatorio'
                    : null,
              );

              final managerField = TextFormField(
                controller: _managerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Gerente que Autoriza *',
                  hintText: 'Ej: Ing. Carlos Ramos',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nombre de Gerente obligatorio'
                    : null,
              );

              final freqField = DropdownButtonFormField<ScheduleFrequency>(
                value: _selectedFrequency,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: ScheduleFrequency.values.map((f) {
                  return DropdownMenuItem(
                    value: f,
                    child: Text(
                      f.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (f) {
                  if (f != null) setState(() => _selectedFrequency = f);
                },
              );

              final dateBtn = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) {
                    setState(() => _nextDate = picked);
                  }
                },
                icon: const Icon(Icons.event, size: 16),
                label: Text(
                  'Próxima: ${_nextDate.day}/${_nextDate.month}/${_nextDate.year}',
                  style: const TextStyle(fontSize: 12),
                ),
              );

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Política de Integridad: Este plan preventivo solo puede ser alterado con autorización de Gerencia.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isNarrow) ...[
                      docField,
                      const SizedBox(height: 10),
                      managerField,
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: docField),
                          const SizedBox(width: 8),
                          Expanded(child: managerField),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Justificación Técnica del Cambio *',
                        hintText: 'Ej: Actualización por cambio de especificación de faja...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Motivo del cambio obligatorio'
                          : null,
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título del Plan *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Título obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (isNarrow) ...[
                      freqField,
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: dateBtn),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: freqField),
                          const SizedBox(width: 8),
                          Expanded(child: dateBtn),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Procedimiento / Tareas *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Procedimiento obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Materiales y Repuestos:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _matNameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Insumo',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _matQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Cant.',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _matUnitCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Unid.',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _addMaterial,
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                        ),
                      ],
                    ),
                    if (_materials.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: _materials.map((m) {
                          return Chip(
                            label: Text('${m.quantity} ${m.unit} - ${m.name}', style: const TextStyle(fontSize: 10)),
                            onDeleted: () => setState(() => _materials.remove(m)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: vm.isSaving ? null : _submit,
          child: const Text('Aplicar Modificación'),
        ),
      ],
    );
  }
}

class _AuthorizeStatusChangeDialog extends StatefulWidget {
  const _AuthorizeStatusChangeDialog({
    required this.schedule,
    required this.newStatus,
  });

  final PreventiveSchedule schedule;
  final ScheduleStatus newStatus;

  @override
  State<_AuthorizeStatusChangeDialog> createState() =>
      _AuthorizeStatusChangeDialogState();
}

class _AuthorizeStatusChangeDialogState
    extends State<_AuthorizeStatusChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _docNumberCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _managerCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final vm = context.read<PreventiveScheduleViewModel>();
    final success = await vm.toggleScheduleStatus(
      scheduleId: widget.schedule.id,
      status: widget.newStatus,
      amendmentDocNumber: _docNumberCtrl.text.trim(),
      authorizedByManager: _managerCtrl.text.trim(),
      reason: _reasonCtrl.text.trim(),
      userId: user.userId,
      userName: user.username,
    );

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreventiveScheduleViewModel>();
    final isPausing = widget.newStatus == ScheduleStatus.paused;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isPausing ? Icons.pause_circle_outline : Icons.play_circle_outline,
            color: isPausing ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${isPausing ? "Pausar / Suspender" : "Reactivar"} Plan: ${widget.schedule.id}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPausing ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPausing ? Colors.orange.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, size: 18, color: isPausing ? Colors.orange.shade800 : Colors.green.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isPausing
                              ? 'Suspender un plan preventivo detiene el programa de mantenimiento del activo. Requiere autorización gerencial documentada.'
                              : 'Reactivar el plan volverá a incluir al activo en el programa de mantenimiento preventivo activo.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPausing ? Colors.orange.shade900 : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _docNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nº Oficio / Doc. Gerencial *',
                    hintText: 'Ej: OF-GER-2026-115',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nº Documento obligatorio'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _managerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Gerente que Autoriza *',
                    hintText: 'Ej: Ing. Carlos Ramos',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nombre de Gerente obligatorio'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Justificación del ${isPausing ? "Paro / Suspensión" : "Reactivación"} *',
                    hintText: isPausing
                        ? 'Ej: Equipo en reacondicionamiento mayor según programa de planta...'
                        : 'Ej: Equipo operativo nuevamente...',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Justificación obligatoria'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: vm.isSaving ? null : _submit,
          child: Text(isPausing ? 'Confirmar Suspensión' : 'Confirmar Reactivación'),
        ),
      ],
    );
  }
}

