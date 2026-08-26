import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../domain/entities/asset.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../states/asset_state.dart';
import '../viewmodels/asset_list_viewmodel.dart';
import 'asset_create_view.dart';
import 'asset_detail_view.dart';
import 'asset_edit_view.dart';
import 'widgets/asset_card_widget.dart';

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

  @override
  void initState() {
    super.initState();
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
      _runSearch();
    } else {
      _viewModel.fetchAssets(widget.areaId);
    }
  }

  bool get _isSearchActive =>
      _searchCtrl.text.trim().isNotEmpty || _statusFilter != null || _showFullTree;

  void _refresh({bool forceRefresh = false}) {
    if (_isSearchActive) {
      _runSearch();
    } else {
      _viewModel.fetchAssets(widget.areaId, forceRefresh: forceRefresh);
    }
  }

  void _runSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
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
    });
    _loadInitial();
  }

  void _handleFilterOrQueryChange() {
    if (_searchCtrl.text.trim().isEmpty && _statusFilter == null && !_showFullTree) {
      _clearSearch();
    } else {
      _runSearch();
    }
  }

  void _toggleFullTree() {
    setState(() {
      _showFullTree = !_showFullTree;
    });
    _refresh(forceRefresh: true);
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
        floatingActionButton: !_isSearchActive && canCreate
            ? FloatingActionButton(
                tooltip: 'Crear equipo',
                onPressed: _createChild,
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          children: [
            _SearchBar(
              controller: _searchCtrl,
              statusFilter: _statusFilter,
              onQueryChanged: (_) => _handleFilterOrQueryChange(),
              onStatusChanged: (status) {
                setState(() => _statusFilter = status);
                _handleFilterOrQueryChange();
              },
              onClear: _clearSearch,
            ),
            if (_isSearchActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Row(
                  children: [
                    Icon(
                      _showFullTree && _searchCtrl.text.isEmpty && _statusFilter == null
                          ? Icons.account_tree
                          : Icons.manage_search,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Consumer<AssetListViewModel>(
                        builder: (context, viewModel, _) {
                          final count = viewModel.state.assets.length;
                          final label = _showFullTree && _searchCtrl.text.isEmpty && _statusFilter == null
                              ? 'Árbol completo: $count activo(s) (padres e hijos)'
                              : 'Resultados filtrados: $count activo(s)';
                          return Text(
                            label,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          );
                        },
                      ),
                    ),
                    InkWell(
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Limpiar filtro',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Consumer<AssetListViewModel>(
                builder: (context, viewModel, child) {
                  final state = viewModel.state;
                  return switch (state.viewState) {
                    ViewState.loading =>
                      const Center(child: CircularProgressIndicator()),
                    ViewState.error => _ErrorView(message: state.errorMessage),
                    ViewState.success => state.assets.isEmpty
                        ? _EmptyView(
                            isSearching: _isSearchActive,
                            onCreate:
                                !_isSearchActive && canCreate ? _createChild : null,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: state.assets.length,
                            itemBuilder: (context, index) {
                              final asset = state.assets[index];
                              return AssetCardWidget(
                                asset: asset,
                                isHierarchicalView: _isSearchActive || _showFullTree,
                                onTap: () => _onAssetTap(asset),
                                onEdit: asset.isActive && canEdit
                                    ? () => _editAsset(asset)
                                    : null,
                              );
                            },
                          ),
                    ViewState.initial => const SizedBox.shrink(),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final AssetStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AssetStatus?> onStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      controller: controller,
      onChanged: onQueryChanged,
      decoration: InputDecoration(
        hintText: 'Buscar por N° de serie, nombre, ID, marca...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            );
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
      ),
    );

    final statusDropdown = DropdownButtonHideUnderline(
      child: DropdownButton<AssetStatus?>(
        value: statusFilter,
        isExpanded: true,
        hint: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list),
            SizedBox(width: 6),
            Text('Estado'),
          ],
        ),
        items: const [
          DropdownMenuItem<AssetStatus?>(
            value: null,
            child: Text('Todos los estados'),
          ),
          DropdownMenuItem<AssetStatus?>(
            value: AssetStatus.active,
            child: Text('Activos'),
          ),
          DropdownMenuItem<AssetStatus?>(
            value: AssetStatus.transferredDeactivated,
            child: Text('Transferidos'),
          ),
          DropdownMenuItem<AssetStatus?>(
            value: AssetStatus.inactive,
            child: Text('Inactivos'),
          ),
        ],
        onChanged: onStatusChanged,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En pantallas estrechas apila la búsqueda y el filtro
          // para que ambos sean cómodos de usar.
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 8),
                statusDropdown,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 8),
              SizedBox(width: 190, child: statusDropdown),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.isSearching, this.onCreate});

  final bool isSearching;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.inventory_2_outlined,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? 'Sin resultados para la búsqueda o filtro aplicado.'
                  : 'No hay activos registrados en esta categoría.',
            ),
            if (onCreate != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onCreate,
                child: const Text('Crear activo'),
              ),
            ],
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
