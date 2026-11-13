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
                  title: const Text('No se pudieron cargar las áreas'),
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
                : _buildAreaSelectorCard(context, eligibleAreas),
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

  Widget _buildAreaSelectorCard(BuildContext context, List<Area> eligibleAreas) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final hasArea = _targetArea != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasArea
              ? const Color(0xFF0055A5).withValues(alpha: 0.6)
              : borderColor,
          width: hasArea ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAreaSearchDialog(context, eligibleAreas),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (!hasArea) ...[
                  const Expanded(
                    child: Text(
                      'Buscar o seleccionar área de destino...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF0055A5).withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _targetArea!.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0055A5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _targetArea!.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_targetArea!.costCenter.isNotEmpty)
                          Text(
                            'Centro de Costos: ${_targetArea!.costCenter}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _openAreaSearchDialog(context, eligibleAreas),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0055A5),
                    side: BorderSide(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.35),
                      width: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Text(
                    hasArea ? 'Cambiar' : 'Buscar Área',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAreaSearchDialog(BuildContext context, List<Area> eligibleAreas) {
    showDialog(
      context: context,
      builder: (ctx) => _TransferAreaSearchDialog(
        areas: eligibleAreas,
        selectedAreaId: _targetArea?.id,
        onAreaSelected: (area) {
          setState(() => _targetArea = area);
          _loadPreview(area.id);
        },
      ),
    );
  }
}

class _TransferAreaSearchDialog extends StatefulWidget {
  const _TransferAreaSearchDialog({
    required this.areas,
    required this.selectedAreaId,
    required this.onAreaSelected,
  });

  final List<Area> areas;
  final String? selectedAreaId;
  final ValueChanged<Area> onAreaSelected;

  @override
  State<_TransferAreaSearchDialog> createState() => _TransferAreaSearchDialogState();
}

class _TransferAreaSearchDialogState extends State<_TransferAreaSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _clean(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cleanQuery = _clean(_query);

    final filtered = widget.areas.where((a) {
      if (cleanQuery.isEmpty) return true;
      final idClean = _clean(a.id);
      final nameClean = _clean(a.name);
      final ccClean = _clean(a.costCenter);
      return idClean.contains(cleanQuery) ||
          nameClean.contains(cleanQuery) ||
          ccClean.contains(cleanQuery);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 580),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      color: Color(0xFF0055A5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Área de Destino',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Filtra por código (ej. A003) o por nombre de área',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Escribe el código o nombre del área...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0055A5), width: 1.5),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Áreas disponibles: ${filtered.length}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 38, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'No se encontraron áreas para "$_query"',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final area = filtered[idx];
                        final isSelected = widget.selectedAreaId == area.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Material(
                            color: isSelected
                                ? const Color(0xFF0055A5).withValues(alpha: 0.08)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF0055A5).withValues(alpha: 0.4)
                                    : Colors.transparent,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              dense: true,
                              onTap: () {
                                widget.onAreaSelected(area);
                                Navigator.of(context).pop();
                              },
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0055A5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                area.id,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0055A5),
                                ),
                              ),
                            ),
                            title: Text(
                              area.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF0055A5) : null,
                              ),
                            ),
                            subtitle: Text(
                              area.costCenter.isNotEmpty
                                  ? 'Centro de Costos: ${area.costCenter}'
                                  : 'Área Operativa',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFF0055A5), size: 20)
                                : const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                            ),
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
