import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/upper_case_formatter.dart';
import 'package:macsapractica/app/router/app_router.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/area.dart';
import '../reports/asset_report_filter_dialog.dart';
import '../states/area_state.dart';
import '../viewmodels/area_list_viewmodel.dart';

/// Vista de selección y gestión CRUD de áreas con paginación de 10 registros.
class AreaSelectionView extends StatefulWidget {
  const AreaSelectionView({super.key});

  @override
  State<AreaSelectionView> createState() => _AreaSelectionViewState();
}

class _AreaSelectionViewState extends State<AreaSelectionView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _currentPage = 0; // Reset a primera página al buscar
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

  Future<void> _editArea(Area area) async {
    final nameCtrl = TextEditingController(text: area.name);
    final ccCtrl = TextEditingController(text: area.costCenter);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_note, color: Color(0xFF0284C7), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Editar Área: ${area.id}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Modifica los datos del área. Todo cambio quedará registrado en el Kardex.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Nombre del Área / Centro de Costo *',
                    hintText: 'Ej: ALMACEN GENERAL',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: ccCtrl,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Centro de Costo (CC) *',
                    hintText: 'Ej: CC-50',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'El centro de costo es obligatorio.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final formattedName = nameCtrl.text.trim().toUpperCase();
      final formattedCC = ccCtrl.text.trim().toUpperCase();
      final ok = await context.read<AreaListViewModel>().updateArea(
            id: area.id,
            name: formattedName,
            costCenter: formattedCC,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Área ${area.id} actualizada correctamente.'
                  : 'Error al actualizar el área: ${context.read<AreaListViewModel>().state.errorMessage}',
            ),
            backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteArea(Area area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Eliminar Área: ${area.id}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas dar de baja o eliminar el área "${area.name}" (${area.id})?',
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Integridad: El sistema verificará que el área no contenga activos activos, planes preventivos u órdenes de trabajo en curso antes de proceder.',
                        style: TextStyle(fontSize: 11.5, color: Colors.brown.shade800, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Eliminación'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context.read<AreaListViewModel>().deleteArea(area.id);

      if (mounted) {
        final error = context.read<AreaListViewModel>().state.errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Área ${area.id} eliminada exitosamente.'
                  : (error.isNotEmpty ? error : 'No se pudo eliminar el área.'),
            ),
            backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
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
                : _AreaPaginatedListView(
                    areas: state.areas,
                    searchQuery: _searchQuery,
                    searchCtrl: _searchCtrl,
                    canManage: canManage,
                    currentPage: _currentPage,
                    pageSize: _pageSize,
                    onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                    onEditArea: _editArea,
                    onDeleteArea: _deleteArea,
                    onCreateArea: canManage ? _createArea : null,
                  ),
            ViewState.initial => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _AreaPaginatedListView extends StatelessWidget {
  const _AreaPaginatedListView({
    required this.areas,
    required this.searchQuery,
    required this.searchCtrl,
    required this.canManage,
    required this.currentPage,
    required this.pageSize,
    required this.onPageChanged,
    required this.onEditArea,
    required this.onDeleteArea,
    this.onCreateArea,
  });

  final List<Area> areas;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool canManage;
  final int currentPage;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final Function(Area) onEditArea;
  final Function(Area) onDeleteArea;
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

    final totalItems = filteredAreas.length;
    final totalPages = totalItems > 0 ? (totalItems / pageSize).ceil() : 1;
    final validPage = currentPage.clamp(0, totalPages - 1);
    final startIndex = validPage * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalItems);
    final pageAreas = totalItems > 0 ? filteredAreas.sublist(startIndex, endIndex) : <Area>[];

    return Column(
      children: [
        // Barra Superior de Control
        Container(
          color: colors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;
              final searchField = TextField(
                controller: searchCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: InputDecoration(
                  hintText: isCompact
                      ? 'BUSCAR ÁREA (NOMBRE, A001, CC)…'
                      : 'BUSCAR ÁREA POR NOMBRE, CÓDIGO (A001) O CENTRO DE COSTO…',
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
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: () => AssetReportFilterDialog.showMultiAreaReport(context),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: Text(isCompact ? 'Reportes' : 'Reportes de Activos (PDF / Excel)'),
                  ),
                  if (canManage && onCreateArea != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onPressed: onCreateArea,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva Área'),
                    ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    actionButtons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  actionButtons,
                ],
              );
            },
          ),
        ),

        const Divider(height: 1),

        // Barra Métrica de Resumen y Paginación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Row(
            children: [
              Icon(Icons.business_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                '$totalItems área(s) disponible(s)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              if (totalItems > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '• Mostrando ${startIndex + 1}-$endIndex de $totalItems',
                  style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              Text(
                'Página ${validPage + 1} de $totalPages',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),

        // Lista de 10 Áreas por Página
        Expanded(
          child: pageAreas.isEmpty
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
                    itemCount: pageAreas.length,
                    itemBuilder: (context, index) {
                      final area = pageAreas[index];
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
                        onDelete: () => onDeleteArea(area),
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRouter.assets,
                          arguments: area.id,
                        ),
                      );
                    },
                  ),
                ),
        ),

        // Barra Inferior de Paginación (10 registros)
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                // Botón Anterior
                OutlinedButton(
                  onPressed: validPage > 0 ? () => onPageChanged(validPage - 1) : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, size: 18),
                      SizedBox(width: 2),
                      Text('Ant.', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Selector Numérico de Páginas
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(totalPages, (idx) {
                          final isSelected = idx == validPage;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => onPageChanged(idx),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? colors.primary : colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? colors.primary : colors.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? colors.onPrimary : colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Botón Siguiente
                OutlinedButton(
                  onPressed: validPage < totalPages - 1 ? () => onPageChanged(validPage + 1) : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Sig.', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tarjeta moderna de área con franja lateral, badges y acciones CRUD.
class _ModernAreaCard extends StatelessWidget {
  const _ModernAreaCard({
    required this.area,
    required this.costCenterFormatted,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  final Area area;
  final String costCenterFormatted;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accentColor = Color(0xFF0284C7);

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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    'Área ${area.id}',
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
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    costCenterFormatted,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0369A1),
                                    ),
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
                      IconButton(
                        icon: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF0369A1)),
                        tooltip: 'Reporte e inventario de esta área (PDF / Excel)',
                        onPressed: () => AssetReportFilterDialog.showAreaReport(
                          context,
                          areaId: area.id,
                          areaName: area.name,
                        ),
                      ),
                      if (canManage) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar nombre y centro de costo',
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                          tooltip: 'Eliminar área',
                          onPressed: onDelete,
                        ),
                      ],
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
