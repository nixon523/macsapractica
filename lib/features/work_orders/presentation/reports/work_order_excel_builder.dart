import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/work_order.dart';

/// Generador de libros nativos Microsoft Excel (.xlsx) para Órdenes de Trabajo de Grupo Macsa.
/// Incluye resumen ejecutivo en cabecera, desglose detallado con formato formal y hoja
/// de materiales / refacciones vinculadas.
class WorkOrderExcelBuilder {
  static Future<Uint8List> buildWorkOrdersExcel({
    required List<WorkOrder> workOrders,
    Map<String, String> areaNamesMap = const {},
    String reportTitle = 'Reporte Consolidado de Órdenes de Trabajo - Grupo Macsa',
    String? dateFilterLabel,
  }) async {
    final excel = Excel.createExcel();

    // ─────────────────────────────────────────────────────────────
    // Hoja 1: Órdenes de Trabajo
    // ─────────────────────────────────────────────────────────────
    final defaultSheet = excel.getDefaultSheet();
    const sheetName = 'Órdenes de Trabajo';
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

    final numberStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Métricas para bloque KPI superior
    final totalCount = workOrders.length;
    final pendingCount = workOrders.where((o) => o.status == WorkOrderStatus.pending).length;
    final inProgressCount = workOrders.where((o) => o.status == WorkOrderStatus.inProgress).length;
    final completedCount = workOrders.where((o) => o.status == WorkOrderStatus.completed).length;
    final cancelledCount = workOrders.where((o) => o.status == WorkOrderStatus.cancelled).length;
    final compliancePct = totalCount > 0 ? (completedCount / totalCount) * 100.0 : 0.0;

    double totalEstHours = 0.0;
    double totalActHours = 0.0;
    for (final o in workOrders) {
      totalEstHours += (o.estimatedHours ?? 0.0);
      totalActHours += (o.actualHours ?? 0.0);
    }

    // Fila 0: Título principal
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue(reportTitle.toUpperCase());
    titleCell.cellStyle = titleStyle;

    // Fila 1: Subtítulo de periodo y emisión
    final now = DateTime.now();
    final emissionStr = 'Emitido: ${_formatDate(now)} ${_formatTime(now)} | Alcance: ${dateFilterLabel ?? "Todo el histórico"} | Total registros: $totalCount';
    final subCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    subCell.value = TextCellValue(emissionStr);
    subCell.cellStyle = subTitleStyle;

    // Fila 3 y 4: Bloque KPI Resumen
    final kpis = [
      ('Total OTs', '$totalCount'),
      ('Pendientes', '$pendingCount'),
      ('En Progreso', '$inProgressCount'),
      ('Completadas', '$completedCount'),
      ('Canceladas', '$cancelledCount'),
      ('% Cumplimiento', '${compliancePct.toStringAsFixed(1)}%'),
      ('Horas Estimadas', '${totalEstHours.toStringAsFixed(1)} h'),
      ('Horas Reales', '${totalActHours.toStringAsFixed(1)} h'),
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

    // Fila 6: Cabeceras de la tabla principal
    final headers = [
      ('Folio OT', 18.0),
      ('Código Activo', 18.0),
      ('Nombre del Activo', 35.0),
      ('Área', 24.0),
      ('Clasificación', 18.0),
      ('Tipos de Trabajo', 25.0),
      ('Prioridad', 14.0),
      ('Estado', 16.0),
      ('Técnico Asignado', 25.0),
      ('Horas Estimadas', 16.0),
      ('Horas Reales', 16.0),
      ('Desviación Horas', 16.0),
      ('Fecha Programada', 18.0),
      ('Fecha Creación', 18.0),
      ('Descripción del Trabajo', 45.0),
      ('Trabajo Realizado / Cierre', 45.0),
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
    for (var i = 0; i < workOrders.length; i++) {
      final o = workOrders[i];
      final rowIndex = startDataRow + 1 + i;
      final areaDisplay = o.areaName ?? areaNamesMap[o.areaId] ?? o.areaId ?? 'No asignada';
      final classification = o.isPreventive ? 'Preventivo' : (o.isCorrective ? 'Correctivo' : 'General');
      final workTypes = o.requestedWorkTypes.isNotEmpty ? o.requestedWorkTypes.join(', ') : '-';
      final estH = o.estimatedHours ?? 0.0;
      final actH = o.actualHours ?? 0.0;
      final desvH = actH - estH;

      final rowData = [
        (TextCellValue(o.displayCorrelative), centerBoldStyle),
        (TextCellValue(o.assetId), centerStyle),
        (TextCellValue(o.assetName), textBoldStyle),
        (TextCellValue(areaDisplay), textStyle),
        (TextCellValue(classification), centerStyle),
        (TextCellValue(workTypes), textStyle),
        (TextCellValue(o.priorityLabel), centerStyle),
        (TextCellValue(o.statusLabel), centerBoldStyle),
        (TextCellValue(o.assignedTo ?? 'Sin asignar'), textStyle),
        (DoubleCellValue(estH), numberStyle),
        (DoubleCellValue(actH), numberStyle),
        (DoubleCellValue(double.parse(desvH.toStringAsFixed(2))), numberStyle),
        (TextCellValue(o.scheduledDate != null ? _formatDate(o.scheduledDate!) : '-'), centerStyle),
        (TextCellValue(o.createdAt != null ? _formatDate(o.createdAt!) : '-'), centerStyle),
        (TextCellValue(o.description), textStyle),
        (TextCellValue(o.workDoneDescription ?? '-'), textStyle),
      ];

      for (var c = 0; c < rowData.length; c++) {
        final (val, style) = rowData[c];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
        cell.value = val;
        cell.cellStyle = style;
      }
    }

    // ─────────────────────────────────────────────────────────────
    // Hoja 2: Materiales y Repuestos Utilizados
    // ─────────────────────────────────────────────────────────────
    const matSheetName = 'Materiales y Repuestos';
    final Sheet matSheet = excel[matSheetName];

    final matHeaders = [
      ('Folio OT', 18.0),
      ('Código Activo', 18.0),
      ('Nombre del Activo', 32.0),
      ('Descripción del Material / Repuesto', 40.0),
      ('Cantidad', 14.0),
      ('Unidad', 12.0),
    ];

    for (var col = 0; col < matHeaders.length; col++) {
      final (title, width) = matHeaders[col];
      final cell = matSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(title);
      cell.cellStyle = headerStyle;
      matSheet.setColumnWidth(col, width);
    }

    var matRow = 1;
    for (final o in workOrders) {
      for (final m in o.materials) {
        final rowVals = [
          (TextCellValue(o.displayCorrelative), centerBoldStyle),
          (TextCellValue(o.assetId), centerStyle),
          (TextCellValue(o.assetName), textStyle),
          (TextCellValue(m.description), textStyle),
          (DoubleCellValue(m.quantity), numberStyle),
          (TextCellValue(m.unit), centerStyle),
        ];

        for (var c = 0; c < rowVals.length; c++) {
          final (val, style) = rowVals[c];
          final cell = matSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: matRow));
          cell.value = val;
          cell.cellStyle = style;
        }
        matRow++;
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

