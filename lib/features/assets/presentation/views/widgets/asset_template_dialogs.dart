import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/features/assets/domain/entities/area.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:macsapractica/features/assets/domain/entities/asset_template.dart';
import 'package:macsapractica/features/assets/domain/usecases/asset_template_usecases.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/area_list_viewmodel.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/asset_template_viewmodel.dart';
import 'area_search_dialog.dart';

/// Diálogo para guardar un árbol de activo como plantilla reutilizable.
class SaveAssetTemplateDialog extends StatefulWidget {
  const SaveAssetTemplateDialog({
    super.key,
    required this.sourceAsset,
  });

  final Asset sourceAsset;

  static Future<bool?> show(
    BuildContext context, {
    required Asset sourceAsset,
  }) {
    return showDialog<bool?>(
      context: context,
      builder: (_) => SaveAssetTemplateDialog(sourceAsset: sourceAsset),
    );
  }

  @override
  State<SaveAssetTemplateDialog> createState() => _SaveAssetTemplateDialogState();
}

class _SaveAssetTemplateDialogState extends State<SaveAssetTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: 'Plantilla - ${widget.sourceAsset.name}',
    );
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AssetTemplateViewModel>();
    final ok = await vm.saveFromAsset(
      sourceAssetCode: widget.sourceAsset.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
    );

    if (mounted) {
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage.isNotEmpty
                ? vm.errorMessage
                : 'Error al guardar la plantilla.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssetTemplateViewModel>();

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.bookmark_add, color: Colors.teal.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Guardar como Plantilla',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width * 0.92, 480.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activo origen: ${widget.sourceAsset.id} (${widget.sourceAsset.name})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Se registrará la estructura jerárquica de este equipo y sus componentes para usarla como molde al crear nuevos equipos idénticos.',
                        style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la plantilla *',
                    hintText: 'Ej: Plantilla Máquina Clasificadora',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bookmark_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre es obligatorio.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Aplicación (opcional)',
                    hintText: 'Detalles sobre para qué equipos o líneas se aplica esta plantilla...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
          onPressed: vm.isLoading ? null : _submit,
          icon: vm.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(vm.isLoading ? 'Guardando...' : 'Guardar Plantilla'),
        ),
      ],
    );
  }
}

/// Diálogo modal con la Biblioteca / Catálogo de Plantillas de Activos.
class AssetTemplateCatalogDialog extends StatefulWidget {
  const AssetTemplateCatalogDialog({
    super.key,
    this.targetAreaId,
  });

  final String? targetAreaId;

  static Future<InstantiateAssetTemplateResult?> show(
    BuildContext context, {
    String? targetAreaId,
  }) {
    return showDialog<InstantiateAssetTemplateResult?>(
      context: context,
      builder: (_) => AssetTemplateCatalogDialog(targetAreaId: targetAreaId),
    );
  }

  @override
  State<AssetTemplateCatalogDialog> createState() => _AssetTemplateCatalogDialogState();
}

class _AssetTemplateCatalogDialogState extends State<AssetTemplateCatalogDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _filter = _searchCtrl.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssetTemplateViewModel>().loadTemplates();
      final areaVm = context.read<AreaListViewModel>();
      if (areaVm.state.areas.isEmpty) {
        areaVm.fetchAreas();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _instantiate(AssetTemplate template) async {
    final result = await showDialog<InstantiateAssetTemplateResult?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InstantiateTemplateFormDialog(
        template: template,
        initialAreaId: widget.targetAreaId,
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _confirmDelete(AssetTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Plantilla'),
        content: Text('¿Seguro que deseas eliminar la plantilla "${template.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context.read<AssetTemplateViewModel>().deleteTemplate(template.id);
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plantilla eliminada correctamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssetTemplateViewModel>();
    final templates = vm.templates.where((t) {
      if (_filter.isEmpty) return true;
      return t.name.toLowerCase().contains(_filter) ||
          (t.description?.toLowerCase().contains(_filter) ?? false) ||
          t.sourceAssetCode.toLowerCase().contains(_filter);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0055A5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_motion, color: Color(0xFF0055A5), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Catálogo de Plantillas de Activos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width * 0.92, 620.0),
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar plantilla por nombre o activo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : templates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _filter.isNotEmpty
                                    ? 'No se encontraron plantillas con ese filtro.'
                                    : 'Aún no hay plantillas registradas.\nGuarda una estructura desde el detalle de cualquier activo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: templates.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final item = templates[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade50,
                                child: Icon(Icons.account_tree_outlined, color: Colors.teal.shade800),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.description != null && item.description!.isNotEmpty) ...[
                                    Text(
                                      item.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${item.totalNodes} componentes',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Molde: ${item.sourceAssetCode}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    tooltip: 'Eliminar plantilla',
                                    onPressed: () => _confirmDelete(item),
                                  ),
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Crear Activo'),
                                    onPressed: () => _instantiate(item),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstantiateTemplateFormDialog extends StatefulWidget {
  const _InstantiateTemplateFormDialog({
    required this.template,
    this.initialAreaId,
  });

  final AssetTemplate template;
  final String? initialAreaId;

  @override
  State<_InstantiateTemplateFormDialog> createState() => _InstantiateTemplateFormDialogState();
}

class _InstantiateTemplateFormDialogState extends State<_InstantiateTemplateFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _observationsCtrl;

  String? _selectedAreaId;
  String? _selectedAreaName;
  bool _copyAttributes = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.name.replaceFirst('Plantilla - ', ''));
    _serialCtrl = TextEditingController();
    _observationsCtrl = TextEditingController();
    _selectedAreaId = widget.initialAreaId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final areaVm = context.read<AreaListViewModel>();
      if (areaVm.state.areas.isNotEmpty) {
        final areas = areaVm.state.areas;
        if (_selectedAreaId != null) {
          final found = areas.where((a) => a.id == _selectedAreaId).firstOrNull;
          if (found != null) {
            setState(() => _selectedAreaName = found.name);
          }
        } else {
          setState(() {
            _selectedAreaId = areas.first.id;
            _selectedAreaName = areas.first.name;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serialCtrl.dispose();
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickArea(List<Area> areas) async {
    final picked = await AreaSearchDialog.show(
      context,
      areas: areas,
      currentAreaId: _selectedAreaId,
    );
    if (picked != null) {
      Area? found;
      for (final a in areas) {
        if (a.id == picked) {
          found = a;
          break;
        }
      }
      final resolved = found;
      if (resolved != null) {
        setState(() {
          _selectedAreaId = resolved.id;
          _selectedAreaName = resolved.name;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreaId == null || _selectedAreaId!.isEmpty) {
      setState(() => _errorMessage = 'Debe seleccionar un área de destino.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final vm = context.read<AssetTemplateViewModel>();
    final result = await vm.instantiate(
      templateId: widget.template.id,
      targetAreaId: _selectedAreaId!,
      newRootName: _nameCtrl.text.trim(),
      newSerial: _serialCtrl.text.trim(),
      observations: _observationsCtrl.text.trim(),
      copyAttributes: _copyAttributes,
    );

    if (mounted) {
      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = vm.errorMessage.isNotEmpty
              ? vm.errorMessage
              : 'Error al instanciar la plantilla.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final areaVm = context.watch<AreaListViewModel>();
    final areas = areaVm.state.areas;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_business, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Crear Equipo desde Plantilla',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.template.name,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width * 0.92, 500.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Se generarán ${widget.template.totalNodes} componentes jerárquicos automáticamente en el área seleccionada.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de Área
                Text(
                  'Área Destino *',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _isProcessing ? null : () => _pickArea(areas),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF0055A5)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedAreaId != null
                                ? '$_selectedAreaId - ${_selectedAreaName ?? ""}'
                                : 'Seleccione área destino...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedAreaId != null ? FontWeight.w600 : FontWeight.normal,
                              color: _selectedAreaId != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nombre equipo raíz
                TextFormField(
                  controller: _nameCtrl,
                  enabled: !_isProcessing,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del equipo raíz *',
                    hintText: 'Ej: Clasificadora 3',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre del activo raíz es obligatorio.'
                      : null,
                ),
                const SizedBox(height: 16),

                // Serie
                TextFormField(
                  controller: _serialCtrl,
                  enabled: !_isProcessing,
                  decoration: const InputDecoration(
                    labelText: 'N° de Serie nuevo equipo (opcional)',
                    hintText: 'Dejar vacío si aún no se tiene la serie',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
                const SizedBox(height: 16),

                // Observaciones
                TextFormField(
                  controller: _observationsCtrl,
                  enabled: !_isProcessing,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    hintText: 'Notas de instalación o condiciones...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Switch Atributos técnicos
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _copyAttributes,
                  onChanged: _isProcessing ? null : (val) => setState(() => _copyAttributes = val),
                  title: const Text(
                    '¿Copiar atributos técnicos predefinidos?',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Traspasa los valores y unidades de medida registradas en la plantilla a todos los componentes.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: Colors.red.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0055A5)),
          onPressed: _isProcessing ? null : _submit,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(_isProcessing ? 'Creando...' : 'Crear Estructura'),
        ),
      ],
    );
  }
}
