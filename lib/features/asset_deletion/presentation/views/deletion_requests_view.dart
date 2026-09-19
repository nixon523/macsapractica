import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/asset_delete_request.dart';
import '../viewmodels/deletion_requests_viewmodel.dart';

enum _DeletionFilterTab { pending, resolved, all }

class DeletionRequestsView extends StatefulWidget {
  const DeletionRequestsView({super.key});

  @override
  State<DeletionRequestsView> createState() => _DeletionRequestsViewState();
}

class _DeletionRequestsViewState extends State<DeletionRequestsView> {
  late final DeletionRequestsViewModel _viewModel = getIt<DeletionRequestsViewModel>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.load();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DeletionRequestsViewModel>.value(
      value: _viewModel,
      child: const _DeletionRequestsContent(),
    );
  }
}

class _DeletionRequestsContent extends StatefulWidget {
  const _DeletionRequestsContent();

  @override
  State<_DeletionRequestsContent> createState() => _DeletionRequestsContentState();
}

class _DeletionRequestsContentState extends State<_DeletionRequestsContent> {
  _DeletionFilterTab _filterTab = _DeletionFilterTab.pending;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPreset = 'todo';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<DeletionRequestsViewModel>().load(
          startDate: _startDate,
          endDate: _endDate,
        );
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

  Future<void> _confirmApprove(AssetDeleteRequest request) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar eliminación'),
        content: Text(
          'Se dará de baja ${request.assetId} (${request.assetName}) junto '
          'con su subárbol (${request.subtreeCount} activo(s)). '
          'Quedará registrado en el kardex. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final viewModel = context.read<DeletionRequestsViewModel>();
    final ok = await viewModel.approve(
      request: request,
      approvedByUserId: user.userId,
      approvedByUserName: user.username,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Solicitud aprobada: ${request.assetId} dado de baja.'
              : 'Error: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  Future<void> _confirmReject(AssetDeleteRequest request) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes indicar el motivo del rechazo.')),
      );
      return;
    }

    final viewModel = context.read<DeletionRequestsViewModel>();
    final ok = await viewModel.reject(
      request: request,
      rejectedByUserId: user.userId,
      rejectedByUserName: user.username,
      rejectReason: reason,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Solicitud rechazada.' : 'Error: ${viewModel.errorMessage}',
        ),
      ),
    );
  }

  List<AssetDeleteRequest> _filterRequests(List<AssetDeleteRequest> list) {
    var filtered = switch (_filterTab) {
      _DeletionFilterTab.pending => list.where((r) => r.status == DeletionRequestStatus.pending).toList(),
      _DeletionFilterTab.resolved => list.where((r) => r.status != DeletionRequestStatus.pending).toList(),
      _DeletionFilterTab.all => list,
    };

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final id = r.assetId.toLowerCase();
        final name = r.assetName.toLowerCase();
        final area = r.areaId.toLowerCase();
        final user = r.requestedByUserName.toLowerCase();
        final reason = r.reason.toLowerCase();
        return id.contains(_searchQuery) ||
            name.contains(_searchQuery) ||
            area.contains(_searchQuery) ||
            user.contains(_searchQuery) ||
            reason.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeletionRequestsViewModel>();
    final allRequests = [...vm.pendingRequests, ...vm.resolvedRequests];
    final filtered = _filterRequests(allRequests);
    final pendingCount = vm.pendingRequests.length;

    return Scaffold(
      body: Column(
        children: [
          _buildFilterSection(
            isNarrow: MediaQuery.of(context).size.width < 750,
            pendingCount: pendingCount,
          ),
          const Divider(height: 1),
          _buildSummaryBar(filtered.length, pendingCount),
          Expanded(
            child: switch (vm.viewState) {
              DeletionRequestsViewState.loading => const Center(child: CircularProgressIndicator()),
              DeletionRequestsViewState.error => Center(child: Text('Error: ${vm.errorMessage}')),
              DeletionRequestsViewState.initial || DeletionRequestsViewState.success => filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Sin resultados para "$_searchQuery"'
                                  : 'No hay solicitudes para el filtro seleccionado.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Intenta con otro término o limpia la barra de búsqueda.'
                                  : 'Prueba seleccionando otro rango de fechas o pestaña.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            if (_selectedPreset != 'todo') ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _applyPreset('todo'),
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('Ver todas las solicitudes'),
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
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final req = filtered[index];
                          return _ModernDeletionRequestCard(
                            request: req,
                            isProcessing: vm.isProcessing,
                            onApprove: () => _confirmApprove(req),
                            onReject: () => _confirmReject(req),
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
    required int pendingCount,
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

          // Fila 2: Búsqueda y Chips de Estado
          if (!isNarrow)
            Row(
              children: [
                Expanded(flex: 3, child: _buildSearchBar()),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _buildStatusChips(pendingCount: pendingCount, scrollable: false)),
              ],
            )
          else ...[
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildStatusChips(pendingCount: pendingCount, scrollable: true),
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
        hintText: 'Buscar por activo, solicitante, área o motivo…',
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

  Widget _buildStatusChips({
    required int pendingCount,
    required bool scrollable,
  }) {
    final categories = <(_DeletionFilterTab, String, IconData, Color)>[
      (_DeletionFilterTab.pending, 'Pendientes ($pendingCount)', Icons.hourglass_top_outlined, const Color(0xFFC2410C)),
      (_DeletionFilterTab.resolved, 'Resueltas', Icons.done_all_outlined, const Color(0xFF15803D)),
      (_DeletionFilterTab.all, 'Todas', Icons.all_inbox_outlined, const Color(0xFF1E293B)),
    ];

    final chips = categories.map((item) {
      final isSelected = _filterTab == item.$1;
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
        onSelected: (_) => setState(() => _filterTab = item.$1),
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

  Widget _buildSummaryBar(int count, int pendingCount) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_late_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                '$count solicitud(es)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$pendingCount pendiente(s)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                  ),
                ),
              ],
            ],
          ),
          Text(
            'Por fecha de solicitud',
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

/// Tarjeta ejecutiva de solicitud de baja con formato visual del Kardex.
class _ModernDeletionRequestCard extends StatelessWidget {
  const _ModernDeletionRequestCard({
    required this.request,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final AssetDeleteRequest request;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '—';
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
    final (statusColor, statusBg, statusLabel) = switch (request.status) {
      DeletionRequestStatus.pending => (const Color(0xFFC2410C), const Color(0xFFFFEDD5), 'Pendiente de Aprobación'),
      DeletionRequestStatus.approved => (const Color(0xFF15803D), const Color(0xFFDCFCE7), 'Baja Aprobada'),
      DeletionRequestStatus.rejected => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), 'Baja Rechazada'),
    };

    final requestedDateStr = _formatTimestamp(request.requestedAt);
    final fullRequestedDate = request.requestedAt != null
        ? '${request.requestedAt!.day.toString().padLeft(2, '0')}/${request.requestedAt!.month.toString().padLeft(2, '0')}/${request.requestedAt!.year} ${request.requestedAt!.hour.toString().padLeft(2, '0')}:${request.requestedAt!.minute.toString().padLeft(2, '0')}'
        : '—';

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
            // Franja lateral con acento de color de estado
            Container(
              width: 5,
              color: statusColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Tag, Nombre y Badge de Resolución
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            request.status == DeletionRequestStatus.pending
                                ? Icons.pending_actions_outlined
                                : request.status == DeletionRequestStatus.approved
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                            size: 18,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: theme.colorScheme.outlineVariant),
                                    ),
                                    child: Text(
                                      request.assetId,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Área: ${request.areaId}',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                request.assetName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Motivo de la solicitud
                    Text(
                      'Motivo: ${request.reason}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),

                    if (request.decisionReason != null && request.decisionReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Decisión de Gerencia: ${request.decisionReason}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Footer: Metadatos y acciones
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_tree_outlined, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Subárbol: ${request.subtreeCount} activo(s)',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  request.requestedByUserName,
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Tooltip(
                              message: fullRequestedDate,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    requestedDateStr,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (request.status == DeletionRequestStatus.pending)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                onPressed: isProcessing ? null : onReject,
                                icon: const Icon(Icons.close, size: 15),
                                label: const Text('Rechazar', style: TextStyle(fontSize: 11.5)),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                onPressed: isProcessing ? null : onApprove,
                                icon: const Icon(Icons.check, size: 15),
                                label: const Text('Aprobar', style: TextStyle(fontSize: 11.5)),
                              ),
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
