import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/get_it.dart';
import '../../../../app/widgets/app_feedback.dart';
import '../../../../app/widgets/app_info_row.dart';
import '../../../asset_deletion/domain/entities/asset_delete_request.dart';
import '../../../asset_deletion/presentation/viewmodels/asset_deletion_request_viewmodel.dart';
import '../../domain/entities/asset.dart';
import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../../kardex/presentation/views/kardex_list_view.dart';
import '../../../operation_reports/domain/usecases/actualizar_es_equipo_proceso.dart';
import '../../../operation_reports/presentation/viewmodels/operation_report_viewmodel.dart';
import '../../../operation_reports/presentation/views/operation_report_form_view.dart';
import '../../../operation_reports/presentation/views/asset_history_analytics_view.dart';
import '../../../operation_reports/presentation/views/operation_report_metrics_view.dart';
import '../reports/asset_report_filter_dialog.dart';
import '../viewmodels/asset_detail_viewmodel.dart';
import 'asset_create_view.dart';
import 'asset_edit_view.dart';
import 'asset_transfer_view.dart';
import 'widgets/asset_image_widget.dart';
import 'widgets/asset_template_dialogs.dart';
import 'widgets/clone_asset_tree_dialog.dart';

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
      AppFeedback.showSuccess(context, 'Activo actualizado.');
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
      AppFeedback.showSuccess(context, 'Componente hijo creado exitosamente.');
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

  Future<void> _openCloneTreeDialog() async {
    final result = await CloneAssetTreeDialog.show(
      context,
      sourceAsset: _asset,
    );
    if (result != null && mounted) {
      AppFeedback.showSuccess(
        context,
        'Estructura duplicada con éxito. Nuevo activo: ${result.newRootAssetCode} (${result.totalClonedNodes} nodos creados).',
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openSaveTemplateDialog() async {
    final ok = await SaveAssetTemplateDialog.show(
      context,
      sourceAsset: _asset,
    );
    if (ok == true && mounted) {
      AppFeedback.showSuccess(
        context,
        'Plantilla guardada exitosamente en el catálogo.',
      );
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KardexListView(entityId: _asset.id),
      ),
    );
  }

  Future<void> _toggleProcessEquipment() async {
    final newVal = !_asset.esEquipoProceso;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newVal ? 'Marcar como Equipo de Proceso' : 'Desmarcar Equipo de Proceso'),
        content: Text(
          newVal
              ? '¿Deseas clasificar este activo (${_asset.id}) como Equipo de Proceso?\n\n'
                'Los equipos de proceso se incluyen en la planilla semanal de disponibilidad y tiempos de operación para los reportes diarios de los jefes de área.'
              : '¿Deseas remover la clasificación de Equipo de Proceso para este activo (${_asset.id})?\n\n'
                'Dejará de aparecer en la planilla semanal de disponibilidad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await getIt<ActualizarEsEquipoProceso>().call(_asset.id, esEquipoProceso: newVal);
      if (mounted) {
        setState(() {
          _asset = _asset.copyWith(esEquipoProceso: newVal);
        });
        AppFeedback.showSuccess(
          context,
          newVal
              ? 'Activo configurado como Equipo de Proceso.'
              : 'Activo desmarcado de Equipos de Proceso.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Error al actualizar: $e');
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
        content: SingleChildScrollView(
          child: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo de la baja *',
              hintText: 'Ej: Obsolescencia, reemplazo por nuevo equipo…',
              border: OutlineInputBorder(),
            ),
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
      AppFeedback.showWarning(context, 'Debes indicar el motivo de la solicitud.');
      return;
    }

    final ok = await _deletionViewModel.request(
      asset: _asset,
      reason: reason,
      userId: user.userId,
      userName: user.username,
    );

    if (!mounted) return;
    if (ok) {
      AppFeedback.showSuccess(context, 'Solicitud enviada al Gerente de Operaciones.');
    } else {
      AppFeedback.showError(context, 'Error: ${_deletionViewModel.errorMessage}');
    }
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

    return ChangeNotifierProvider<AssetDetailViewModel>.value(
      value: _viewModel,
      child: ChangeNotifierProvider<AssetDeletionRequestViewModel>.value(
        value: _deletionViewModel,
        child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${asset.id} - ${asset.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (canCreateChild && _isEquipment)
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: 'Guardar estructura como plantilla',
                onPressed: _openSaveTemplateDialog,
              ),
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Generar Ficha / Reporte (PDF / Excel)',
              onPressed: () => AssetReportFilterDialog.showSingleAsset(context, _asset),
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Ver historial (Kardex)',
              onPressed: _openHistory,
            ),
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Hoja de Vida y Analítica (OTs, Averías, Piezas)',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetHistoryAnalyticsView(
                    codigoActivo: _asset.id,
                    nombreActivo: _asset.name,
                  ),
                ),
              ),
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
                _AssetAvailabilityCard(
                  asset: _asset,
                  onToggleProcessEquipment:
                      canEdit && _isEquipment ? _toggleProcessEquipment : null,
                ),
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
                Consumer<AssetDeletionRequestViewModel>(
                  builder: (context, deletionVm, _) {
                    if (deletionVm.pendingRequest != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PendingDeletionBanner(
                          request: deletionVm.pendingRequest!,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                if (!_isDeactivated)
                  Consumer<AssetDeletionRequestViewModel>(
                    builder: (context, deletionVm, _) {
                      return _AssetActionsCard(
                        canEdit: canEdit,
                        canTransfer: canTransfer,
                        canCloneTree: canCreateChild && _isEquipment,
                        canRequestDeletion:
                            canRequestDeletion && deletionVm.pendingRequest == null,
                        isRequestingDeletion: deletionVm.isRequesting,
                        onEdit: _openEdit,
                        onTransfer: _openTransfer,
                        onCloneTree: _openCloneTreeDialog,
                        onGenerateReport: () =>
                            AssetReportFilterDialog.showSingleAsset(context, _asset),
                        onRequestDeletion: _openDeleteRequest,
                      );
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

class _AssetActionsCard extends StatelessWidget {
  const _AssetActionsCard({
    required this.canEdit,
    required this.canTransfer,
    required this.canCloneTree,
    required this.canRequestDeletion,
    required this.isRequestingDeletion,
    required this.onEdit,
    required this.onTransfer,
    required this.onCloneTree,
    required this.onGenerateReport,
    required this.onRequestDeletion,
  });

  final bool canEdit;
  final bool canTransfer;
  final bool canCloneTree;
  final bool canRequestDeletion;
  final bool isRequestingDeletion;
  final VoidCallback? onEdit;
  final VoidCallback? onTransfer;
  final VoidCallback? onCloneTree;
  final VoidCallback? onGenerateReport;
  final VoidCallback? onRequestDeletion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Gestión del Activo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (canEdit) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar activo'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 550;
                final items = <Widget>[
                  if (canTransfer)
                    _ActionItemButton(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transferir a otra área',
                      color: theme.colorScheme.primary,
                      onPressed: onTransfer,
                      isWide: isWide,
                    ),
                  if (canCloneTree)
                    _ActionItemButton(
                      icon: Icons.copy_all_rounded,
                      label: 'Duplicar estructura / Clonar',
                      color: Colors.indigo.shade700,
                      onPressed: onCloneTree,
                      isWide: isWide,
                    ),
                  _ActionItemButton(
                    icon: Icons.description_outlined,
                    label: 'Ficha Técnica / Reporte',
                    color: Colors.teal.shade800,
                    onPressed: onGenerateReport,
                    isWide: isWide,
                  ),
                ];

                if (isWide) {
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: items,
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      items[i],
                    ],
                  ],
                );
              },
            ),
            if (canRequestDeletion) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: isRequestingDeletion ? null : onRequestDeletion,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Solicitar baja / eliminación'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionItemButton extends StatelessWidget {
  const _ActionItemButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.isWide,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );

    if (isWide) {
      return btn;
    }
    return SizedBox(
      width: double.infinity,
      child: btn,
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
    final targetCode = asset.transferredToId;

    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Activo Histórico Transferido',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              targetCode != null
                  ? 'Este registro se encuentra archivado y desactivado en esta área. Su ciclo de vida activo continúa bajo el código $targetCode en su nueva área de operación.'
                  : 'Este activo se encuentra desactivado por traspaso y su historial está archivado.',
              style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, height: 1.3),
            ),
            const SizedBox(height: 6),
            Text(
              'ℹ️ Si la máquina regresa a esta área en el futuro, realice una nueva transferencia desde el activo actual en su área destino.',
              style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.amber.shade900),
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

  void _showFullImageDialog(BuildContext context, String imagePathOrBase64) {
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
                child: AssetImageWidget(
                  imageData: imagePathOrBase64,
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

    if (imageData == null || imageData.trim().isEmpty) {
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
                child: AssetImageWidget(
                  imageData: imageData,
                  fit: BoxFit.contain,
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
      if (asset.level == AssetLevel.equipment) ...[
        ('N° de Serie', asset.serial != null && asset.serial!.isNotEmpty ? asset.serial! : 'Sin serie registrado'),
        ('Tipo de Activo', asset.esEquipoProceso ? 'Equipo de Proceso (Monitoreo Semanal)' : 'Equipo Estándar'),
      ],
      ('Área', asset.areaId),
      ('Marca', asset.brand ?? 'N/A'),
      ('Modelo', asset.model ?? 'N/A'),
      ('Nivel', _levelLabels[asset.level] ?? asset.level.name),
      ('Activo padre', asset.parentAssetId ?? '—'),
      ('Ruta jerárquica', asset.ancestors.isEmpty ? '—' : asset.ancestors.join(' → ')),
      if (asset.observations != null && asset.observations!.trim().isNotEmpty)
        ('Observaciones', asset.observations!.trim()),
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
                if (asset.level == AssetLevel.equipment && asset.esEquipoProceso) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed, size: 12, color: Colors.blue.shade800),
                        const SizedBox(width: 4),
                        Text(
                          'Equipo de Proceso',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                  ),
                ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sub-equipos / Partes', style: theme.textTheme.titleSmall),
            if (onCreateChild != null)
              FilledButton.tonalIcon(
                onPressed: onCreateChild,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar hijo'),
              ),
          ],
        ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.extension_off_outlined),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Este activo no tiene hijos. Puedes agregar uno para completar su estructura.',
                                ),
                              ),
                            ],
                          ),
                          if (onCreateChild != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: onCreateChild,
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar sub-equipo o parte'),
                              ),
                            ),
                          ],
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
    return AssetImageWidget(
      imageData: child.imageData,
      width: 40,
      height: 40,
      borderRadius: BorderRadius.circular(6),
      fallbackIcon: Icons.precision_manufacturing_outlined,
      fallbackBgColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
  const _AssetAvailabilityCard({
    required this.asset,
    this.onToggleProcessEquipment,
  });

  final Asset asset;
  final VoidCallback? onToggleProcessEquipment;

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

            // Sección de Equipo de Proceso (Solo para activos de primer nivel)
            if (asset.level == AssetLevel.equipment) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: asset.esEquipoProceso ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: asset.esEquipoProceso ? Colors.blue.shade200 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          asset.esEquipoProceso ? Icons.speed : Icons.info_outline,
                          size: 18,
                          color: asset.esEquipoProceso ? Colors.blue.shade800 : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            asset.esEquipoProceso
                                ? 'Equipo de Proceso (Monitoreo Semanal)'
                                : 'Equipo Estándar (Sin monitoreo semanal)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: asset.esEquipoProceso ? Colors.blue.shade900 : Colors.grey.shade800,
                            ),
                          ),
                        ),
                        if (widget.onToggleProcessEquipment != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: widget.onToggleProcessEquipment,
                            child: Text(
                              asset.esEquipoProceso ? 'Desmarcar' : 'Marcar como Proceso',
                              style: TextStyle(
                                fontSize: 12,
                                color: asset.esEquipoProceso ? Colors.red.shade700 : Colors.blue.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (asset.esEquipoProceso) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Este equipo forma parte del flujo principal de planta. Requiere registro semanal de tiempos de operación y paros por turno/día.',
                        style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.blue.shade700,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: getIt<OperationReportViewModel>(),
                                    child: OperationReportFormView(
                                      codigoActivo: asset.id,
                                      nombreActivo: asset.name,
                                      areaId: asset.areaId,
                                      fecha: DateTime.now(),
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_calendar, size: 16),
                            label: const Text('Cargar Reporte Diario', style: TextStyle(fontSize: 12)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.blue.shade900,
                              side: BorderSide(color: Colors.blue.shade300),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: getIt<OperationReportViewModel>(),
                                    child: OperationReportMetricsView(
                                      codigoActivo: asset.id,
                                      nombreActivo: asset.name,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.analytics_outlined, size: 16),
                            label: const Text('Métricas de Disponibilidad', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

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

