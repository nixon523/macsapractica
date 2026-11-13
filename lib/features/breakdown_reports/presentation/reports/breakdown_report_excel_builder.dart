import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/breakdown_report.dart';

/// Generador de libros nativos Microsoft Excel (.xlsx) para Reportes de Averías / Incidencias
/// de Grupo Macsa con métricas clave, formato ejecutivo y desglose por área.
class BreakdownReportExcelBuilder {
  static Future<Uint8List> buildBreakdownExcel({
    required List<BreakdownReport> reports,
    Map<String, String> areaNamesMap = const {},
    String reportTitle = 'Reporte Ejecutivo de Averías e Incidencias - Grupo Macsa',
    String? dateFilterLabel,
  }) async {
    final excel = Excel.createExcel();

    // ─────────────────────────────────────────────────────────────
    // Hoja 1: Incidencias y Averías
    // ─────────────────────────────────────────────────────────────
    final defaultSheet = excel.getDefaultSheet();
    const sheetName = 'Averías e Incidencias';
    excel.rename(defaultSheet ?? 'Sheet1', sheetName);
    final Sheet sheet = excel[sheetName];

    // Estilos
    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#0055A5'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final subTitleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F0F4F8'),
      fontColorHex: ExcelColor.fromHexString('#334155'),
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      italic: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final kpiHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final kpiValueStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#0055A5'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

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

    // Métricas para bloque KPI
    final totalCount = reports.length;
    final reportedCount = reports.where((r) => r.status == BreakdownReportStatus.reported).length;
    final inWorkOrderCount = reports.where((r) => r.status == BreakdownReportStatus.inWorkOrder).length;
    final resolvedCount = reports.where((r) => r.status == BreakdownReportStatus.resolved).length;
    final rejectedCount = reports.where((r) => r.status == BreakdownReportStatus.rejected).length;
    final openCount = reportedCount + inWorkOrderCount;
    final highSeverityCount = reports.where((r) => r.severity == BreakdownSeverity.high).length;
    final resolutionRate = totalCount > 0 ? (resolvedCount / totalCount) * 100.0 : 0.0;

    // Fila 0: Título principal
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue(reportTitle.toUpperCase());
    titleCell.cellStyle = titleStyle;

    // Fila 1: Subtítulo
    final now = DateTime.now();
    final emissionStr = 'Emitido: ${_formatDate(now)} ${_formatTime(now)} | Alcance: ${dateFilterLabel ?? "Todo el histórico"} | Total registros: $totalCount';
    final subCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    subCell.value = TextCellValue(emissionStr);
    subCell.cellStyle = subTitleStyle;

    // Fila 3 y 4: Bloque KPI Resumen
    final kpis = [
      ('Total Incidencias', '$totalCount'),
      ('Abiertas / En Curso', '$openCount'),
      ('Reportadas', '$reportedCount'),
      ('En OT', '$inWorkOrderCount'),
      ('Resueltas', '$resolvedCount'),
      ('Rechazadas', '$rejectedCount'),
      ('Severidad Alta', '$highSeverityCount'),
      ('% Tasa Resolución', '${resolutionRate.toStringAsFixed(1)}%'),
    ];

    for (var k = 0; k < kpis.length; k++) {
      final (label, val) = kpis[k];
      final lblCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: k, rowIndex: 3));
      lblCell.value = TextCellValue(label);
      lblCell.cellStyle = kpiHeaderStyle;

      final valCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: k, rowIndex: 4));
      valCell.value = TextCellValue(val);
      valCell.cellStyle = kpiValueStyle;
    }

    // Fila 6: Cabeceras
    final headers = [
      ('Folio Avería', 18.0),
      ('Código Activo', 18.0),
      ('Nombre del Activo', 35.0),
      ('Área', 24.0),
      ('Severidad', 14.0),
      ('Estado', 16.0),
      ('Reportado Por', 25.0),
      ('Fecha Reporte', 18.0),
      ('OT Vinculada', 18.0),
      ('Resuelto Por', 25.0),
      ('Fecha Solución', 18.0),
      ('Motivo Rechazo', 35.0),
      ('Descripción del Fallo / Problema', 50.0),
    ];

    const startDataRow = 6;
    for (var col = 0; col < headers.length; col++) {
      final (title, width) = headers[col];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: startDataRow));
      cell.value = TextCellValue(title);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(col, width);
    }

    // Filas de datos
    for (var i = 0; i < reports.length; i++) {
      final r = reports[i];
      final rowIndex = startDataRow + 1 + i;
      final areaDisplay = areaNamesMap[r.areaId] ?? r.areaId;

      final rowData = [
        (TextCellValue(r.id), centerBoldStyle),
        (TextCellValue(r.assetId), centerStyle),
        (TextCellValue(r.assetName), textBoldStyle),
        (TextCellValue(areaDisplay), textStyle),
        (TextCellValue(r.severityLabel), centerStyle),
        (TextCellValue(r.statusLabel), centerBoldStyle),
        (TextCellValue(r.reportedByUserName), textStyle),
        (TextCellValue(r.reportedAt != null ? _formatDate(r.reportedAt!) : '-'), centerStyle),
        (TextCellValue(r.workOrderId ?? '-'), centerStyle),
        (TextCellValue(r.resolvedByUserName ?? '-'), textStyle),
        (TextCellValue(r.resolvedAt != null ? _formatDate(r.resolvedAt!) : '-'), centerStyle),
        (TextCellValue(r.rejectionReason ?? '-'), textStyle),
        (TextCellValue(r.description), textStyle),
      ];

      for (var c = 0; c < rowData.length; c++) {
        final (val, style) = rowData[c];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
        cell.value = val;
        cell.cellStyle = style;
      }
    }

    final fileBytes = excel.encode();
    return Uint8List.fromList(fileBytes ?? []);
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

