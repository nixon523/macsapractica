import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/app/di/get_it.dart';
import 'package:macsapractica/features/assets/domain/entities/area.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:macsapractica/features/assets/domain/usecases/clone_asset_tree_usecase.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/area_list_viewmodel.dart';
import 'area_search_dialog.dart';

/// Modal dialog for cloning an asset and its entire subtree to a target area.
class CloneAssetTreeDialog extends StatefulWidget {
  const CloneAssetTreeDialog({
    super.key,
    required this.sourceAsset,
  });

  final Asset sourceAsset;

  static Future<CloneAssetTreeResult?> show(
    BuildContext context, {
    required Asset sourceAsset,
  }) {
    return showDialog<CloneAssetTreeResult?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloneAssetTreeDialog(sourceAsset: sourceAsset),
    );
  }

  @override
  State<CloneAssetTreeDialog> createState() => _CloneAssetTreeDialogState();
}

class _CloneAssetTreeDialogState extends State<CloneAssetTreeDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _observationsCtrl;

  String? _selectedAreaId;
  String? _selectedAreaName;
  bool _copyAttributes = true;
  bool _isCloning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: '${widget.sourceAsset.name} (Copia)');
    _serialCtrl = TextEditingController();
    _observationsCtrl = TextEditingController(
      text: widget.sourceAsset.observations ?? '',
    );
    _selectedAreaId = widget.sourceAsset.areaId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final areaVm = context.read<AreaListViewModel>();
      if (areaVm.state.areas.isEmpty) {
        areaVm.fetchAreas();
      } else {
        Area? currentArea;
        for (final a in areaVm.state.areas) {
          if (a.id == widget.sourceAsset.areaId) {
            currentArea = a;
            break;
          }
        }
        final resolvedArea = currentArea ?? (areaVm.state.areas.isNotEmpty ? areaVm.state.areas.first : null);
        if (resolvedArea != null) {
          setState(() {
            _selectedAreaName = resolvedArea.name;
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
      _isCloning = true;
      _errorMessage = null;
    });

    try {
      final cloneUseCase = getIt<CloneAssetTreeUseCase>();
      final result = await cloneUseCase(CloneAssetTreeParams(
        sourceAssetCode: widget.sourceAsset.id,
        targetAreaId: _selectedAreaId!,
        newRootName: _nameCtrl.text.trim(),
        newSerial: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        observations: _observationsCtrl.text.trim().isEmpty ? null : _observationsCtrl.text.trim(),
        copyAttributes: _copyAttributes,
      ));

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCloning = false;
          _errorMessage = e.toString();
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
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.copy_all, color: Colors.indigo.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Duplicar Estructura de Activo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width * 0.92, 520.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Origen: ${widget.sourceAsset.id} - ${widget.sourceAsset.name}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Se duplicará el equipo raíz junto con todos sus sub-equipos y partes de forma jerárquica con nuevos correlativos automáticos.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Las imágenes NO se clonarán (los nuevos componentes iniciarán sin foto).\n• Los números de serie en subcomponentes se reiniciarán.',
                        style: TextStyle(fontSize: 11.5, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de Área Destino
                Text(
                  'Área de Destino *',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _isCloning ? null : () => _pickArea(areas),
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
                                ? '$_selectedAreaId - ${_selectedAreaName ?? widget.sourceAsset.areaId}'
                                : 'Seleccione área de destino...',
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

                // Nombre del nuevo activo raíz
                TextFormField(
                  controller: _nameCtrl,
                  enabled: !_isCloning,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del nuevo equipo raíz *',
                    hintText: 'Ej: Clasificadora 2',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre del activo raíz es obligatorio.'
                      : null,
                ),
                const SizedBox(height: 16),

                // Serie opcional
                TextFormField(
                  controller: _serialCtrl,
                  enabled: !_isCloning,
                  decoration: const InputDecoration(
                    labelText: 'N° de Serie nuevo equipo raíz (opcional)',
                    hintText: 'Dejar vacío si no se conoce la serie aún',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
                const SizedBox(height: 16),

                // Observaciones
                TextFormField(
                  controller: _observationsCtrl,
                  enabled: !_isCloning,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    hintText: 'Notas sobre la clonación o condiciones del equipo...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Switch para copiar atributos técnicos
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _copyAttributes,
                  onChanged: _isCloning ? null : (val) => setState(() => _copyAttributes = val),
                  title: const Text(
                    '¿Copiar atributos técnicos en los componentes?',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Traspasa los valores y unidades de medida (potencia, voltaje, caudal, etc.) a todos los componentes clonados.',
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
          onPressed: _isCloning ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo.shade700,
          ),
          onPressed: _isCloning ? null : _submit,
          icon: _isCloning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.copy_all, size: 18),
          label: Text(_isCloning ? 'Duplicando...' : 'Duplicar Estructura'),
        ),
      ],
    );
  }
}
