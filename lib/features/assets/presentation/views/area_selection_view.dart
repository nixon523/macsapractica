import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/app/router/app_router.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/area.dart';
import '../states/area_state.dart';
import '../viewmodels/area_list_viewmodel.dart';

/// Vista de selección de área: lista limpia y directa de áreas.
class AreaSelectionView extends StatefulWidget {
  const AreaSelectionView({super.key});

  @override
  State<AreaSelectionView> createState() => _AreaSelectionViewState();
}

class _AreaSelectionViewState extends State<AreaSelectionView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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
        context.read<AreaListViewModel>().fetchAreas();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createArea() async {
    final result = await Navigator.of(context).pushNamed(AppRouter.areaCreate);
    if (result == true && mounted) {
      context.read<AreaListViewModel>().fetchAreas(forceRefresh: true);
    }
  }

  Future<void> _editAreaName(Area area) async {
    final nameCtrl = TextEditingController(text: area.name);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Área ${area.id}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del Área / Centro de Costo',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context
          .read<AreaListViewModel>()
          .updateAreaName(area.id, nameCtrl.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Nombre de área actualizado correctamente.'
                  : 'Error al actualizar el nombre del área.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        context.watch<AuthViewModel>().hasPermission('asset.create');

    return Scaffold(
      body: Consumer<AreaListViewModel>(
        builder: (context, viewModel, child) {
          final state = viewModel.state;
          return switch (state.viewState) {
            ViewState.loading =>
              const Center(child: CircularProgressIndicator()),
            ViewState.error => Center(child: Text('Error: ${state.errorMessage}')),
            ViewState.success => state.areas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Aún no hay áreas registradas.'),
                        if (canManage) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _createArea,
                            child: const Text('Crear primera área'),
                          ),
                        ],
                      ],
                    ),
                  )
                : _AreaListView(
                    areas: state.areas,
                    searchQuery: _searchQuery,
                    searchCtrl: _searchCtrl,
                    canManage: canManage,
                    onEditArea: _editAreaName,
                    onCreateArea: canManage ? _createArea : null,
                  ),
            ViewState.initial => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _AreaListView extends StatelessWidget {
  const _AreaListView({
    required this.areas,
    required this.searchQuery,
    required this.searchCtrl,
    required this.canManage,
    required this.onEditArea,
    this.onCreateArea,
  });

  final List<Area> areas;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool canManage;
  final Function(Area) onEditArea;
  final VoidCallback? onCreateArea;

  @override
  Widget build(BuildContext context) {
    final filteredAreas = areas.where((area) {
      if (searchQuery.isEmpty) return true;
      final matchName = area.name.toLowerCase().contains(searchQuery);
      final matchId = area.id.toLowerCase().contains(searchQuery);
      final matchCc = area.costCenter.toLowerCase().contains(searchQuery);
      return matchName || matchId || matchCc;
    }).toList();

    return Column(
      children: [
        // Barra de Búsqueda y Crear
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, código (A001) o ID...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => searchCtrl.clear(),
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
                ),
              ),
              if (canManage && onCreateArea != null) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onCreateArea,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Crear Área'),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1),

        // Lista de Áreas
        Expanded(
          child: filteredAreas.isEmpty
              ? const Center(
                  child: Text('No se encontraron áreas.'),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    context.read<AreaListViewModel>().fetchAreas(forceRefresh: true);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredAreas.length,
                    itemBuilder: (context, index) {
                      final area = filteredAreas[index];
                      final ccStr = area.costCenter.startsWith('CC-')
                          ? area.costCenter
                          : (area.costCenter.startsWith('CC')
                              ? area.costCenter
                              : 'CC-${area.costCenter}');

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.factory_outlined, size: 18),
                          ),
                          title: Text(
                            'Área ${area.id}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text('${area.name} · Centro de costo: $ccStr'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canManage)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Editar nombre',
                                  onPressed: () => onEditArea(area),
                                ),
                              const Icon(Icons.arrow_forward_ios, size: 14),
                            ],
                          ),
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRouter.assets,
                            arguments: area.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
