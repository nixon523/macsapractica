import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../app/widgets/app_dialog.dart';
import '../../../../app/widgets/app_info_row.dart';
import '../../../asset_deletion/domain/entities/asset_delete_request.dart';
import '../../../asset_deletion/presentation/viewmodels/asset_deletion_request_viewmodel.dart';
import '../../domain/entities/asset.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../kardex/presentation/views/kardex_list_view.dart';
import '../viewmodels/asset_detail_viewmodel.dart';
import 'asset_create_view.dart';
import 'asset_edit_view.dart';
import 'asset_transfer_view.dart';

const _statusLabels = {
  AssetStatus.active: 'Activo',
  AssetStatus.transferredDeactivated: 'Transferido / Desactivado',
  AssetStatus.inactive: 'Inactivo',
  AssetStatus.deleted: 'Eliminado',
};

const _levelLabels = {
  AssetLevel.equipment: 'Equipo',
  AssetLevel.subEquipment: 'Sub-equipo',
  AssetLevel.part: 'Parte',
  AssetLevel.subPart: 'Sub-parte',
};

class AssetDetailView extends StatefulWidget {
  const AssetDetailView({
    super.key,
    required this.areaId,
    required this.asset,
  });

  final String areaId;
  final Asset asset;

  @override
  State<AssetDetailView> createState() => _AssetDetailViewState();
}

class _AssetDetailViewState extends State<AssetDetailView> {
  late final AssetDetailViewModel _viewModel = getIt<AssetDetailViewModel>();
  late final AssetDeletionRequestViewModel _deletionViewModel =
      getIt<AssetDeletionRequestViewModel>();
  // Copia local del activo: permite actualizar la pantalla en sitio cuando se
  // edita sin necesidad de salir y volver a entrar.
  late Asset _asset = widget.asset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.loadChildren(
        areaId: widget.areaId,
        parentAssetId: _asset.id,
      );
      _deletionViewModel.loadPending(_asset.id);
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _deletionViewModel.dispose();
    super.dispose();
  }

  bool get _isEquipment => _asset.level == AssetLevel.equipment;
  bool get _isLeaf => _asset.level == AssetLevel.subPart;
  bool get _isDeactivated =>
      _asset.status == AssetStatus.transferredDeactivated;

  Future<void> _reloadChildren() {
    return _viewModel.loadChildren(
      areaId: widget.areaId,
      parentAssetId: _asset.id,
    );
  }

  void _openEdit() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssetEditView(asset: _asset)),
    );
    // El formulario devuelve el Asset actualizado: se refleja en la pantalla
    // sin cerrar el detalle.
    if (result is Asset && mounted) {
      setState(() => _asset = result);
      _reloadChildren();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activo actualizado.')),
      );
    }
  }

  void _openCreateChild() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetCreateView(
          areaId: widget.areaId,
          parentAsset: _asset,
        ),
      ),
    );
    // El hijo se crea bajo el activo actual: se recargan los hijos y se queda
    // en el detalle para verlo reflejado.
    if (result != null && mounted) {
      _reloadChildren();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hijo creado.')),
      );
    }
  }

  void _openTransfer() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetTransferView(asset: _asset),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KardexListView(entityId: _asset.id),
      ),
    );
  }

  Future<void> _confirmReactivate() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivar activo'),
        content: const Text(
          'Se reactivará este activo junto con toda su descendencia, '
          'quedando disponible de nuevo para ser transferido. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await _viewModel.reactivate(
      asset: _asset,
      userId: user.userId,
      userName: user.username,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activo reactivado correctamente.')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${_viewModel.reactivationError ?? 'No se pudo reactivar'}',
          ),
        ),
      );
    }
  }

  Future<void> _openToggleStatus(AssetStatus newStatus) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final isPausing = newStatus == AssetStatus.inactive;
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isPausing ? Icons.power_settings_new : Icons.play_circle_outline,
              color: isPausing ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPausing
                    ? 'Inactivar Activo / Fuera de Servicio'
                    : 'Reactivar Activo Operativo',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: responsiveDialogWidth(context, 440),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPausing ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPausing ? Colors.orange.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    isPausing
                        ? 'Al inactivar este activo se registrará como fuera de servicio en el área ${_asset.areaId} y se iniciará el conteo de tiempo de parada (Downtime).'
                        : 'Al reactivar el activo volverá a estar disponible para operaciones y mantenimiento en el área ${_asset.areaId}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPausing ? Colors.orange.shade900 : Colors.green.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Motivo de la ${isPausing ? "Inactivación" : "Reactivación"} *',
                    hintText: isPausing
                        ? 'Ej: Falla en rodamiento, en espera de repuesto...'
                        : 'Ej: Reparación concluida, pruebas aprobadas...',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Debes ingresar el motivo'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isPausing ? Colors.orange.shade800 : Colors.green.shade700,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(isPausing ? 'Confirmar Inactivación' : 'Confirmar Reactivación'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _viewModel.toggleActiveStatus(
        assetId: _asset.id,
        newStatus: newStatus,
        reason: reasonCtrl.text.trim(),
        userId: user.userId,
        userName: user.username,
      );

      if (success && mounted) {
        final now = DateTime.now();
        final updatedHistory = <AssetStatusPeriod>[];
        for (final p in _asset.statusHistory) {
          if (p.isCurrent) {
            updatedHistory.add(AssetStatusPeriod(
              status: p.status,
              startedAt: p.startedAt,
              endedAt: now,
              areaId: p.areaId,
              reason: p.reason,
              userId: p.userId,
              userName: p.userName,
            ));
          } else {
            updatedHistory.add(p);
          }
        }
        updatedHistory.add(AssetStatusPeriod(
          status: newStatus,
          startedAt: now,
          areaId: _asset.areaId,
          reason: reasonCtrl.text.trim(),
          userId: user.userId,
          userName: user.username,
        ));

        setState(() {
          _asset = _asset.copyWith(
            status: newStatus,
            statusHistory: updatedHistory,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == AssetStatus.inactive
                  ? 'Activo marcado como Inactivo / Fuera de Servicio.'
                  : 'Activo reactivado exitosamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openDeleteRequest() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar eliminación'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo de la baja *',
            hintText: 'Ej: Obsolescencia, reemplazo por nuevo equipo…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes indicar el motivo de la solicitud.')),
      );
      return;
    }

    final ok = await _deletionViewModel.request(
      asset: _asset,
      reason: reason,
      userId: user.userId,
      userName: user.username,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Solicitud enviada al Gerente de Operaciones.'
              : 'Error: ${_deletionViewModel.errorMessage}',
        ),
      ),
    );
  }

  void _openChild(Asset child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetDetailView(
          areaId: widget.areaId,
          asset: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    final authVm = context.watch<AuthViewModel>();
    final canTransfer = _isEquipment &&
        asset.isActive &&
        authVm.hasPermission('asset.transfer');
    final canRequestDeletion = asset.status != AssetStatus.deleted &&
        authVm.hasPermission('asset.delete.request');
    // Un activo dado de baja o deshabilitado por transferencia no se edita.
    final canEdit = asset.status != AssetStatus.deleted &&
        !_isDeactivated &&
        authVm.hasPermission('asset.edit');
    final canCreateChild = !_isLeaf &&
        asset.status == AssetStatus.active &&
        authVm.hasPermission('asset.create');
    final canReactivate =
        _isDeactivated && authVm.hasPermission('asset.transfer');

    return ChangeNotifierProvider<AssetDetailViewModel>.value(
      value: _viewModel,
      child: ChangeNotifierProvider<AssetDeletionRequestViewModel>.value(
        value: _deletionViewModel,
        child: Scaffold(
        appBar: AppBar(
          title: Text('${asset.id} - ${asset.name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Ver historial (Kardex)',
              onPressed: _openHistory,
            ),
          ],
        ),
        body: Consumer<AssetDetailViewModel>(
          builder: (context, viewModel, child) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isDeactivated) ...[
                  _DeactivatedBanner(asset: asset),
                  const SizedBox(height: 16),
                ],
                _AssetPhoto(asset: asset),
                const SizedBox(height: 16),
                _AssetInfoCard(asset: asset),
                const SizedBox(height: 16),
                _AssetAvailabilityCard(asset: _asset),
                const SizedBox(height: 16),
                if (asset.dynamicAttributes.isNotEmpty) ...[
                  _AttributesCard(attributes: asset.dynamicAttributes),
                  const SizedBox(height: 16),
                ],
                if (!_isLeaf) ...[
                  _ChildrenSection(
                    viewState: viewModel.viewState,
                    children: viewModel.children,
                    errorMessage: viewModel.errorMessage,
                    onRetry: _reloadChildren,
                    onChildTap: _openChild,
                    onCreateChild: canCreateChild ? _openCreateChild : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isDeactivated)
                  FilledButton.icon(
                    onPressed:
                        viewModel.isReactivating || !canReactivate
                            ? null
                            : _confirmReactivate,
                    icon: viewModel.isReactivating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo),
                    label: Text(
                      viewModel.isReactivating
                          ? 'Reactivando…'
                          : 'Reactivar activo transferido',
                    ),
                  )
                else ...[
                  if (canEdit) ...[
                    FilledButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar activo'),
                    ),
                    const SizedBox(height: 10),
                    if (_asset.isActive)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade900,
                          side: BorderSide(color: Colors.orange.shade400),
                        ),
                        onPressed: () => _openToggleStatus(AssetStatus.inactive),
                        icon: const Icon(Icons.power_settings_new, color: Colors.orange),
                        label: const Text('Inactivar / Fuera de Servicio'),
                      )
                    else if (_asset.isInactive)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                        onPressed: () => _openToggleStatus(AssetStatus.active),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Reactivar Activo Operativo'),
                      ),
                  ],
                  if (canTransfer) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openTransfer,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Transferir a otra área'),
                    ),
                  ],
                ],
                Consumer<AssetDeletionRequestViewModel>(
                  builder: (context, deletionVm, _) {
                    if (deletionVm.pendingRequest != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _PendingDeletionBanner(
                          request: deletionVm.pendingRequest!,
                        ),
                      );
                    }
                    if (canRequestDeletion) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: OutlinedButton.icon(
                          onPressed: deletionVm.isRequesting
                              ? null
                              : _openDeleteRequest,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Solicitar eliminación'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

class _PendingDeletionBanner extends StatelessWidget {
  const _PendingDeletionBanner({required this.request});

  final AssetDeleteRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Solicitud de eliminación pendiente',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Motivo: ${request.reason}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Solicitada por ${request.requestedByUserName} · '
              '${request.subtreeCount} activo(s) afectado(s).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeactivatedBanner extends StatelessWidget {
  const _DeactivatedBanner({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                asset.transferredToId != null
                    ? 'Este activo fue transferido (duplicado en ${asset.transferredToId}). '
                        'Está deshabilitado y solo puede reactivarse para volver a transferirlo.'
                    : 'Este activo está deshabilitado y solo puede reactivarse.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetPhoto extends StatelessWidget {
  const _AssetPhoto({required this.asset});

  final Asset asset;

  void _showFullImageDialog(BuildContext context, String base64String) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black87,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  base64Decode(base64String.split(',').last),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final imageData = asset.imageData;

    if (imageData == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.precision_manufacturing_outlined,
                size: 54,
                color: colors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                'Sin fotografía registrada',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = base64Decode(imageData.split(',').last);

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Imagen con BoxFit.contain para ver el activo 100% completo sin recortes ni distorsión
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showFullImageDialog(context, imageData),
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                height: 250,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 54, color: colors.error),
                  ),
                ),
              ),
            ),
          ),

          // Botón flotante para ampliar imagen
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: colors.surface.withValues(alpha: 0.85),
              elevation: 3,
              shape: const CircleBorder(),
              child: IconButton(
                icon: Icon(Icons.fullscreen, color: colors.primary, size: 22),
                tooltip: 'Ampliar imagen a pantalla completa',
                onPressed: () => _showFullImageDialog(context, imageData),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetInfoCard extends StatelessWidget {
  const _AssetInfoCard({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rows = <(String, String)>[
      ('ID', asset.id),
      ('Nombre', asset.name),
      if (asset.level == AssetLevel.equipment)
        ('N° de Serie', asset.serial != null && asset.serial!.isNotEmpty ? asset.serial! : 'Sin serie registrado'),
      ('Área', asset.areaId),
      ('Marca', asset.brand ?? 'N/A'),
      ('Modelo', asset.model ?? 'N/A'),
      ('Nivel', _levelLabels[asset.level] ?? asset.level.name),
      ('Activo padre', asset.parentAssetId ?? '—'),
      ('Ruta jerárquica', asset.ancestors.isEmpty ? '—' : asset.ancestors.join(' → ')),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(status: asset.status),
                const SizedBox(width: 8),
                _LevelChip(level: asset.level),
              ],
            ),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              AppInfoRow(
                label: label,
                value: Text(value),
                labelWidth: 120,
                labelStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttributesCard extends StatelessWidget {
  const _AttributesCard({required this.attributes});

  final Map<String, dynamic> attributes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atributos técnicos',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final entry in attributes.entries)
              AppInfoRow(
                label: entry.key,
                value: Text('${entry.value}'),
                labelWidth: 140,
                labelStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChildrenSection extends StatelessWidget {
  const _ChildrenSection({
    required this.viewState,
    required this.children,
    required this.errorMessage,
    required this.onRetry,
    required this.onChildTap,
    required this.onCreateChild,
  });

  final DetailViewState viewState;
  final List<Asset> children;
  final String errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<Asset> onChildTap;
  final VoidCallback? onCreateChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sub-equipos / Partes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        switch (viewState) {
          DetailViewState.loading =>
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )),
          DetailViewState.error => Center(
              child: Column(
                children: [
                  Text('Error: $errorMessage', textAlign: TextAlign.center),
                  TextButton(onPressed: onRetry, child: const Text('Reintentar')),
                ],
              ),
            ),
          DetailViewState.initial || DetailViewState.success =>
            children.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.extension_off_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este activo no tiene hijos. Puedes agregar uno para completar su estructura.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final child in children)
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: _ChildThumb(child: child),
                            title: Text('${child.id} - ${child.name}'),
                            subtitle: Text(
                              '${_levelLabels[child.level] ?? child.level.name} · ${child.brand ?? ''} ${child.model ?? ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!child.isActive) ...[
                                  _StatusChip(status: child.status),
                                  const SizedBox(width: 4),
                                ],
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => onChildTap(child),
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (onCreateChild != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onCreateChild,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar hijo'),
                          ),
                        ),
                    ],
                  ),
        },
      ],
    );
  }
}

class _ChildThumb extends StatelessWidget {
  const _ChildThumb({required this.child});

  final Asset child;

  @override
  Widget build(BuildContext context) {
    final imageData = child.imageData;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 40,
        height: 40,
        child: imageData == null
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.precision_manufacturing_outlined, size: 24),
              )
            : Image.memory(
                base64Decode(imageData.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AssetStatus.active => Colors.green,
      AssetStatus.transferredDeactivated => Colors.orange,
      AssetStatus.inactive => Colors.red,
      AssetStatus.deleted => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            _statusLabels[status] ?? status.name,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final AssetLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      AssetLevel.equipment => Colors.blue.shade100,
      AssetLevel.subEquipment => Colors.teal.shade100,
      AssetLevel.part => Colors.amber.shade100,
      AssetLevel.subPart => Colors.purple.shade100,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _levelLabels[level] ?? level.name,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

class _AssetAvailabilityCard extends StatefulWidget {
  const _AssetAvailabilityCard({required this.asset});

  final Asset asset;

  @override
  State<_AssetAvailabilityCard> createState() => _AssetAvailabilityCardState();
}

class _AssetAvailabilityCardState extends State<_AssetAvailabilityCard> {
  bool _expanded = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) {
      final hours = d.inHours % 24;
      return '${d.inDays}d ${hours}h';
    }
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return '${d.inHours}h ${mins}m';
    }
    if (d.inMinutes > 0) {
      final secs = d.inSeconds % 60;
      return '${d.inMinutes}m ${secs}s';
    }
    return '${d.inSeconds} seg';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = widget.asset;
    final history = asset.statusHistory.reversed.toList();

    final uptimeStr = _formatDuration(asset.totalUptime);
    final downtimeStr = _formatDuration(asset.totalDowntime);
    final avail = asset.availabilityPercentage;
    final availColor = avail >= 90
        ? Colors.green.shade700
        : (avail >= 75 ? Colors.orange.shade700 : Colors.red.shade700);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Disponibilidad y Tiempos de Operación',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4 KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final kpiItems = [
                  _KpiBox(
                    label: 'Tiempo Operativo',
                    value: uptimeStr,
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                  ),
                  _KpiBox(
                    label: 'Fuera de Servicio',
                    value: downtimeStr,
                    color: Colors.red,
                    icon: Icons.pause_circle_outline,
                  ),
                  _KpiBox(
                    label: 'Disponibilidad',
                    value: '${avail.toStringAsFixed(1)}%',
                    color: availColor,
                    icon: Icons.speed,
                  ),
                  _KpiBox(
                    label: 'Paradas Registradas',
                    value: '${asset.inactiveCount} veces',
                    color: Colors.orange,
                    icon: Icons.history_toggle_off,
                  ),
                ];

                if (isNarrow) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: kpiItems[0]), const SizedBox(width: 8), Expanded(child: kpiItems[1])]),
                      const SizedBox(height: 8),
                      Row(children: [Expanded(child: kpiItems[2]), const SizedBox(width: 8), Expanded(child: kpiItems[3])]),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: kpiItems[0]),
                    const SizedBox(width: 8),
                    Expanded(child: kpiItems[1]),
                    const SizedBox(width: 8),
                    Expanded(child: kpiItems[2]),
                    const SizedBox(width: 8),
                    Expanded(child: kpiItems[3]),
                  ],
                );
              },
            ),

            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _expanded
                            ? 'Ocultar bitácora de estados (${history.length})'
                            : 'Ver bitácora de estados (${history.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                for (final p in history)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.status == AssetStatus.active
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: p.status == AssetStatus.active
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  p.status == AssetStatus.active
                                      ? Icons.check_circle
                                      : Icons.pause_circle_filled,
                                  size: 16,
                                  color: p.status == AssetStatus.active
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.status == AssetStatus.active
                                      ? 'Operativo'
                                      : 'Fuera de Servicio',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: p.status == AssetStatus.active
                                        ? Colors.green.shade900
                                        : Colors.orange.shade900,
                                  ),
                                ),
                                if (p.isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ACTUAL',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              _formatDuration(p.duration),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Desde: ${_formatDate(p.startedAt)} '
                          '${p.endedAt != null ? "→ Hasta: ${_formatDate(p.endedAt!)}" : "(En curso)"}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        if (p.reason != null && p.reason!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Motivo: ${p.reason}',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                        if (p.userName != null && p.userName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Registrado por: ${p.userName}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

