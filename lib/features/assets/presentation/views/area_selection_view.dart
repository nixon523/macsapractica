import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/app/router/app_router.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/area.dart';
import '../states/area_state.dart';
import '../viewmodels/area_list_viewmodel.dart';

/// Vista de selección de área con estándar visual y profesional del Kardex.
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
    final canManage = context.watch<AuthViewModel>().hasPermission('asset.create');

    return Scaffold(
      body: Consumer<AreaListViewModel>(
        builder: (context, viewModel, child) {
          final state = viewModel.state;
          return switch (state.viewState) {
            ViewState.loading => const Center(child: CircularProgressIndicator()),
            ViewState.error => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 12),
                      Text('Error al cargar áreas', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(state.errorMessage, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.read<AreaListViewModel>().fetchAreas(forceRefresh: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ViewState.success => state.areas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.factory_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          const Text(
                            'Aún no hay áreas registradas.',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Crea un área para comenzar a registrar equipos y activos.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if (canManage) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _createArea,
                              icon: const Icon(Icons.add),
                              label: const Text('Crear primera área'),
                            ),
                          ],
                        ],
                      ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final filteredAreas = areas.where((area) {
      if (searchQuery.isEmpty) return true;
      final matchName = area.name.toLowerCase().contains(searchQuery);
      final matchId = area.id.toLowerCase().contains(searchQuery);
      final matchCc = area.costCenter.toLowerCase().contains(searchQuery);
      return matchName || matchId || matchCc;
    }).toList();

    return Column(
      children: [
        // Barra de Control Responsiva
        Container(
          color: colors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar área por nombre, código (A001) o centro de costo…',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => searchCtrl.clear(),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: colors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                ),
              ),
              if (canManage && onCreateArea != null) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onCreateArea,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva Área'),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1),

        // Barra Métrica de Resumen
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Row(
            children: [
              Icon(Icons.business_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                '${filteredAreas.length} área(s) disponible(s)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'Selecciona un área para ver sus activos',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Lista de Áreas Ejecutivas
        Expanded(
          child: filteredAreas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: colors.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron áreas con "$searchQuery"',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => searchCtrl.clear(),
                          child: const Text('Limpiar búsqueda'),
                        ),
                      ],
                    ),
                  ),
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

                      return _ModernAreaCard(
                        area: area,
                        costCenterFormatted: ccStr,
                        canManage: canManage,
                        onEdit: () => onEditArea(area),
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRouter.assets,
                          arguments: area.id,
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

/// Tarjeta moderna de área con franja lateral y estética de Kardex.
class _ModernAreaCard extends StatelessWidget {
  const _ModernAreaCard({
    required this.area,
    required this.costCenterFormatted,
    required this.canManage,
    required this.onEdit,
    required this.onTap,
  });

  final Area area;
  final String costCenterFormatted;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accentColor = Color(0xFF0284C7); // Azul cyan industrial

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Franja lateral con acento de color de área
              Container(
                width: 5,
                color: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.factory_outlined, size: 20, color: accentColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Text(
                                    'Área ${area.id}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    costCenterFormatted,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              area.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (canManage)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar nombre del área',
                          onPressed: onEdit,
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
