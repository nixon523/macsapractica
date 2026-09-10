import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/asset.dart';

/// Elemento con información jerárquica para renderizado en árbol
class _HierarchicalAssetItem {
  final Asset asset;
  final int depth;

  const _HierarchicalAssetItem({
    required this.asset,
    required this.depth,
  });
}

/// Generador de Catálogo e Inventario de Activos por Área o Multi-Área en PDF
/// Organizado por jerarquía de árbol (Padre -> Sub-equipos -> Partes -> Sub-partes),
/// con sangría ASCII 100% compatible, anchos calibrados para códigos largos de 4to nivel
/// y banners de área de ancho completo.
class AssetAreaInventoryPdfBuilder {
  static const _brandDark = PdfColor(0.08, 0.22, 0.38);
  static const _brandPrimary = PdfColor(0.12, 0.40, 0.65);
  static const _brandLight = PdfColor(0.92, 0.96, 1.00);
  static const _headerBg = PdfColor(0.94, 0.94, 0.94);
  static const _rootRowBg = PdfColor(0.97, 0.98, 1.00);
  static const _borderColor = PdfColors.grey400;

  static Future<Uint8List> buildPdf({
    required List<Asset> assets,
    PdfPageFormat pageFormat = PdfPageFormat.letter,
    String title = 'INVENTARIO Y CATÁLOGO DE ACTIVOS',
    String? subtitle,
    Map<String, String> areaNamesMap = const {},
    String issuedByName = 'Administrador de Sistema',
  }) async {
    final pdf = pw.Document();

    // Métricas globales
    final totalAssets = assets.length;
    final activeCount = assets.where((a) => a.status == AssetStatus.active).length;
    final inactiveCount = assets.where((a) => a.status == AssetStatus.inactive).length;
    final processCount = assets.where((a) => a.esEquipoProceso).length;
    final avgAvail = totalAssets > 0
        ? assets.map((a) => a.availabilityPercentage).reduce((a, b) => a + b) / totalAssets
        : 100.0;

    // Agrupar por área
    final Map<String, List<Asset>> grouped = {};
    for (final asset in assets) {
      grouped.putIfAbsent(asset.areaId, () => []).add(asset);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        header: (context) => _buildHeader(title, subtitle),
        footer: (context) => _buildFooter(context, issuedByName),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 8),

            // Resumen Ejecutivo de Métricas
            _buildExecutiveSummary(
              total: totalAssets,
              active: activeCount,
              inactive: inactiveCount,
              process: processCount,
              avgAvail: avgAvail,
              areasCount: grouped.keys.length,
            ),
            pw.SizedBox(height: 10),

            // Tablas por Área con jerarquía estricta y banner de ancho completo
            ...grouped.entries.map((entry) {
              final areaId = entry.key;
              final areaName = areaNamesMap[areaId] ?? areaId;
              final areaAssets = entry.value;
              final treeItems = _buildHierarchicalTree(areaAssets);

              return pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Banner de Área a ancho completo
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                      decoration: const pw.BoxDecoration(
                        color: _brandPrimary,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(2),
                          topRight: pw.Radius.circular(2),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'ÁREA: $areaName ($areaId)',
                            style: pw.TextStyle(
                              fontSize: 9.0,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            '${areaAssets.length} Activos',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tabla de Activos de la Área con cabecera repetible
                    _buildAssetsTable(treeItems),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String title, String? subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brandPrimary, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'GRUPO MACSA - SISTEMA CMMS',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _brandDark),
              ),
              if (subtitle != null)
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _brandLight,
              border: pw.Border.all(color: _brandPrimary),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _brandDark),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, String issuedByName) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado por: $issuedByName | Fecha de Emisión: $dateStr',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _brandDark),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary({
    required int total,
    required int active,
    required int inactive,
    required int process,
    required double avgAvail,
    required int areasCount,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: _headerBg,
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryCard('Áreas Incluidas', '$areasCount', _brandDark),
          _summaryCard('Total Activos', '$total', _brandPrimary),
          _summaryCard('Activos Operativos', '$active', PdfColors.green800),
          _summaryCard('Fuera de Servicio', '$inactive', PdfColors.red800),
          _summaryCard('Equipos de Proceso', '$process', PdfColors.blue800),
          _summaryCard('Disponibilidad Media', '${avgAvail.toStringAsFixed(1)} %', PdfColors.teal800),
        ],
      ),
    );
  }

  static pw.Widget _summaryCard(String label, String val, PdfColor col) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(val, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: col)),
      ],
    );
  }

  static pw.Widget _buildAssetsTable(List<_HierarchicalAssetItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.1), // Código (amplio para códigos largos tipo A003-001-03-01-01)
        1: pw.FlexColumnWidth(3.3), // Nombre del Activo (con sangría limpia)
        2: pw.FlexColumnWidth(1.1), // Nivel
        3: pw.FlexColumnWidth(1.7), // Marca/Modelo
        4: pw.FlexColumnWidth(1.4), // Serie
        5: pw.FlexColumnWidth(0.9), // Estado
        6: pw.FlexColumnWidth(0.75), // Proceso
        7: pw.FlexColumnWidth(0.75), // Disp %
      },
      children: [
        // Cabecera formal de columnas (se repite en cada página si la tabla se divide)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          repeat: true,
          children: [
            _cell('Código', isHeader: true),
            _cell('Nombre del Activo', isHeader: true),
            _cell('Nivel', isHeader: true),
            _cell('Marca / Modelo', isHeader: true),
            _cell('N° Serie', isHeader: true),
            _cell('Estado', isHeader: true),
            _cell('Proceso', isHeader: true),
            _cell('Disp. %', isHeader: true),
          ],
        ),

        // Filas de datos ordenadas en árbol jerárquico
        ...items.map((item) {
          final a = item.asset;
          final isRoot = item.depth == 0;
          final brandModel = '${a.brand ?? ''} ${a.model ?? ''}'.trim();

          return pw.TableRow(
            decoration: isRoot ? const pw.BoxDecoration(color: _rootRowBg) : null,
            children: [
              _cell(a.id, bold: isRoot, isCode: true),
              _nameCell(a.name, item.depth, isRoot),
              _cell(_formatLevel(a.level), bold: isRoot),
              _cell(brandModel.isNotEmpty ? brandModel : '-'),
              _cell(a.serial ?? '-'),
              _cell(
                _formatStatus(a.status),
                bold: isRoot,
                color: a.status == AssetStatus.active
                    ? PdfColors.green900
                    : (a.status == AssetStatus.inactive ? PdfColors.red900 : PdfColors.orange900),
              ),
              _cell(a.esEquipoProceso ? 'SÍ' : 'NO', bold: a.esEquipoProceso),
              _cell('${a.availabilityPercentage.toStringAsFixed(1)}%'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _nameCell(String name, int depth, bool isRoot) {
    final double leftIndent = depth == 0 ? 0.0 : (depth == 1 ? 6.0 : (depth == 2 ? 12.0 : 18.0));

    return pw.Padding(
      padding: pw.EdgeInsets.only(left: 3.5 + leftIndent, right: 3.5, top: 2.5, bottom: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (depth > 0)
            pw.Text(
              '- ',
              style: pw.TextStyle(
                fontSize: 6.8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          pw.Expanded(
            child: pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: 6.8,
                fontWeight: isRoot ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isRoot ? _brandDark : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool isHeader = false, bool bold = false, bool isCode = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isCode ? 6.7 : 7.0,
          fontWeight: (isHeader || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? _brandDark : (color ?? PdfColors.black),
        ),
      ),
    );
  }

  /// Construye el árbol jerárquico determinístico (Padre -> Hijos -> Nietos)
  static List<_HierarchicalAssetItem> _buildHierarchicalTree(List<Asset> assets) {
    final assetMap = {for (final a in assets) a.id: a};
    final Map<String, List<Asset>> childrenMap = {};
    final List<Asset> rootAssets = [];

    for (final a in assets) {
      final parentId = a.parentAssetId;
      if (parentId != null && parentId.isNotEmpty && assetMap.containsKey(parentId)) {
        childrenMap.putIfAbsent(parentId, () => []).add(a);
      } else {
        rootAssets.add(a);
      }
    }

    // Ordenar raíces por código natural (A1-001, A1-002, ...)
    rootAssets.sort((a, b) => a.id.compareTo(b.id));

    // Ordenar hijos de cada padre
    for (final list in childrenMap.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    final List<_HierarchicalAssetItem> result = [];

    void traverse(Asset node, int depth) {
      result.add(_HierarchicalAssetItem(asset: node, depth: depth));
      final children = childrenMap[node.id] ?? [];
      for (final child in children) {
        traverse(child, depth + 1);
      }
    }

    for (final root in rootAssets) {
      traverse(root, 0);
    }

    return result;
  }

  static String _formatLevel(AssetLevel level) {
    switch (level) {
      case AssetLevel.equipment:
        return 'Equipo';
      case AssetLevel.subEquipment:
        return 'Sub-equipo';
      case AssetLevel.part:
        return 'Parte';
      case AssetLevel.subPart:
        return 'Sub-parte';
    }
  }

  static String _formatStatus(AssetStatus status) {
    switch (status) {
      case AssetStatus.active:
        return 'Activo';
      case AssetStatus.inactive:
        return 'Inactivo';
      case AssetStatus.transferredDeactivated:
        return 'Transferido';
      case AssetStatus.deleted:
        return 'Eliminado';
    }
  }
}
