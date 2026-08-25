import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../domain/entities/area.dart';
import '../../domain/entities/asset.dart';
import '../../domain/usecases/get_next_asset_id_usecase.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../states/area_state.dart';
import '../viewmodels/area_list_viewmodel.dart';
import '../viewmodels/asset_transfer_viewmodel.dart';

class AssetTransferView extends StatefulWidget {
  const AssetTransferView({super.key, required this.asset});

  final Asset asset;

  @override
  State<AssetTransferView> createState() => _AssetTransferViewState();
}

class _AssetTransferViewState extends State<AssetTransferView> {
  final _transferViewModel = getIt<AssetTransferViewModel>();
  final _getNextAssetId = getIt<GetNextAssetIdUseCase>();

  Area? _targetArea;
  String? _previewId;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _transferViewModel.reset();
  }

  Future<void> _loadPreview(String areaId) async {
    setState(() {
      _previewing = true;
      _previewId = null;
    });
    try {
      final id = await _getNextAssetId(
        GetNextAssetIdParams(areaId: areaId),
      );
      if (mounted) {
        setState(() => _previewId = id);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _previewId = null);
      }
    } finally {
      if (mounted) {
        setState(() => _previewing = false);
      }
    }
  }

  Future<void> _confirmTransfer() async {
    final user = context.read<AuthViewModel>().currentUser;
    final area = _targetArea;
    final previewId = _previewId;
    if (user == null || area == null || previewId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar transferencia'),
        content: Text(
          'Se copiará la jerarquía completa del equipo ${widget.asset.id} '
          'al área ${area.id} ($previewId).\n\n'
          'El equipo original quedará deshabilitado y registrado en el kardex. '
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await _transferViewModel.transfer(
      sourceAsset: widget.asset,
      targetAreaId: area.id,
      newAssetId: previewId,
      userId: user.userId,
      userName: user.username,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipo transferido correctamente.')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${_transferViewModel.errorMessage}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final areaState = context.watch<AreaListViewModel>().state;
    final transferVm = context.watch<AssetTransferViewModel>();
    final eligibleAreas = areaState.viewState == ViewState.success
        ? areaState.areas.where((a) => a.id != asset.areaId).toList()
        : const <Area>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Transferir equipo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.precision_manufacturing_outlined),
              title: Text('${asset.id} - ${asset.name}'),
              subtitle: Text(
                'Área actual: ${asset.areaId} · Nivel: ${asset.level.name}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Área de destino', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          switch (areaState.viewState) {
            ViewState.loading || ViewState.initial =>
              const Center(child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              )),
            ViewState.error => Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text('No se pudieron cargar las áreas'),
                  subtitle: Text(areaState.errorMessage),
                  trailing: TextButton(
                    onPressed: () =>
                        context.read<AreaListViewModel>().fetchAreas(),
                    child: const Text('Reintentar'),
                  ),
                ),
              ),
            ViewState.success => eligibleAreas.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay otras áreas disponibles.'),
                    ),
                  )
                : DropdownButtonFormField<Area>(
                    initialValue: _targetArea,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Selecciona un área',
                    ),
                    items: [
                      for (final area in eligibleAreas)
                        DropdownMenuItem(
                          value: area,
                          child: Text('${area.id} - ${area.name}'),
                        ),
                    ],
                    onChanged: (area) {
                      setState(() => _targetArea = area);
                      if (area != null) _loadPreview(area.id);
                    },
                  ),
          },
          const SizedBox(height: 16),
          if (_targetArea != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.preview_outlined),
                title: const Text('Nuevo ID de la jerarquía'),
                subtitle: Text(
                  _previewing
                      ? 'Calculando…'
                      : (_previewId ?? 'No disponible'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Al transferir se copia el equipo completo con su sub-equipos, '
                  'partes y sub-partes (nuevos IDs relacionales). El equipo '
                  'original se deshabilita pero permanece como registro histórico.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  transferVm.isTransferring || _previewId == null || _previewing
                      ? null
                      : _confirmTransfer,
              icon: transferVm.isTransferring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz),
              label: Text(
                transferVm.isTransferring ? 'Transferiendo…' : 'Transferir',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
