import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../domain/entities/asset.dart';
import 'asset_image_widget.dart';

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

    // Indentación proporcional y compacta para no saturar en móviles
    final indentWidth = depth == 0 ? 0.0 : (isMobile ? depth * 16.0 + 2.0 : depth * 20.0);

    // Paleta refinada por nivel jerárquico
    final (levelColor, levelBg, levelLabel) = switch (asset.level) {
      AssetLevel.equipment => (
          const Color(0xFF0284C7),
          const Color(0xFFF0F9FF),
          'Equipo',
        ),
      AssetLevel.subEquipment => (
          const Color(0xFF0D9488),
          const Color(0xFFF0FDFA),
          'Sub-equipo',
        ),
      AssetLevel.part => (
          const Color(0xFFD97706),
          const Color(0xFFFFFBEB),
          'Parte',
        ),
      AssetLevel.subPart => (
          const Color(0xFF7C3AED),
          const Color(0xFFF5F3FF),
          'Sub-parte',
        ),
    };

    // Subtítulo inteligente: sólo muestra datos reales si existen
    final brandModel = [
      if (asset.brand != null && asset.brand!.trim().isNotEmpty && asset.brand != '—') asset.brand!.trim(),
      if (asset.model != null && asset.model!.trim().isNotEmpty && asset.model != '—') asset.model!.trim(),
    ].join(' · ');

    final hasSerial = asset.serial != null && asset.serial!.trim().isNotEmpty;
    final hasSubtitle = hasSerial || brandModel.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 12,
        vertical: depth == 0 ? 3 : 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Conector sutil de árbol jerárquico
          if (depth > 0) ...[
            Container(
              width: indentWidth,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: isMobile ? 14 : 16,
                color: levelColor.withValues(alpha: 0.6),
              ),
            ),
          ],

          // Tarjeta del Activo
          Expanded(
            child: Material(
              color: Colors.white,
              elevation: depth == 0 ? 0.5 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: depth == 0
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFE2E8F0),
                  width: depth == 0 ? 1.0 : 0.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: levelColor,
                        width: depth == 0 ? 4.0 : 3.0,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      // Ícono o Miniatura
                      AssetImageWidget(
                        imageData: imageData,
                        width: depth == 0 ? 36 : (isMobile ? 28 : 30),
                        height: depth == 0 ? 36 : (isMobile ? 28 : 30),
                        fallbackIcon: _getIconForLevel(asset.level),
                        fallbackColor: levelColor,
                        fallbackBgColor: levelBg,
                      ),

                      const SizedBox(width: 10),

                      // Título y datos esenciales
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${asset.id} ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: depth == 0 ? 13.5 : (isMobile ? 12 : 12.5),
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '— ${asset.name}',
                                    style: TextStyle(
                                      fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: depth == 0 ? 13.5 : (isMobile ? 12 : 12.5),
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            if (hasSubtitle) ...[
                              const SizedBox(height: 3),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  if (hasSerial)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.qr_code, size: 11, color: colors.secondary),
                                        const SizedBox(width: 3),
                                        Text(
                                          asset.serial!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: colors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (brandModel.isNotEmpty)
                                    Text(
                                      brandModel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Badges y Acciones en el lateral derecho
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge de Nivel
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: levelBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: levelColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              levelLabel,
                              style: TextStyle(
                                fontSize: isMobile ? 9.5 : 10.5,
                                fontWeight: FontWeight.w600,
                                color: levelColor,
                              ),
                            ),
                          ),

                          if (!asset.isActive) ...[
                            const SizedBox(width: 4),
                            _StatusChip(status: asset.status),
                          ],

                          if (onEdit != null) ...[
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Editar activo',
                              onPressed: onEdit,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              color: Colors.grey.shade600,
                            ),
                          ],

                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
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
        AssetLevel.equipment => Icons.precision_manufacturing_outlined,
        AssetLevel.subEquipment => Icons.settings_suggest_outlined,
        AssetLevel.part => Icons.extension_outlined,
        AssetLevel.subPart => Icons.grain_outlined,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      AssetStatus.active => (Colors.green.shade700, 'Activo'),
      AssetStatus.transferredDeactivated => (Colors.orange.shade800, 'Traspasado'),
      AssetStatus.inactive => (Colors.red.shade700, 'Inactivo'),
      AssetStatus.deleted => (Colors.grey.shade600, 'Eliminado'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
