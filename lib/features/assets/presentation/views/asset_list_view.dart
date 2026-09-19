import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../domain/entities/asset.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../reports/asset_report_filter_dialog.dart';
import '../states/asset_state.dart';
import '../viewmodels/asset_list_viewmodel.dart';
import 'asset_create_view.dart';
import 'asset_detail_view.dart';
import 'asset_edit_view.dart';
import 'widgets/asset_card_widget.dart';

/// Cantidad de activos mostrados por página.
const _pageSize = 10;

class AssetListView extends StatefulWidget {
  const AssetListView({
    super.key,
    required this.areaId,
  });

  final String areaId;

  @override
  State<AssetListView> createState() => _AssetListViewState();
}

class _AssetListViewState extends State<AssetListView> {
  late final AssetListViewModel _viewModel = getIt<AssetListViewModel>();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  AssetStatus? _statusFilter;
  bool _showFullTree = false;
  int _currentPage = 0;

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPreset = 'todo';

  @override
  void initState() {
    super.initState();
    _startDate = null;
    _endDate = null;

    _searchCtrl.addListener(() {
      _runSearch();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitial();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _loadInitial() {
    if (_showFullTree) {
      _viewModel.fetchAllAssets(widget.areaId, status: _statusFilter);
    } else {
      _viewModel.fetchAssets(widget.areaId);
    }
  }

  bool get _isSearchActive =>
      _searchCtrl.text.trim().isNotEmpty || _statusFilter != null || _showFullTree || _startDate != null;

  void _refresh({bool forceRefresh = false}) {
    if (_showFullTree) {
      _viewModel.fetchAllAssets(widget.areaId, status: _statusFilter);
    } else if (_isSearchActive) {
      _runSearch();
    } else {
      _viewModel.fetchAssets(widget.areaId, forceRefresh: forceRefresh);
    }
  }

  void _runSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _currentPage = 0);
      _viewModel.search(
        widget.areaId,
        query: _searchCtrl.text,
        status: _statusFilter,
      );
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _statusFilter = null;
      _showFullTree = false;
      _currentPage = 0;
      _selectedPreset = 'todo';
      _startDate = null;
      _endDate = null;
    });
    _loadInitial();
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      _currentPage = 0;
      switch (preset) {
        case 'hoy':
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'semana':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
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
      helpText: 'Seleccionar Rango de Registro (Desde - Hasta)',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar Filtro',
    );
    if (picked != null) {
      setState(() {
        _selectedPreset = 'personalizado';
        _currentPage = 0;
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _toggleFullTree() {
    setState(() {
      _showFullTree = !_showFullTree;
      _currentPage = 0;
    });
    if (_showFullTree) {
      _viewModel.fetchAllAssets(widget.areaId, status: _statusFilter);
    } else if (_searchCtrl.text.trim().isNotEmpty || _statusFilter != null) {
      _runSearch();
    } else {
      _viewModel.fetchAssets(widget.areaId, forceRefresh: true);
    }
  }

  void _onAssetTap(Asset asset) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetDetailView(
          areaId: widget.areaId,
          asset: asset,
        ),
      ),
    );
    if (result == true && mounted) {
      _refresh(forceRefresh: true);
    }
  }

  Future<void> _createChild() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetCreateView(
          areaId: widget.areaId,
          parentAsset: null,
        ),
      ),
    );
    if (result != null && mounted) {
      _refresh(forceRefresh: true);
    }
  }

  Future<void> _editAsset(Asset asset) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetEditView(asset: asset),
      ),
    );
    if (result != null && mounted) {
      _refresh(forceRefresh: true);
    }
  }

  List<Asset> _filterByDate(List<Asset> assets) {
    if (_startDate == null || _endDate == null) return assets;
    return assets.where((a) {
      if (a.createdAt == null) return false;
      return a.createdAt!.isAfter(_startDate!) && a.createdAt!.isBefore(_endDate!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final canCreate = authVm.hasPermission('asset.create');
    final canEdit = authVm.hasPermission('asset.edit');

    return ChangeNotifierProvider<AssetListViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activos del Área'),
          actions: [
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Generar Reporte / Inventario (PDF / Excel)',
              onPressed: () => AssetReportFilterDialog.showAreaReport(
                context,
                areaId: widget.areaId,
              ),
            ),
            IconButton(
              icon: Icon(
                _showFullTree ? Icons.account_tree : Icons.account_tree_outlined,
                color: _showFullTree ? Theme.of(context).colorScheme.primary : null,
              ),
              tooltip: _showFullTree
                  ? 'Ver solo equipos raíz'
                  : 'Ver árbol jerárquico completo (padres e hijos)',
              onPressed: _toggleFullTree,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: () => _refresh(forceRefresh: true),
            ),
          ],
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                tooltip: 'Crear equipo',
                onPressed: _createChild,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Equipo'),
              )
            : null,
        body: Consumer<AssetListViewModel>(
          builder: (context, viewModel, child) {
            final state = viewModel.state;
            final isNarrow = MediaQuery.of(context).size.width < 750;

            final dateFilteredAssets = _filterByDate(state.assets);

            return Column(
              children: [
                _buildFilterSection(isNarrow: isNarrow),
                const Divider(height: 1),
                if (state.viewState == ViewState.success)
                  _buildSummaryBar(dateFilteredAssets),
                Expanded(
                  child: switch (state.viewState) {
                    ViewState.loading => const Center(child: CircularProgressIndicator()),
                    ViewState.error => _ErrorView(message: state.errorMessage),
                    ViewState.success => dateFilteredAssets.isEmpty
                        ? _EmptyView(
                            isSearching: _isSearchActive,
                            selectedPreset: _selectedPreset,
                            onShowAll: () => _applyPreset('todo'),
                            onCreate: !_isSearchActive && canCreate ? _createChild : null,
                          )
                        : _PaginatedAssetList(
                            assets: dateFilteredAssets,
                            currentPage: _currentPage,
                            isHierarchicalView: _isSearchActive || _showFullTree,
                            canEdit: canEdit,
                            onAssetTap: _onAssetTap,
                            onEditAsset: _editAsset,
                            onPageChanged: (page) {
                              setState(() => _currentPage = page);
                            },
                          ),
                    ViewState.initial => const SizedBox.shrink(),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterSection({required bool isNarrow}) {
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

          // Fila 2: Búsqueda y Chips de Estado / Árbol
          if (!isNarrow)
            Row(
              children: [
                Expanded(flex: 3, child: _buildSearchBar()),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _buildStatusAndTreeChips(scrollable: false)),
              ],
            )
          else ...[
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildStatusAndTreeChips(scrollable: true),
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
        _buildPresetChip('todo', 'Todo'),
        const SizedBox(width: 6),
        _buildPresetChip('hoy', 'Hoy'),
        const SizedBox(width: 6),
        _buildPresetChip('semana', 'Semana'),
        const SizedBox(width: 6),
        _buildPresetChip('mes', 'Mes'),
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
        hintText: 'Buscar por N° serie, nombre, ID o modelo…',
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: _clearSearch,
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

  Widget _buildStatusAndTreeChips({required bool scrollable}) {
    final statuses = <(AssetStatus?, String, IconData, Color)>[
      (null, 'Todos', Icons.all_inbox_outlined, const Color(0xFF1E293B)),
      (AssetStatus.active, 'Activos', Icons.check_circle_outline, const Color(0xFF15803D)),
      (AssetStatus.inactive, 'Inactivos', Icons.pause_circle_outline, const Color(0xFFB45309)),
      (AssetStatus.transferredDeactivated, 'Transferidos', Icons.swap_horiz_outlined, const Color(0xFF64748B)),
    ];

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final chips = <Widget>[
      ...statuses.map((item) {
        final isSelected = _statusFilter == item.$1;
        return FilterChip(
          avatar: Icon(
            item.$3,
            size: 16,
            color: isSelected ? Colors.white : item.$4,
          ),
          label: Text(item.$2),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _statusFilter = item.$1;
              _currentPage = 0;
            });
            if (_showFullTree) {
              _viewModel.fetchAllAssets(widget.areaId, status: _statusFilter);
            } else {
              _runSearch();
            }
          },
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
      }),
      // Chip adicional para Árbol Jerárquico
      FilterChip(
        avatar: Icon(
          Icons.account_tree_outlined,
          size: 16,
          color: _showFullTree ? Colors.white : colors.primary,
        ),
        label: const Text('Árbol Jerárquico'),
        selected: _showFullTree,
        onSelected: (_) => _toggleFullTree(),
        selectedColor: colors.primary,
        backgroundColor: colors.surfaceContainerLow,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: _showFullTree ? FontWeight.w600 : FontWeight.normal,
          color: _showFullTree ? Colors.white : colors.onSurface,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ];

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

  Widget _buildSummaryBar(List<Asset> assets) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = assets.length;
    final active = assets.where((a) => a.isActive).length;

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
              Icon(Icons.precision_manufacturing_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                '$total activo(s)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$active operativo(s)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          if (_showFullTree)
            Text(
              'Árbol completo (padres e hijos)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            )
          else
            Text(
              'Mostrando 10 por página',
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

/// Widget que muestra la lista paginada de activos con controles de navegación.
class _PaginatedAssetList extends StatelessWidget {
  const _PaginatedAssetList({
    required this.assets,
    required this.currentPage,
    required this.isHierarchicalView,
    required this.canEdit,
    required this.onAssetTap,
    required this.onEditAsset,
    required this.onPageChanged,
  });

  final List<Asset> assets;
  final int currentPage;
  final bool isHierarchicalView;
  final bool canEdit;
  final void Function(Asset) onAssetTap;
  final void Function(Asset) onEditAsset;
  final void Function(int) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final totalPages = (assets.length / _pageSize).ceil();
    final safePage = currentPage.clamp(0, totalPages - 1 > 0 ? totalPages - 1 : 0);
    final startIndex = safePage * _pageSize;
    final endIndex = (startIndex + _pageSize) < assets.length ? startIndex + _pageSize : assets.length;
    final pageAssets = assets.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pageAssets.length,
            itemBuilder: (context, index) {
              final asset = pageAssets[index];
              return AssetCardWidget(
                asset: asset,
                isHierarchicalView: isHierarchicalView,
                onTap: () => onAssetTap(asset),
                onEdit: asset.isActive && canEdit ? () => onEditAsset(asset) : null,
              );
            },
          ),
        ),
        if (totalPages > 1)
          _PaginationBar(
            currentPage: safePage,
            totalPages: totalPages,
            totalItems: assets.length,
            onPageChanged: onPageChanged,
          ),
      ],
    );
  }
}

/// Barra de paginación con botones Anterior/Siguiente e indicador de página.
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final void Function(int) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final startItem = currentPage * _pageSize + 1;
    final endItem = ((currentPage + 1) * _pageSize) < totalItems
        ? (currentPage + 1) * _pageSize
        : totalItems;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón Anterior
          TextButton.icon(
            onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            label: const Text('Anterior'),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              disabledForegroundColor: colors.onSurface.withValues(alpha: 0.3),
            ),
          ),
          // Indicador de página
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Página ${currentPage + 1} de $totalPages',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$startItem–$endItem de $totalItems activos',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          // Botón Siguiente
          TextButton.icon(
            onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            label: const Text('Siguiente'),
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              disabledForegroundColor: colors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.isSearching,
    required this.selectedPreset,
    required this.onShowAll,
    this.onCreate,
  });

  final bool isSearching;
  final String selectedPreset;
  final VoidCallback onShowAll;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.inventory_2_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'Sin resultados para la búsqueda o filtro aplicado.'
                  : (selectedPreset == 'todo'
                      ? 'No hay activos registrados en esta área.'
                      : 'No hay activos registrados en este periodo.'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Prueba con otros términos de búsqueda o limpia los filtros.'
                  : (selectedPreset == 'todo'
                      ? 'Puedes agregar un nuevo equipo con el botón inferior.'
                      : 'Prueba cambiando el rango de fechas o seleccionando "Todo".'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (selectedPreset != 'todo')
                  OutlinedButton.icon(
                    onPressed: onShowAll,
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Ver todos los activos'),
                  ),
                if (onCreate != null)
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Crear nuevo activo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $message', textAlign: TextAlign.center),
      ),
    );
  }
}
