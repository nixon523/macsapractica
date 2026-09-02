import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../domain/entities/asset.dart';

class AssetCardWidget extends StatelessWidget {
  const AssetCardWidget({
    super.key,
    required this.asset,
    this.onTap,
    this.onEdit,
    this.isHierarchicalView = true,
  });

  final Asset asset;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool isHierarchicalView;

  int get _depth => switch (asset.level) {
        AssetLevel.equipment => 0,
        AssetLevel.subEquipment => 1,
        AssetLevel.part => 2,
        AssetLevel.subPart => 3,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final imageData = asset.imageData;
    final depth = _depth;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    // Indentación adaptativa: en móvil usamos menos espacio por nivel para
    // dejar más ancho al contenido de la tarjeta.
    final indentUnit = isMobile ? 14.0 : 28.0;
    final currentIndent = isMobile ? 18.0 : 32.0;

    // Color distintivo por nivel jerárquico para acentuar el árbol en la UI
    final levelBorderColor = switch (asset.level) {
      AssetLevel.equipment => colors.primary,
      AssetLevel.subEquipment => Colors.teal.shade700,
      AssetLevel.part => Colors.amber.shade800,
      AssetLevel.subPart => Colors.purple.shade700,
    };

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- Sangría visual y conectores jerárquicos de árbol ---
          if (depth > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < depth - 1; i++)
                  Container(
                    width: indentUnit,
                    height: 56,
                    alignment: Alignment.center,
                    child: Container(
                      width: 2,
                      height: 56,
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                Container(
                  width: currentIndent,
                  height: 56,
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        height: 56,
                        color: levelBorderColor.withValues(alpha: 0.6),
                      ),
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: isMobile ? 16 : 20,
                        color: levelBorderColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // --- Tarjeta del Activo ---
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              elevation: depth == 0 ? 2 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: depth == 0
                      ? colors.primary.withValues(alpha: 0.6)
                      : levelBorderColor.withValues(alpha: 0.4),
                  width: depth == 0 ? 1.8 : 1.2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: levelBorderColor,
                      width: depth == 0 ? 0 : 4,
                    ),
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  onTap: onTap,
                  leading: imageData == null
                      ? CircleAvatar(
                          radius: depth == 0 ? 22 : 18,
                          backgroundColor: depth == 0
                              ? colors.primaryContainer
                              : levelBorderColor.withValues(alpha: 0.15),
                          child: Icon(
                            _getIconForLevel(asset.level),
                            size: depth == 0 ? 22 : 18,
                            color: depth == 0
                                ? colors.onPrimaryContainer
                                : levelBorderColor,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: SizedBox(
                            width: depth == 0 ? 44 : 36,
                            height: depth == 0 ? 44 : 36,
                            child: Image.memory(
                              base64Decode(imageData.split(',').last),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => CircleAvatar(
                                radius: depth == 0 ? 22 : 18,
                                backgroundColor: colors.primaryContainer,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 18,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                  title: Text(
                    '${asset.id} - ${asset.name}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          depth == 0 ? FontWeight.bold : FontWeight.w600,
                      fontSize: depth == 0 ? 15 : 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (asset.serial != null && asset.serial!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(Icons.qr_code,
                                    size: 13, color: colors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'N° Serie: ${asset.serial}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'Marca: ${asset.brand ?? '—'} · Modelo: ${asset.model ?? '—'}',
                          style:
                              theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // En móvil escondemos el chip de nivel (redundante con el
                      // color del borde) para ganar espacio para el título.
                      if (!isMobile) ...[
                        _LevelChip(level: asset.level),
                        const SizedBox(width: 4),
                      ],
                      if (!asset.isActive) ...[
                        _StatusChip(status: asset.status),
                        const SizedBox(width: 4),
                      ],
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar',
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                      const Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLevel(AssetLevel level) => switch (level) {
        AssetLevel.equipment => Icons.precision_manufacturing,
        AssetLevel.subEquipment => Icons.settings,
        AssetLevel.part => Icons.extension,
        AssetLevel.subPart => Icons.grain,
      };
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
    final label = switch (status) {
      AssetStatus.active => 'Activo',
      AssetStatus.transferredDeactivated => 'Transferido',
      AssetStatus.inactive => 'Inactivo',
      AssetStatus.deleted => 'Eliminado',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _levelLabels[level] ?? level.name,
        style: const TextStyle(
            fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500),
      ),
    );
  }
}

const _levelLabels = {
  AssetLevel.equipment: 'Equipo',
  AssetLevel.subEquipment: 'Sub-equipo',
  AssetLevel.part: 'Parte',
  AssetLevel.subPart: 'Sub-parte',
};
