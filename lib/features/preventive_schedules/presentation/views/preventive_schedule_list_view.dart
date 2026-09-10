import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../app/widgets/app_dialog.dart';
import '../../../assets/domain/entities/area.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../assets/domain/repositories/area_repository.dart';
import '../../../assets/domain/repositories/asset_repository.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/preventive_schedule.dart';
import '../states/preventive_schedule_state.dart';
import '../viewmodels/preventive_schedule_viewmodel.dart';
import '../widgets/batch_generate_preventive_ots_dialog.dart';
import '../widgets/generate_preventive_ot_dialog.dart';

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

  String _selectedPreset = 'todo';

  @override
  void initState() {
    super.initState();
    _startDate = null;
    _endDate = null;

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

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'hoy':
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'proximos7dias':
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          final inSevenDays = now.add(const Duration(days: 7));
          _endDate = DateTime(inSevenDays.year, inSevenDays.month, inSevenDays.day, 23, 59, 59);
          break;
        case 'mes':
          _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          final nextMonth = DateTime(now.year, now.month + 1, 1);
          _endDate = nextMonth.subtract(const Duration(seconds: 1));
          break;
        case 'todo':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
    _loadData();
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

  Future<void> _openCreateDialog([PreventiveSchedule? templateSchedule]) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<PreventiveScheduleViewModel>(),
        child: _CreatePreventivePlanDialog(templateSchedule: templateSchedule),
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
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => GeneratePreventiveOtDialog(schedule: schedule),
    );

    if (result == true && mounted) {
      _loadData();
    }
  }

  Future<void> _openBatchGenerateDialog() async {
    final schedules = context.read<PreventiveScheduleViewModel>().schedules;
    final areas = await getIt<AreaRepository>().getAreas();
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => BatchGeneratePreventiveOtsDialog(
        schedules: schedules,
        areas: areas,
      ),
    );

    if (result == true && mounted) {
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
          _buildFilterSection(
            isNarrow: MediaQuery.of(context).size.width < 750,
            urgentCount: urgentCount,
            overdueCount: overdueCount,
            canManage: canManage,
          ),

          const Divider(height: 1),

          _buildSummaryBar(filteredList.length, urgentCount, overdueCount),

          Expanded(
            child: switch (vm.state.viewState) {
              ViewState.loading =>
                const Center(child: CircularProgressIndicator()),
              ViewState.error =>
                Center(child: Text('Error: ${vm.state.errorMessage}')),
              ViewState.initial || ViewState.success => filteredList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Sin resultados para "$_searchQuery"'
                                  : 'No hay planes preventivos para el filtro seleccionado.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Intenta con otro término o limpia la barra de búsqueda.'
                                  : 'Prueba cambiando el rango de fechas o el estado del plan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            if (_selectedPreset != 'todo') ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _applyPreset('todo'),
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('Ver todos los planes'),
                              ),
                            ],
                          ],
                        ),
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
                            onDuplicate: () => _openCreateDialog(schedule),
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

  Widget _buildFilterSection({
    required bool isNarrow,
    required int urgentCount,
    required int overdueCount,
    required bool canManage,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Selector de Fechas (Desde - Hasta) y Presets
          if (!isNarrow)
            Row(
              children: [
                _buildDateRangeButton(),
                const SizedBox(width: 12),
                Expanded(child: _buildPresetsRow()),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openBatchGenerateDialog,
                    icon: const Icon(Icons.playlist_add_check, size: 18),
                    label: const Text('Programar OTs del Mes'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo Plan PM'),
                  ),
                ],
              ],
            )
          else ...[
            _buildDateRangeButton(),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildPresetsRow(),
            ),
            if (canManage) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openBatchGenerateDialog,
                      icon: const Icon(Icons.playlist_add_check, size: 16),
                      label: const Text('Programar OTs', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openCreateDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nuevo Plan PM', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 10),

          // Fila 2: Búsqueda y Chips de categoría
          if (!isNarrow)
            Row(
              children: [
                Expanded(flex: 3, child: _buildSearchBar()),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _buildCategoryChips(
                    urgentCount: urgentCount,
                    overdueCount: overdueCount,
                    scrollable: false,
                  ),
                ),
              ],
            )
          else ...[
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildCategoryChips(
              urgentCount: urgentCount,
              overdueCount: overdueCount,
              scrollable: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRangeButton() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    String label;
    if (_startDate == null && _endDate == null) {
      label = 'Todo el historial';
    } else if (_startDate != null && _endDate != null) {
      final s = _startDate!;
      final e = _endDate!;
      if (s.year == e.year && s.month == e.month && s.day == e.day) {
        label = 'Hoy: ${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')}/${s.year}';
      } else {
        label = '${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')}/${s.year} '
            '➔ ${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}';
      }
    } else {
      label = 'Filtrar rango';
    }

    return OutlinedButton.icon(
      onPressed: _selectDateRange,
      icon: Icon(Icons.calendar_today_outlined, size: 18, color: colors.primary),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: colors.onSurface,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: colors.surfaceContainerLowest,
      ),
    );
  }

  Widget _buildPresetsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPresetChip('hoy', 'Hoy'),
        const SizedBox(width: 6),
        _buildPresetChip('proximos7dias', 'Próx. 7 días'),
        const SizedBox(width: 6),
        _buildPresetChip('mes', 'Este mes'),
        const SizedBox(width: 6),
        _buildPresetChip('todo', 'Todo'),
      ],
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final isSelected = _selectedPreset == key;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyPreset(key),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
      ),
      selectedColor: colors.primary,
      backgroundColor: colors.surfaceContainerLow,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar por equipo, plan, tipo o tarea…',
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => _searchCtrl.clear(),
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildCategoryChips({
    required int urgentCount,
    required int overdueCount,
    required bool scrollable,
  }) {
    final categories = <(_PreventiveFilterTab, String, IconData, Color)>[
      (_PreventiveFilterTab.all, 'Todos', Icons.all_inbox_outlined, const Color(0xFF1E293B)),
      (_PreventiveFilterTab.urgent, 'Urgentes ($urgentCount)', Icons.alarm_outlined, const Color(0xFFC2410C)),
      (_PreventiveFilterTab.upcoming, 'Próximos', Icons.schedule_outlined, const Color(0xFFD97706)),
      (_PreventiveFilterTab.onSchedule, 'Al día', Icons.check_circle_outline, const Color(0xFF15803D)),
      (_PreventiveFilterTab.overdue, 'Vencidos ($overdueCount)', Icons.error_outline, const Color(0xFFDC2626)),
      (_PreventiveFilterTab.paused, 'Pausados', Icons.pause_circle_outline, const Color(0xFF64748B)),
    ];

    final chips = categories.map((item) {
      final isSelected = _tab == item.$1;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;

      return FilterChip(
        avatar: Icon(
          item.$3,
          size: 16,
          color: isSelected ? Colors.white : item.$4,
        ),
        label: Text(item.$2),
        selected: isSelected,
        onSelected: (_) => setState(() => _tab = item.$1),
        selectedColor: item.$4,
        backgroundColor: colors.surfaceContainerLow,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : colors.onSurface,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)).toList(),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildSummaryBar(int count, int urgent, int overdue) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onTimeRatio = count > 0 ? (((count - overdue) / count) * 100).clamp(0, 100).toInt() : 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            '$count plan(es) preventivo(s)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          if (urgent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$urgent urgente(s)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
              ),
            ),
          if (overdue > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$overdue vencido(s)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: onTimeRatio >= 85
                  ? const Color(0xFFDCFCE7)
                  : (onTimeRatio >= 70 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: onTimeRatio >= 85
                    ? const Color(0xFF15803D).withValues(alpha: 0.3)
                    : const Color(0xFFDC2626).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  onTimeRatio >= 85 ? Icons.trending_up : Icons.trending_down,
                  size: 13,
                  color: onTimeRatio >= 85 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 4),
                Text(
                  'Salud: $onTimeRatio% al día',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: onTimeRatio >= 85 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Por fecha de ejecución',
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _assetLevelLabel(AssetLevel level) {
  switch (level) {
    case AssetLevel.equipment:
      return 'Equipo';
    case AssetLevel.subEquipment:
      return 'Subequipo';
    case AssetLevel.part:
      return 'Parte';
    case AssetLevel.subPart:
      return 'Subparte';
  }
}

class _PreventiveCard extends StatefulWidget {
  const _PreventiveCard({
    required this.schedule,
    required this.canGenerateOt,
    required this.isAdmin,
    required this.onGenerateOt,
    required this.onDuplicate,
    required this.onAmend,
    required this.onToggleStatus,
  });

  final PreventiveSchedule schedule;
  final bool canGenerateOt;
  final bool isAdmin;
  final VoidCallback onGenerateOt;
  final VoidCallback onDuplicate;
  final VoidCallback onAmend;
  final VoidCallback onToggleStatus;

  @override
  State<_PreventiveCard> createState() => _PreventiveCardState();
}

class _PreventiveCardState extends State<_PreventiveCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
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
    final accentColor = isPaused ? Colors.grey.shade400 : alertTextColor;
    final hasActivities = schedule.activities.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: accentColor,
            ),
            Expanded(
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
                            if (hasActivities)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_tree_outlined, size: 12, color: Color(0xFF475569)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${schedule.activities.length} componentes',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                  ],
                                ),
                              ),
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
                    if (hasActivities) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 18,
                                color: const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _expanded
                                      ? 'Ocultar actividades por componente (${schedule.activities.length})'
                                      : 'Ver desglose por componente (${schedule.activities.length}) y frecuencias',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 8),
                        Column(
                          children: schedule.activities.map((act) {
                            final actNextStr = '${act.nextDate.day}/${act.nextDate.month}/${act.nextDate.year}';
                            final (actBg, actFg, actStatus) = switch (act.alertLevel) {
                              PreventiveAlertLevel.overdue => (
                                  const Color(0xFFFEE2E2),
                                  const Color(0xFFDC2626),
                                  'Vencido (${act.daysRemaining.abs()}d)'
                                ),
                              PreventiveAlertLevel.urgent => (
                                  const Color(0xFFFFEDD5),
                                  const Color(0xFFC2410C),
                                  'Urgente (${act.daysRemaining}d)'
                                ),
                              PreventiveAlertLevel.upcoming => (
                                  const Color(0xFFFEF3C7),
                                  const Color(0xFFB45309),
                                  'Próximo (${act.daysRemaining}d)'
                                ),
                              PreventiveAlertLevel.onSchedule => (
                                  const Color(0xFFDCFCE7),
                                  const Color(0xFF15803D),
                                  'Al día (${act.daysRemaining}d)'
                                ),
                            };
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.settings_suggest_outlined, size: 14, color: Color(0xFF475569)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${act.childAssetId} - ${act.childAssetName}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          act.frequencyLabel,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: actBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          actStatus,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: actFg),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Actividad: ${act.description}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                  ),
                                  Text(
                                    'Próxima fecha: $actNextStr',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                  if (act.materials.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: act.materials.map((m) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Text(
                                            '${m.quantity} ${m.unit} - ${m.name}',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
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
                            if (widget.canGenerateOt && !isPaused)
                              if (schedule.canGenerateWorkOrder)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onPressed: widget.onGenerateOt,
                                  icon: const Icon(Icons.assignment_add, size: 16),
                                  label: Text(
                                    hasActivities ? 'Generar OT Consolidada' : 'Generar OT',
                                    style: const TextStyle(fontSize: 12),
                                  ),
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
                            if (widget.canGenerateOt || widget.isAdmin) ...[
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                tooltip: 'Opciones del Plan',
                                onSelected: (value) {
                                  if (value == 'duplicate') widget.onDuplicate();
                                  if (value == 'amend') widget.onAmend();
                                  if (value == 'toggle') widget.onToggleStatus();
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy_all, size: 16, color: Color(0xFF0284C7)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Duplicar / Usar como Plantilla',
                                            style: TextStyle(fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.isAdmin) ...[
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
                                          SizedBox(width: 8),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Representa una actividad individual dentro de un componente hijo.
class _SingleActivityDraft {
  _SingleActivityDraft({String defaultName = ''})
      : descCtrl = TextEditingController(text: 'Mantenimiento preventivo de $defaultName'),
        intervalCtrl = TextEditingController(text: '2'),
        matNameCtrl = TextEditingController(),
        matQtyCtrl = TextEditingController(text: '1'),
        matUnitCtrl = TextEditingController(text: 'pza');

  final TextEditingController descCtrl;
  final TextEditingController intervalCtrl;
  String unit = 'meses'; // sin tildes para coincidir con DB
  final List<PreventiveMaterial> materials = [];

  final TextEditingController matNameCtrl;
  final TextEditingController matQtyCtrl;
  final TextEditingController matUnitCtrl;

  void addMaterial() {
    final name = matNameCtrl.text.trim();
    final qty = double.tryParse(matQtyCtrl.text.trim()) ?? 1.0;
    final u = matUnitCtrl.text.trim().isEmpty ? 'pza' : matUnitCtrl.text.trim();
    if (name.isEmpty) return;
    materials.add(PreventiveMaterial(name: name, quantity: qty, unit: u));
    matNameCtrl.clear();
    matQtyCtrl.text = '1';
  }

  void dispose() {
    descCtrl.dispose();
    intervalCtrl.dispose();
    matNameCtrl.dispose();
    matQtyCtrl.dispose();
    matUnitCtrl.dispose();
  }
}

class _ChildActivityDraft {
  _ChildActivityDraft(this.child)
      : activities = [_SingleActivityDraft(defaultName: child.name)];

  final Asset child;
  bool isSelected = true;
  final List<_SingleActivityDraft> activities;

  void addActivity() {
    activities.add(_SingleActivityDraft(defaultName: child.name));
  }

  void removeActivity(int index) {
    if (index >= 0 && index < activities.length && activities.length > 1) {
      activities[index].dispose();
      activities.removeAt(index);
    }
  }

  void dispose() {
    for (final a in activities) {
      a.dispose();
    }
  }
}

class _CreatePreventivePlanDialog extends StatefulWidget {
  const _CreatePreventivePlanDialog({this.templateSchedule});

  final PreventiveSchedule? templateSchedule;

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

  List<Area> _areas = [];
  List<Asset> _allAssets = []; // todos los activos cargados (cross-area)
  List<Asset> _equipmentAssets = []; // equipos filtrados para selección
  Area? _selectedArea;
  Asset? _selectedAsset;
  bool _isTransversal = false; // Plan sin área específica
  ScheduleFrequency _selectedFrequency = ScheduleFrequency.annual;
  DateTime _startDate = DateTime.now();

  final List<PreventiveMaterial> _materials = [];
  final _matNameCtrl = TextEditingController();
  final _matQtyCtrl = TextEditingController(text: '1');
  final _matUnitCtrl = TextEditingController(text: 'pza');

  List<_ChildActivityDraft> _childDrafts = [];
  bool _loadingDependencies = true;
  bool _loadingChildren = false;
  bool _isSaving = false;

  // Para búsqueda global multiactivo transversal
  final _transversalSearchCtrl = TextEditingController();
  List<Asset> _allGlobalEquipments = [];
  List<Asset> _transversalSearchResults = [];
  final Set<Asset> _selectedTransversalAssets = {};
  bool _loadingGlobalEquipments = false;

  Map<String, PreventiveSchedule> _existingPlanByAsset = {};

  @override
  void initState() {
    super.initState();
    if (widget.templateSchedule != null) {
      final t = widget.templateSchedule!;
      _titleCtrl.text = t.title.isNotEmpty ? '${t.title} (Copia)' : 'Copia de ${t.id}';
      _typeCtrl.text = t.maintenanceType;
      _descCtrl.text = t.description;
      _selectedFrequency = t.frequency;
      _materials.addAll(t.materials);
      if (t.areaId.isEmpty || t.areaName == 'Transversal') {
        _isTransversal = true;
      }
    }
    _loadAreasAndAssets();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _typeCtrl.dispose();
    _descCtrl.dispose();
    _matNameCtrl.dispose();
    _matQtyCtrl.dispose();
    _matUnitCtrl.dispose();
    _transversalSearchCtrl.dispose();
    for (final d in _childDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAllGlobalEquipments() async {
    if (_allGlobalEquipments.isNotEmpty) return;
    setState(() => _loadingGlobalEquipments = true);
    try {
      final schedules = context.read<PreventiveScheduleViewModel>().schedules;
      _existingPlanByAsset = {
        for (final s in schedules)
          s.assetId: s
      };

      final assetRepo = getIt<AssetRepository>();
      final List<Asset> globalEquipments = [];
      for (final area in _areas) {
        final areaAssets = await assetRepo.getAllAssetsByArea(area.id);
        final eq = areaAssets.where((a) =>
            a.status == AssetStatus.active &&
            (a.level == AssetLevel.equipment || a.parentAssetId == null));
        globalEquipments.addAll(eq);
      }
      if (mounted) {
        setState(() {
          _allGlobalEquipments = globalEquipments;
          _transversalSearchResults = globalEquipments;
          _loadingGlobalEquipments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGlobalEquipments = false);
    }
  }

  void _filterTransversalAssets(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _transversalSearchResults = List.from(_allGlobalEquipments);
      } else {
        _transversalSearchResults = _allGlobalEquipments.where((a) {
          final idMatch = a.id.toLowerCase().contains(q);
          final nameMatch = a.name.toLowerCase().contains(q);
          final brandMatch = a.brand?.toLowerCase().contains(q) ?? false;
          final areaMatch = a.areaId.toLowerCase().contains(q);
          return idMatch || nameMatch || brandMatch || areaMatch;
        }).toList();
      }
    });
  }

  Future<void> _loadAreasAndAssets() async {
    try {
      final schedules = context.read<PreventiveScheduleViewModel>().schedules;
      _existingPlanByAsset = {
        for (final s in schedules)
          s.assetId: s
      };

      final areaRepo = getIt<AreaRepository>();
      final areas = await areaRepo.getAreas();
      if (mounted) {
        setState(() {
          _areas = areas;
          if (widget.templateSchedule != null && widget.templateSchedule!.areaId.isNotEmpty) {
            final match = areas.firstWhere(
              (a) => a.id == widget.templateSchedule!.areaId,
              orElse: () => areas.first,
            );
            _selectedArea = match;
            _loadAssetsForArea(_selectedArea!.id);
          } else {
            _selectedArea = null;
            _selectedAsset = null;
            _equipmentAssets = [];
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
      final schedules = context.read<PreventiveScheduleViewModel>().schedules;
      _existingPlanByAsset = {
        for (final s in schedules)
          s.assetId: s
      };

      final assetRepo = getIt<AssetRepository>();
      final allAreaAssets = await assetRepo.getAllAssetsByArea(areaId);
      final activeAssets = allAreaAssets
          .where((a) => a.status == AssetStatus.active)
          .toList();

      final equipmentAssets = activeAssets
          .where((a) => a.level == AssetLevel.equipment || a.parentAssetId == null)
          .toList();

      final listToUse = equipmentAssets.isNotEmpty ? equipmentAssets : activeAssets;

      if (mounted) {
        setState(() {
          _allAssets = activeAssets;
          _equipmentAssets = listToUse;
          _selectedAsset = null;
          _loadingDependencies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDependencies = false);
    }
  }

  Future<void> _loadChildrenForAsset(String parentId, [List<Asset>? allAreaAssets]) async {
    setState(() => _loadingChildren = true);
    for (final d in _childDrafts) {
      d.dispose();
    }
    _childDrafts.clear();

    try {
      final assets = allAreaAssets ??
          (_selectedArea != null
              ? await getIt<AssetRepository>().getAllAssetsByArea(_selectedArea!.id)
              : _allAssets);

      final children = assets.where((a) {
        return a.status == AssetStatus.active &&
            a.id != parentId &&
            (a.parentAssetId == parentId || a.ancestors.contains(parentId));
      }).toList();

      if (mounted) {
        setState(() {
          _childDrafts = children.map((c) {
            final draft = _ChildActivityDraft(c);
            // Si viene de plantilla, precargar actividades coincidentes
            if (widget.templateSchedule != null && widget.templateSchedule!.activities.isNotEmpty) {
              final matchingTemplateActs = widget.templateSchedule!.activities
                  .where((a) =>
                      a.childAssetId == c.id ||
                      a.childAssetName.toLowerCase() == c.name.toLowerCase() ||
                      a.childAssetLevel == c.level.name)
                  .toList();
              if (matchingTemplateActs.isNotEmpty) {
                draft.activities.clear();
                for (final ma in matchingTemplateActs) {
                  final actDraft = _SingleActivityDraft(defaultName: c.name);
                  actDraft.descCtrl.text = ma.description;
                  actDraft.intervalCtrl.text = ma.frequencyInterval.toString();
                  actDraft.unit = ma.frequencyUnit;
                  actDraft.materials.addAll(ma.materials);
                  draft.activities.add(actDraft);
                }
              }
            }
            return draft;
          }).toList();
          _loadingChildren = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChildren = false);
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

  DateTime _calculateNextDate(DateTime fromDate, int interval, String unit) {
    switch (unit.toLowerCase()) {
      case 'dias':
        return fromDate.add(Duration(days: interval));
      case 'semanas':
        return fromDate.add(Duration(days: interval * 7));
      case 'anios':
        return DateTime(fromDate.year + interval, fromDate.month, fromDate.day);
      case 'meses':
      default:
        return DateTime(fromDate.year, fromDate.month + interval, fromDate.day);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final targets = _isTransversal && _selectedTransversalAssets.isNotEmpty
        ? _selectedTransversalAssets.toList()
        : (_selectedAsset != null ? [_selectedAsset!] : <Asset>[]);

    final duplicateTargets = targets.where((t) => _existingPlanByAsset.containsKey(t.id)).toList();
    if (duplicateTargets.isNotEmpty) {
      final first = duplicateTargets.first;
      final existingPlan = _existingPlanByAsset[first.id]!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El equipo ${first.id} (${first.name}) ya cuenta con el Plan Preventivo ${existingPlan.id}. '
            'No se permite crear múltiples planes para el mismo equipo; use la opción "Editar Plan" con autorización gerencial.',
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final selectedDrafts = _childDrafts.where((d) => d.isSelected).toList();
      final List<PreventiveChildActivity> baseActivities = [];

      for (final d in selectedDrafts) {
        for (final act in d.activities) {
          final interval = int.tryParse(act.intervalCtrl.text.trim()) ?? 1;
          final next = _calculateNextDate(_startDate, interval, act.unit);
          baseActivities.add(
            PreventiveChildActivity(
              childAssetId: d.child.id,
              childAssetName: d.child.name,
              childAssetLevel: d.child.level.name,
              description: act.descCtrl.text.trim().isNotEmpty
                  ? act.descCtrl.text.trim()
                  : 'Mantenimiento de ${d.child.name}',
              frequencyInterval: interval,
              frequencyUnit: act.unit,
              startDate: _startDate,
              nextDate: next,
              materials: List.from(act.materials),
            ),
          );
        }
      }

      DateTime computedNextDate = _selectedFrequency.calculateNextDate(_startDate);
      if (baseActivities.isNotEmpty) {
        baseActivities.sort((a, b) => a.nextDate.compareTo(b.nextDate));
        computedNextDate = baseActivities.first.nextDate;
      }

      final vm = context.read<PreventiveScheduleViewModel>();
      int createdCount = 0;

      for (final target in targets) {
        final schedule = PreventiveSchedule(
          id: '',
          title: _titleCtrl.text.trim(),
          assetId: target.id,
          assetName: target.name,
          areaId: target.areaId,
          areaName: target.areaId,
          maintenanceType: _typeCtrl.text.trim(),
          frequency: _selectedFrequency,
          description: _descCtrl.text.trim(),
          materials: _materials,
          activities: baseActivities,
          startDate: _startDate,
          nextDate: computedNextDate,
          status: ScheduleStatus.active,
        );

        final ok = await vm.createSchedule(
          schedule: schedule,
          userId: user.userId,
          userName: user.username,
        );
        if (ok) {
          createdCount++;
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                vm.errorMessage.isNotEmpty
                    ? vm.errorMessage
                    : 'Error al crear el plan preventivo.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }

      if (mounted && createdCount > 0) {
        if (createdCount > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('¡Se crearon $createdCount planes preventivos transversales exitosamente!')),
          );
        }
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Unidades de frecuencia normalizadas sin tildes (coinciden con DB)
  static const _frequencyUnits = [
    ('dias', 'Días'),
    ('semanas', 'Semanas'),
    ('meses', 'Meses'),
    ('anios', 'Años'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Definir Plan Preventivo por Componentes'),
      content: SizedBox(
        width: responsiveDialogWidth(context, 740),
        child: _loadingDependencies
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 480;

                    // === Área (opcional con toggle transversal) ===
                    Widget areaSection;
                    if (_isTransversal) {
                      areaSection = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.public, size: 18, color: Color(0xFF0284C7)),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Plan Transversal (Multiactivo entre Áreas)',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() => _isTransversal = false),
                                  child: const Text('Cambiar a Plan por Área', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Buscador de activos global
                            TextField(
                              controller: _transversalSearchCtrl,
                              onChanged: _filterTransversalAssets,
                              decoration: InputDecoration(
                                labelText: 'Buscar tipo o nombre de equipo (ej. Aire, Bomba, Compresor...)',
                                hintText: 'Filtra equipos en todas las áreas...',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: _transversalSearchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _transversalSearchCtrl.clear();
                                          _filterTransversalAssets('');
                                        },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Resultados y multi-selección
                            if (_loadingGlobalEquipments)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Equipos encontrados: ${_transversalSearchResults.length}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedTransversalAssets.addAll(_transversalSearchResults);
                                            if (_selectedAsset == null && _transversalSearchResults.isNotEmpty) {
                                              _selectedAsset = _transversalSearchResults.first;
                                              _loadChildrenForAsset(_selectedAsset!.id);
                                            }
                                          });
                                        },
                                        child: const Text('Marcar Todos', style: TextStyle(fontSize: 11)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedTransversalAssets.clear();
                                          });
                                        },
                                        child: const Text('Desmarcar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 140),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _transversalSearchResults.length,
                                  itemBuilder: (ctx, idx) {
                                    final eq = _transversalSearchResults[idx];
                                    final isChecked = _selectedTransversalAssets.contains(eq);
                                    final existingPlan = _existingPlanByAsset[eq.id];
                                    return CheckboxListTile(
                                      value: isChecked,
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      title: Text(
                                        '${eq.id} - ${eq.name}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: existingPlan != null ? Colors.amber.shade900 : null,
                                        ),
                                      ),
                                      subtitle: Text(
                                        existingPlan != null
                                            ? 'Área: ${eq.areaId} · ${eq.brand ?? ""} · ⚠️ Ya tiene Plan: ${existingPlan.id}'
                                            : 'Área: ${eq.areaId} · ${eq.brand ?? ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: existingPlan != null ? Colors.amber.shade900 : null,
                                          fontWeight: existingPlan != null ? FontWeight.w500 : null,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedTransversalAssets.add(eq);
                                            _selectedAsset = eq;
                                            _loadChildrenForAsset(eq.id);
                                          } else {
                                            _selectedTransversalAssets.remove(eq);
                                            if (_selectedAsset == eq) {
                                              _selectedAsset = _selectedTransversalAssets.isNotEmpty ? _selectedTransversalAssets.first : null;
                                            }
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              if (_selectedTransversalAssets.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'ℹ️ Se creará este plan para ${_selectedTransversalAssets.length} equipo(s) seleccionado(s).',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    } else {
                      areaSection = Autocomplete<Area>(
                        displayStringForOption: (a) => '${a.id} - ${a.name}',
                        initialValue: _selectedArea != null
                            ? TextEditingValue(text: '${_selectedArea!.id} - ${_selectedArea!.name}')
                            : null,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _areas;
                          }
                          final q = textEditingValue.text.toLowerCase().trim();
                          return _areas.where((a) =>
                              a.id.toLowerCase().contains(q) ||
                              a.name.toLowerCase().contains(q));
                        },
                        onSelected: (Area selection) {
                          setState(() {
                            _selectedArea = selection;
                            _selectedAsset = null;
                            _equipmentAssets = [];
                            _childDrafts.clear();
                            _loadAssetsForArea(selection.id);
                          });
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 680),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final a = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.location_city, size: 18),
                                      title: Text('${a.id} - ${a.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      onTap: () => onSelected(a),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Buscar Área *',
                              hintText: 'Escribe código o nombre del área...',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: const Icon(Icons.location_city, size: 18),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (controller.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Limpiar selección',
                                      onPressed: () {
                                        controller.clear();
                                        setState(() {
                                          _selectedArea = null;
                                          _selectedAsset = null;
                                          _equipmentAssets = [];
                                          _childDrafts.clear();
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.public, size: 18),
                                    tooltip: 'Cambiar a Plan Transversal',
                                    onPressed: () {
                                      setState(() => _isTransversal = true);
                                      _loadAllGlobalEquipments();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            validator: (v) => _isTransversal ? null : (_selectedArea == null ? 'Busca y selecciona un área' : null),
                          );
                        },
                      );
                    }

                    // === Equipo Principal (filtrable por búsqueda) ===
                    Widget assetField;
                    if (_selectedArea == null) {
                      assetField = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Busca y selecciona un área arriba para listar sus equipos disponibles',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (_equipmentAssets.isEmpty) {
                      assetField = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No se encontraron equipos principales activos en ${_selectedArea!.name}',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      assetField = Autocomplete<Asset>(
                        displayStringForOption: (a) => '${a.id} - ${a.name}',
                        initialValue: _selectedAsset != null
                            ? TextEditingValue(text: '${_selectedAsset!.id} - ${_selectedAsset!.name}')
                            : null,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _equipmentAssets;
                          }
                          final q = textEditingValue.text.toLowerCase().trim();
                          return _equipmentAssets.where((a) =>
                              a.id.toLowerCase().contains(q) ||
                              a.name.toLowerCase().contains(q) ||
                              (a.brand?.toLowerCase().contains(q) ?? false));
                        },
                        onSelected: (Asset selection) {
                          setState(() {
                            _selectedAsset = selection;
                            _loadChildrenForAsset(selection.id);
                          });
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 250, maxWidth: 680),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final a = options.elementAt(index);
                                    final existingPlan = _existingPlanByAsset[a.id];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        '${a.id} - ${a.name} (${_assetLevelLabel(a.level)})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: existingPlan != null ? Colors.amber.shade900 : null,
                                        ),
                                      ),
                                      subtitle: existingPlan != null
                                          ? Text('⚠️ Ya cuenta con el Plan ${existingPlan.id}', style: TextStyle(fontSize: 11, color: Colors.amber.shade900))
                                          : (a.brand != null && a.brand!.isNotEmpty ? Text('Marca: ${a.brand}', style: const TextStyle(fontSize: 11)) : null),
                                      trailing: existingPlan != null ? const Icon(Icons.warning_amber, size: 16, color: Colors.amber) : null,
                                      onTap: () => onSelected(a),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Buscar Equipo Principal *',
                              hintText: 'Escribe código o nombre del equipo...',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: const Icon(Icons.precision_manufacturing, size: 18),
                              suffixIcon: controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Limpiar selección',
                                      onPressed: () {
                                        controller.clear();
                                        setState(() {
                                          _selectedAsset = null;
                                          _childDrafts.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            validator: (v) {
                              if (_isTransversal) return null;
                              if (_selectedAsset == null) return 'Busca y selecciona un equipo';
                              if (_existingPlanByAsset.containsKey(_selectedAsset!.id)) {
                                return 'Este equipo ya tiene el plan ${_existingPlanByAsset[_selectedAsset!.id]!.id}. Edítelo con autorización gerencial.';
                              }
                              return null;
                            },
                          );
                        },
                      );
                    }

                    final freqField = DropdownButtonFormField<ScheduleFrequency>(
                      value: _selectedFrequency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Frecuencia Global *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ScheduleFrequency.globalFrequencies.map((f) {
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
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        'Fecha Base: ${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}',
                        style: const TextStyle(fontSize: 12),
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
                              labelText: 'Título del Plan Preventivo *',
                              hintText: 'Ej: Plan de Mantenimiento Integral Máquina Clasificadora',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa el título del plan'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Área
                          areaSection,
                          const SizedBox(height: 10),

                          // Equipo (solo si es por área específica)
                          if (!_isTransversal) ...[
                            assetField,
                            const SizedBox(height: 8),
                            if (_selectedAsset != null && _existingPlanByAsset.containsKey(_selectedAsset!.id)) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'El equipo ${_selectedAsset!.id} ya cuenta con el Plan ${_existingPlanByAsset[_selectedAsset!.id]!.id}',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'No se permite crear múltiples planes para un mismo equipo. Para modificar tareas, frecuencias o materiales, utilice la opción "Editar Plan" en la lista de planes (requiere autorización gerencial).',
                                            style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],

                          if (isNarrow) ...[
                            typeField,
                            const SizedBox(height: 10),
                            freqField,
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: dateField),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(flex: 3, child: typeField),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: freqField),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: dateField),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Objetivo / Procedimiento General del Equipo',
                              hintText: 'Ej: Asegurar el óptimo funcionamiento y calibración...',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(Icons.account_tree, color: Color(0xFF0284C7), size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Actividades en Componentes Hijos (Frecuencias Custom):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              if (_loadingChildren)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _childDrafts.isNotEmpty
                                ? 'Configura las tareas, frecuencia personalizada y repuestos de cada componente. Puedes agregar múltiples actividades por hijo:'
                                : 'Este equipo no tiene componentes hijos registrados. Puedes definir materiales globales abajo:',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),

                          if (_childDrafts.isNotEmpty) ...[
                            ..._childDrafts.map((draft) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: draft.isSelected ? const Color(0xFFF8FAFC) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: draft.isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.5) : Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: draft.isSelected,
                                          onChanged: (val) {
                                            setState(() => draft.isSelected = val ?? false);
                                          },
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${draft.child.id} - ${draft.child.name} (${_assetLevelLabel(draft.child.level)})',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: draft.isSelected ? const Color(0xFF0F172A) : Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                        if (draft.isSelected)
                                          TextButton.icon(
                                            onPressed: () => setState(() => draft.addActivity()),
                                            icon: const Icon(Icons.add_circle_outline, size: 16),
                                            label: const Text('Agregar actividad', style: TextStyle(fontSize: 11)),
                                          ),
                                      ],
                                    ),
                                    if (draft.isSelected) ...[
                                      ...draft.activities.asMap().entries.map((entry) {
                                        final actIdx = entry.key;
                                        final act = entry.value;
                                        return Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Actividad ${actIdx + 1}',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                                    ),
                                                  ),
                                                  if (draft.activities.length > 1)
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                                                      tooltip: 'Eliminar esta actividad',
                                                      onPressed: () => setState(() => draft.removeActivity(actIdx)),
                                                      constraints: const BoxConstraints(),
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              TextFormField(
                                                controller: act.descCtrl,
                                                decoration: const InputDecoration(
                                                  labelText: 'Descripción de la actividad *',
                                                  isDense: true,
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextFormField(
                                                      controller: act.intervalCtrl,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      decoration: const InputDecoration(
                                                        labelText: 'Cada (número) *',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      validator: (v) {
                                                        if (v == null || v.trim().isEmpty) return 'Requerido';
                                                        final n = int.tryParse(v.trim());
                                                        if (n == null || n < 1) return '≥ 1';
                                                        return null;
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 3,
                                                    child: DropdownButtonFormField<String>(
                                                      value: act.unit,
                                                      isExpanded: true,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Unidad *',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      items: _frequencyUnits.map((u) {
                                                        return DropdownMenuItem(value: u.$1, child: Text(u.$2));
                                                      }).toList(),
                                                      onChanged: (u) {
                                                        if (u != null) {
                                                          setState(() => act.unit = u);
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Materiales/Repuestos para esta actividad:',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: TextField(
                                                      controller: act.matNameCtrl,
                                                      decoration: const InputDecoration(
                                                        hintText: 'Repuesto (ej. Rodamiento 6204)',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    flex: 1,
                                                    child: TextField(
                                                      controller: act.matQtyCtrl,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
                                                      controller: act.matUnitCtrl,
                                                      decoration: const InputDecoration(
                                                        hintText: 'Unidad',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () => setState(() => act.addMaterial()),
                                                    icon: const Icon(Icons.add_circle, color: Color(0xFF0284C7)),
                                                    tooltip: 'Agregar material',
                                                  ),
                                                ],
                                              ),
                                              if (act.materials.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: act.materials.map((m) {
                                                    return Chip(
                                                      label: Text(
                                                        '${m.quantity} ${m.unit} - ${m.name}',
                                                        style: const TextStyle(fontSize: 11),
                                                      ),
                                                      onDeleted: () => setState(() => act.materials.remove(m)),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
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
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar Plan'),
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
  bool _isSaving = false;

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

    setState(() => _isSaving = true);

    try {
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Modificar Plan: ${widget.schedule.id}'),
        ],
      ),
      content: SizedBox(
        width: responsiveDialogWidth(context, 500),
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
                items: ScheduleFrequency.globalFrequencies.map((f) {
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
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Aplicar Modificación'),
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
  bool _isSaving = false;

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

    setState(() => _isSaving = true);

    try {
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isPausing ? 'Confirmar Suspensión' : 'Confirmar Reactivación'),
        ),
      ],
    );
  }
}

