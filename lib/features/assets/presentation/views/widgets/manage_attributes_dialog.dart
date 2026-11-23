import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macsapractica/app/widgets/app_dialog.dart';
import 'package:macsapractica/features/assets/domain/entities/asset_attribute_definition.dart';
import 'package:macsapractica/features/assets/domain/entities/brand.dart';
import 'package:macsapractica/features/assets/domain/entities/unit_of_measure.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/attribute_catalog_viewmodel.dart';

class ManageAttributesDialog extends StatefulWidget {
  const ManageAttributesDialog({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManageAttributesDialog(initialTabIndex: initialTabIndex),
    );
  }

  @override
  State<ManageAttributesDialog> createState() => _ManageAttributesDialogState();
}

class _ManageAttributesDialogState extends State<ManageAttributesDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchAttrCtrl = TextEditingController();
  final TextEditingController _searchUnitCtrl = TextEditingController();
  final TextEditingController _searchBrandCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttributeCatalogViewModel>().loadAll(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchAttrCtrl.dispose();
    _searchUnitCtrl.dispose();
    _searchBrandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AttributeCatalogViewModel>();
    final theme = Theme.of(context);
    final width = responsiveDialogWidth(context, 620);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Catálogo de Atributos, Unidades y Marcas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            isScrollable: false,
            tabs: const [
              Tab(icon: Icon(Icons.label_outline, size: 18), text: 'Atributos'),
              Tab(icon: Icon(Icons.straighten, size: 18), text: 'Unidades'),
              Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Marcas'),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        height: 440,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAttributesTab(vm),
            _buildUnitsTab(vm),
            _buildBrandsTab(vm),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Tab 1: Atributos Técnicos
  // --------------------------------------------------------------------------
  Widget _buildAttributesTab(AttributeCatalogViewModel vm) {
    final query = _searchAttrCtrl.text.trim().toLowerCase();
    final filtered = vm.attributes.where((a) {
      if (query.isEmpty) return true;
      return a.name.toLowerCase().contains(query) ||
          (a.description != null && a.description!.toLowerCase().contains(query)) ||
          (a.defaultUnitCode != null && a.defaultUnitCode!.toLowerCase().contains(query));
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchAttrCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar atributo...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchAttrCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchAttrCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _openAttributeForm(null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (vm.isLoading && vm.attributes.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                query.isEmpty
                    ? 'No hay atributos técnicos registrados.'
                    : 'No se encontraron atributos para "$query".',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final attr = filtered[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.settings_input_component,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    attr.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    [
                      if (attr.defaultUnitCode != null && attr.defaultUnitCode!.isNotEmpty)
                        'Unidad sugerida: ${attr.defaultUnitCode}',
                      if (attr.description != null && attr.description!.isNotEmpty)
                        attr.description!,
                    ].join(' • '),
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Editar atributo',
                        onPressed: () => _openAttributeForm(attr),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Eliminar del catálogo',
                        onPressed: () => _confirmDeleteAttribute(attr),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Tab 2: Unidades de Medida
  // --------------------------------------------------------------------------
  Widget _buildUnitsTab(AttributeCatalogViewModel vm) {
    final query = _searchUnitCtrl.text.trim().toLowerCase();
    final filtered = vm.units.where((u) {
      if (query.isEmpty) return true;
      return u.code.toLowerCase().contains(query) || u.name.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchUnitCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar unidad (ej: kW, PSI, °C)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchUnitCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchUnitCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _openUnitForm(null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (vm.isLoading && vm.units.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                query.isEmpty
                    ? 'No hay unidades de medida registradas.'
                    : 'No se encontraron unidades para "$query".',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final unit = filtered[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 48,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      unit.code,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  title: Text(
                    unit.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Editar unidad',
                        onPressed: () => _openUnitForm(unit),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Eliminar unidad',
                        onPressed: () => _confirmDeleteUnit(unit),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Diálogos de Gestión
  // --------------------------------------------------------------------------
  Future<void> _openAttributeForm(AssetAttributeDefinition? attr) async {
    final vm = context.read<AttributeCatalogViewModel>();
    final nameCtrl = TextEditingController(text: attr?.name ?? '');
    final descCtrl = TextEditingController(text: attr?.description ?? '');
    int? selectedUnitId = attr?.defaultUnitId;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(attr == null ? 'Nuevo Atributo Técnico' : 'Editar Atributo Técnico'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Atributo *',
                      hintText: 'Ej: Potencia, Voltaje, Presión...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Detalles o especificaciones...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedUnitId,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de Medida por Defecto',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('(Sin unidad por defecto)'),
                      ),
                      for (final u in vm.units)
                        DropdownMenuItem<int?>(
                          value: u.id,
                          child: Text('${u.code} - ${u.name}'),
                        ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedUnitId = val;
                      });
                    },
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
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final ok = await vm.saveAttribute(
        id: attr?.id,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        defaultUnitId: selectedUnitId,
      );
      if (!ok && mounted && vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteAttribute(AssetAttributeDefinition attr) async {
    final vm = context.read<AttributeCatalogViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Atributo del Catálogo'),
        content: Text(
          '¿Deseas retirar "${attr.name}" del catálogo?\n\n'
          'Los activos que ya tengan este atributo registrado conservarán sus datos sin alterarse, '
          'pero ya no se ofrecerá para nuevos registros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await vm.deleteAttribute(attr.id);
      if (!ok && mounted && vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openUnitForm(UnitOfMeasure? unit) async {
    final vm = context.read<AttributeCatalogViewModel>();
    final codeCtrl = TextEditingController(text: unit?.code ?? '');
    final nameCtrl = TextEditingController(text: unit?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(unit == null ? 'Nueva Unidad de Medida' : 'Editar Unidad de Medida'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Símbolo / Código *',
                  hintText: 'Ej: kW, PSI, °C, RPM...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El símbolo es obligatorio.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo *',
                  hintText: 'Ej: Kilovatios, Libras por pulgada...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final ok = await vm.saveUnit(
        id: unit?.id,
        code: codeCtrl.text.trim(),
        name: nameCtrl.text.trim(),
      );
      if (!ok && mounted && vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteUnit(UnitOfMeasure unit) async {
    final vm = context.read<AttributeCatalogViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Unidad de Medida'),
        content: Text(
          '¿Deseas retirar "${unit.code} (${unit.name})" del catálogo?\n\n'
          'Por integridad referencial, si está vinculada a atributos del catálogo, '
          'se desactivará de forma segura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await vm.deleteUnit(unit.id);
      if (!ok && mounted && vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // Tab 3: Marcas de Activos
  // --------------------------------------------------------------------------
  Widget _buildBrandsTab(AttributeCatalogViewModel vm) {
    final query = _searchBrandCtrl.text.trim().toLowerCase();
    final filtered = vm.brands.where((b) {
      if (query.isEmpty) return true;
      return b.name.toLowerCase().contains(query) ||
          (b.description != null && b.description!.toLowerCase().contains(query));
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchBrandCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar marca...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchBrandCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchBrandCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _openBrandForm(null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (vm.isLoading && vm.brands.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                query.isEmpty
                    ? 'No hay marcas registradas en el catálogo.'
                    : 'No se encontraron marcas para "$query".',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final brand = filtered[index];
                final subtitleParts = <String>[];
                if (brand.description != null && brand.description!.isNotEmpty) {
                  subtitleParts.add(brand.description!);
                }
                if (brand.totalAssetsAssociated > 0) {
                  subtitleParts.add('${brand.totalAssetsAssociated} activos');
                }

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.teal.shade50,
                    child: Icon(Icons.verified, size: 16, color: Colors.teal.shade700),
                  ),
                  title: Text(
                    brand.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  subtitle: subtitleParts.isNotEmpty
                      ? Text(
                          subtitleParts.join(' • '),
                          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Editar marca',
                        onPressed: () => _openBrandForm(brand),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Eliminar del catálogo',
                        onPressed: () => _confirmDeleteBrand(brand),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openBrandForm(Brand? brand) async {
    final vm = context.read<AttributeCatalogViewModel>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: brand?.name ?? '');
    final descCtrl = TextEditingController(text: brand?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(brand == null ? 'Nueva Marca' : 'Editar Marca'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Marca *',
                  hintText: 'Ej: Siemens, ABB, Danfoss, Caterpillar...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Fabricante (opcional)',
                  hintText: 'Ej: Motores eléctricos y variadores de frecuencia',
                  border: OutlineInputBorder(),
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final ok = await vm.saveBrand(
        id: brand?.id,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
      if (!ok && mounted && vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteBrand(Brand brand) async {
    final vm = context.read<AttributeCatalogViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Marca'),
        content: Text(
          '¿Deseas retirar "${brand.name}" del catálogo?\n\n'
          '${brand.totalAssetsAssociated > 0 ? "Esta marca está vinculada a ${brand.totalAssetsAssociated} activo(s). Por integridad referencial, se desactivará del catálogo para que no aparezca en nuevas selecciones, pero se conservará en los activos existentes." : "La marca no tiene activos asociados y se eliminará permanentemente."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await vm.deleteBrand(brand.id);
      if (!ok && mounted && vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }
}
