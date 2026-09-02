import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/kardex_log.dart';
import '../viewmodels/kardex_list_viewmodel.dart';

/// Vista profesional de Bitácora / Kardex de auditoría.
/// Inicia SIEMPRE en el día de HOY con filtros de rango Desde-Hasta,
/// módulos de negocio y búsqueda instantánea.
class KardexListView extends StatefulWidget {
  const KardexListView({super.key, this.entityId});

  final String? entityId;

  @override
  State<KardexListView> createState() => _KardexListViewState();
}

class _KardexListViewState extends State<KardexListView> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  String _selectedPreset = 'hoy';
  String? _selectedModule;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Inicia SIEMPRE en el día de HOY
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final vm = context.read<KardexListViewModel>();
    if (widget.entityId != null && widget.entityId!.isNotEmpty) {
      vm.loadForEntity(widget.entityId!);
    } else {
      vm.loadAll(
        limit: 200,
        module: _selectedModule,
        startDate: _startDate,
        endDate: _endDate,
      );
    }
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
        case 'ayer':
          final yesterday = now.subtract(const Duration(days: 1));
          _startDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
          _endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
          break;
        case '7dias':
          final sevenDaysAgo = now.subtract(const Duration(days: 6));
          _startDate = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'mes':
          _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'todo':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
    _loadData();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day),
            ),
      helpText: 'Seleccionar Rango de Fechas (Desde - Hasta)',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar Filtro',
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = 'personalizado';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadData();
    }
  }

  void _onModuleChanged(String? module) {
    if (_selectedModule == module) return;
    setState(() {
      _selectedModule = module;
    });
    _loadData();
  }

  List<KardexLog> _filterLogs(List<KardexLog> logs) {
    if (_searchQuery.isEmpty) return logs;
    return logs.where((log) {
      final entity = log.entityId.toLowerCase();
      final user = log.userName.toLowerCase();
      final details = log.details.toLowerCase();
      final action = log.action.toLowerCase();
      return entity.contains(_searchQuery) ||
          user.contains(_searchQuery) ||
          details.contains(_searchQuery) ||
          action.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KardexListViewModel>();
    final isEntityDetail = widget.entityId != null && widget.entityId!.isNotEmpty;

    final filteredLogs = _filterLogs(vm.logs);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;
        final isTablet = constraints.maxWidth >= 550 && constraints.maxWidth < 850;

        return Column(
          children: [
            if (!isEntityDetail) ...[
              _buildFilterSection(isDesktop: isDesktop, isTablet: isTablet),
              const Divider(height: 1),
            ],
            Expanded(
              child: _buildBody(vm, filteredLogs),
            ),
          ],
        );
      },
    );

    if (isEntityDetail) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Historial / Kardex: ${widget.entityId}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _loadData,
            ),
          ],
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildFilterSection({required bool isDesktop, required bool isTablet}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Selector de Fechas (Desde - Hasta) y Presets
          if (isDesktop)
            Row(
              children: [
                _buildDateRangeButton(),
                const SizedBox(width: 12),
                Expanded(child: _buildPresetsRow()),
              ],
            )
          else ...[
            _buildDateRangeButton(),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildPresetsRow(),
            ),
          ],
          const SizedBox(height: 10),

          // Fila 2: Barra de búsqueda y Filtros por Módulo
          if (isDesktop)
            Row(
              children: [
                Expanded(flex: 3, child: _buildSearchBar()),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _buildModuleChips(scrollable: false)),
              ],
            )
          else ...[
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildModuleChips(scrollable: true),
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
        _buildPresetChip('ayer', 'Ayer'),
        const SizedBox(width: 6),
        _buildPresetChip('7dias', '7 días'),
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
        hintText: 'Buscar por entidad (ej: A1-001, OT-0001), usuario o detalle…',
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

  Widget _buildModuleChips({required bool scrollable}) {
    final modules = <(String?, String, IconData)>[
      (null, 'Todos', Icons.dashboard_outlined),
      ('ASSETS', 'Activos', Icons.precision_manufacturing_outlined),
      ('WORK_ORDERS', 'Órdenes', Icons.assignment_outlined),
      ('BREAKDOWNS', 'Averías', Icons.report_problem_outlined),
      ('PREVENTIVE', 'Preventivos', Icons.calendar_month_outlined),
      ('USERS', 'Usuarios', Icons.admin_panel_settings_outlined),
    ];

    final chips = modules.map((m) {
      final isSelected = _selectedModule == m.$1;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final chipColor = m.$1 == null ? const Color(0xFF1E293B) : colors.primary;

      return FilterChip(
        avatar: Icon(
          m.$3,
          size: 16,
          color: isSelected ? colors.onPrimary : chipColor,
        ),
        label: Text(m.$2),
        selected: isSelected,
        onSelected: (_) => _onModuleChanged(m.$1),
        selectedColor: chipColor,
        backgroundColor: colors.surfaceContainerLow,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? colors.onPrimary : colors.onSurface,
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

  Widget _buildBody(KardexListViewModel vm, List<KardexLog> logs) {
    if (vm.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Consultando bitácora de auditoría…', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (vm.errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Error al consultar el Kardex',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                vm.errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Sin resultados para "$_searchQuery"'
                    : 'No hay eventos registrados en este periodo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Intenta con otro término o limpia la barra de búsqueda.'
                    : 'Prueba seleccionando otro rango de fechas o cambiando de módulo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_selectedPreset != 'todo') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _applyPreset('todo'),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Ver todo el historial'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: Column(
        children: [
          // Banner de conteo / Resumen
          _buildSummaryBar(logs.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: logs.length,
              itemBuilder: (context, index) => _KardexLogTile(log: logs[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(int count) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            '$count registro(s) de auditoría',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            'Orden cronológico inverso',
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

/// Tarjeta ejecutiva para cada evento de auditoría del Kardex.
class _KardexLogTile extends StatelessWidget {
  const _KardexLogTile({required this.log});

  final KardexLog log;

  static const Map<String, String> _actionLabels = {
    'WORK_ORDER_CREATED': 'Orden de Trabajo Creada',
    'WORK_ORDER_STATUS_CHANGED': 'Cambio de Estado en OT',
    'WORK_ORDER_UPDATED': 'OT Actualizada',
    'BREAKDOWN_REPORTED': 'Reporte de Avería Creado',
    'BREAKDOWN_LINKED_WORK_ORDER': 'Reporte Vinculado a OT',
    'BREAKDOWN_RESOLVED': 'Reporte de Avería Resuelto',
    'BREAKDOWN_REJECTED': 'Reporte de Avería Rechazado',
    'ASSET_DELETE_REQUESTED': 'Solicitud de Baja de Activo',
    'ASSET_DELETED': 'Baja de Activo Aprobada',
    'ASSET_DELETE_REJECTED': 'Baja de Activo Rechazada',
    'ASSET_CREATED': 'Activo Registrado',
    'ASSET_UPDATED': 'Información de Activo Modificada',
    'ASSET_REACTIVATED': 'Activo Reactivado',
    'ASSET_DEACTIVATED': 'Activo Desactivado',
    'ASSET_TRANSFER': 'Activo Transferido de Área',
    'PREVENTIVE_SCHEDULE_CREATED': 'Programa Preventivo Creado',
    'PREVENTIVE_SCHEDULE_UPDATED': 'Programa Preventivo Modificado',
    'PREVENTIVE_SCHEDULE_DELETED': 'Programa Preventivo Eliminado',
    'PREVENTIVE_SCHEDULE_STATUS_CHANGED': 'Estado Preventivo Modificado',
    'USER_CREATED': 'Usuario Registrado',
    'USER_UPDATED': 'Usuario Actualizado',
    'USER_STATUS_CHANGED': 'Estado de Usuario Modificado',
    'PASSWORD_RESET_TEMPORARY': 'Clave Temporal Asignada',
  };

  static Color _getModuleColor(String module) {
    return switch (module.toUpperCase()) {
      'ASSETS' => const Color(0xFF1565C0), // Azul corporativo
      'WORK_ORDERS' => const Color(0xFF6A1B9A), // Púrpura ejecutivo
      'BREAKDOWNS' => const Color(0xFFD84315), // Naranja quemado / Averías
      'PREVENTIVE' => const Color(0xFF00695C), // Verde azulado / Preventivo
      'USERS' => const Color(0xFF37474F), // Gris oscuro / Usuarios
      _ => const Color(0xFF455A64),
    };
  }

  static IconData _getModuleIcon(String module) {
    return switch (module.toUpperCase()) {
      'ASSETS' => Icons.precision_manufacturing_outlined,
      'WORK_ORDERS' => Icons.assignment_outlined,
      'BREAKDOWNS' => Icons.report_problem_outlined,
      'PREVENTIVE' => Icons.calendar_month_outlined,
      'USERS' => Icons.admin_panel_settings_outlined,
      _ => Icons.history,
    };
  }

  static String _getModuleLabel(String module) {
    return switch (module.toUpperCase()) {
      'ASSETS' => 'Activos',
      'WORK_ORDERS' => 'Órdenes de Trabajo',
      'BREAKDOWNS' => 'Averías',
      'PREVENTIVE' => 'Preventivo',
      'USERS' => 'Usuarios',
      _ => module,
    };
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final dayStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final diff = now.difference(dt);
    String relative;
    if (diff.inMinutes < 1) {
      relative = 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      relative = 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      relative = 'Hoy a las $timeStr';
    } else if (diff.inDays == 1 || (diff.inHours < 48 && dt.day == now.subtract(const Duration(days: 1)).day)) {
      relative = 'Ayer a las $timeStr';
    } else {
      relative = '$dayStr $timeStr';
    }

    return relative;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleColor = _getModuleColor(log.module);
    final moduleIcon = _getModuleIcon(log.module);
    final moduleLabel = _getModuleLabel(log.module);
    final actionName = _actionLabels[log.action] ?? log.action;
    final timeFormatted = _formatTimestamp(log.timestamp);
    final fullDate = '${log.timestamp.day.toString().padLeft(2, '0')}/${log.timestamp.month.toString().padLeft(2, '0')}/${log.timestamp.year} ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

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
            // Acento de color lateral por módulo
            Container(
              width: 5,
              color: moduleColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Icono, Acción y Tag de Entidad
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar temático del módulo
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: moduleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(moduleIcon, size: 18, color: moduleColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                actionName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                moduleLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: moduleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge con ID de entidad
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Text(
                            log.entityId,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Detalles del cambio
                    Text(
                      log.details,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Footer: Usuario y Timestamp
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Usuario responsable
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              log.userName.isNotEmpty ? log.userName : 'Sistema',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        // Fecha y hora
                        Tooltip(
                          message: fullDate,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                timeFormatted,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
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
            ),
          ],
        ),
      ),
    );
  }
}
