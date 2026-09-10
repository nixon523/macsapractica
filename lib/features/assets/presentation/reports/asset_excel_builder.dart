import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/asset.dart';

/// Elemento con información jerárquica para exportación en árbol a Excel
class _ExcelHierarchicalItem {
  final Asset asset;
  final int depth;

  const _ExcelHierarchicalItem({
    required this.asset,
    required this.depth,
  });
}

/// Generador de libros nativos de Microsoft Excel (.xlsx) para activos
/// Diseñado con ordenamiento jerárquico (Padre -> Sub-equipos -> Partes),
/// anchos de columna automáticos, estilos formales y formato numérico.
class AssetExcelBuilder {
  static Future<Uint8List> buildInventoryExcel({
    required List<Asset> assets,
    Map<String, String> areaNamesMap = const {},
    String reportTitle = 'Inventario de Activos Grupo Macsa',
  }) async {
    final excel = Excel.createExcel();

    // Renombrar la hoja por defecto
    final defaultSheet = excel.getDefaultSheet();
    const sheetName = 'Inventario de Activos';
    excel.rename(defaultSheet ?? 'Sheet1', sheetName);
    final Sheet sheet = excel[sheetName];

    // Estilos de cabecera principal
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'), // Azul Macsa
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Estilos de datos
    final textStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final textBoldStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final centerStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final centerBoldStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final numberStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Cabeceras y anchos de la Hoja 1: Inventario de Activos (Sin estación)
    final headers = [
      ('Código Activo', 20.0),
      ('Nombre del Activo', 42.0),
      ('Área ID', 12.0),
      ('Nombre de Área', 32.0),
      ('Nivel Jerárquico', 16.0),
      ('Marca', 20.0),
      ('Modelo', 22.0),
      ('Número de Serie', 22.0),
      ('Estado Operativo', 18.0),
      ('Equipo de Proceso', 18.0),
      ('Código Padre', 18.0),
      ('Fecha Alta', 16.0),
      ('Horas Operativas (Uptime)', 26.0),
      ('Horas Fuera de Servicio (Downtime)', 32.0),
      ('Disponibilidad (%)', 20.0),
      ('Total Paradas (Eventos)', 22.0),
    ];

    // Escribir cabeceras y configurar ancho de columnas
    for (var col = 0; col < headers.length; col++) {
      final (title, width) = headers[col];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(title);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(col, width);
    }

    // Ordenar jerárquicamente todos los activos
    final hierarchicalItems = _buildHierarchicalTree(assets);

    // Llenar filas de datos
    for (var r = 0; r < hierarchicalItems.length; r++) {
      final item = hierarchicalItems[r];
      final a = item.asset;
      final isRoot = item.depth == 0;
      final rowIndex = r + 1;
      final areaName = areaNamesMap[a.areaId] ?? a.areaId;

      final uptimeHours = (a.totalUptime.inMinutes / 60.0);
      final downtimeHours = (a.totalDowntime.inMinutes / 60.0);
      final dispPct = a.availabilityPercentage;

      // Indentación visual de nombre
      String nameDisplay = a.name;
      if (item.depth == 1) {
        nameDisplay = '  • ${a.name}';
      } else if (item.depth == 2) {
        nameDisplay = '    - ${a.name}';
      } else if (item.depth >= 3) {
        nameDisplay = '      - ${a.name}';
      }

      final rowData = [
        (TextCellValue(a.id), isRoot ? centerBoldStyle : centerStyle),
        (TextCellValue(nameDisplay), isRoot ? textBoldStyle : textStyle),
        (TextCellValue(a.areaId), centerStyle),
        (TextCellValue(areaName), textStyle),
        (TextCellValue(_formatLevel(a.level)), isRoot ? centerBoldStyle : centerStyle),
        (TextCellValue(a.brand ?? '-'), textStyle),
        (TextCellValue(a.model ?? '-'), textStyle),
        (TextCellValue(a.serial ?? '-'), centerStyle),
        (TextCellValue(_formatStatus(a.status)), isRoot ? centerBoldStyle : centerStyle),
        (TextCellValue(a.esEquipoProceso ? 'SÍ' : 'NO'), centerStyle),
        (TextCellValue(a.parentAssetId ?? '-'), centerStyle),
        (TextCellValue(a.createdAt != null ? _formatDate(a.createdAt!) : '-'), centerStyle),
        (DoubleCellValue(double.parse(uptimeHours.toStringAsFixed(2))), numberStyle),
        (DoubleCellValue(double.parse(downtimeHours.toStringAsFixed(2))), numberStyle),
        (DoubleCellValue(double.parse(dispPct.toStringAsFixed(2))), numberStyle),
        (IntCellValue(a.inactiveCount), numberStyle),
      ];

      for (var c = 0; c < rowData.length; c++) {
        final (val, style) = rowData[c];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
        cell.value = val;
        cell.cellStyle = style;
      }
    }

    // Hoja 2: Bitácora de Estados y Paradas
    const historySheetName = 'Historial de Estados y Paradas';
    final Sheet histSheet = excel[historySheetName];

    final histHeaders = [
      ('Código Activo', 20.0),
      ('Nombre del Activo', 38.0),
      ('Área', 30.0),
      ('Fecha Inicio', 22.0),
      ('Fecha Fin', 22.0),
      ('Duración (Horas)', 18.0),
      ('Estado Resultante', 18.0),
      ('Motivo / Observación', 45.0),
    ];

    for (var col = 0; col < histHeaders.length; col++) {
      final (title, width) = histHeaders[col];
      final cell = histSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(title);
      cell.cellStyle = headerStyle;
      histSheet.setColumnWidth(col, width);
    }

    var histRow = 1;
    for (final item in hierarchicalItems) {
      final a = item.asset;
      final areaName = areaNamesMap[a.areaId] ?? a.areaId;
      for (final p in a.statusHistory) {
        final durHours = p.duration.inMinutes / 60.0;
        final rowVals = [
          (TextCellValue(a.id), centerStyle),
          (TextCellValue(a.name), textStyle),
          (TextCellValue(areaName), textStyle),
          (TextCellValue(_formatDateTime(p.startedAt)), centerStyle),
          (TextCellValue(p.endedAt != null ? _formatDateTime(p.endedAt!) : 'Actual'), centerStyle),
          (DoubleCellValue(double.parse(durHours.toStringAsFixed(2))), numberStyle),
          (TextCellValue(_formatStatus(p.status)), centerStyle),
          (TextCellValue(p.reason ?? '-'), textStyle),
        ];

        for (var c = 0; c < rowVals.length; c++) {
          final (val, style) = rowVals[c];
          final cell = histSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: histRow));
          cell.value = val;
          cell.cellStyle = style;
        }
        histRow++;
      }
    }

    // Codificar los bytes puros sin disparar descargas automáticas
    final fileBytes = excel.encode();
    return Uint8List.fromList(fileBytes ?? []);
  }

  /// Construye el árbol jerárquico determinístico (Padre -> Hijos -> Nietos)
  static List<_ExcelHierarchicalItem> _buildHierarchicalTree(List<Asset> assets) {
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

    // Ordenar raíces por área y luego código natural
    rootAssets.sort((a, b) {
      final areaCmp = a.areaId.compareTo(b.areaId);
      if (areaCmp != 0) return areaCmp;
      return a.id.compareTo(b.id);
    });

    // Ordenar hijos de cada padre
    for (final list in childrenMap.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    final List<_ExcelHierarchicalItem> result = [];

    void traverse(Asset node, int depth) {
      result.add(_ExcelHierarchicalItem(asset: node, depth: depth));
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

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
