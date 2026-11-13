import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/work_order.dart';

/// Generador de Reporte Consolidado de Órdenes de Trabajo en PDF
/// Diseñado con estética ejecutiva institucional de Grupo Macsa,
/// métricas en tarjetas, tabla paginada y bloque formal de validación y firmas.
class WorkOrderReportPdfBuilder {
  static const _primaryBlue = PdfColor(0.0, 0.33, 0.65); // #0055A5
  static const _darkBlue = PdfColor(0.08, 0.22, 0.38);
  static const _lightBlueBg = PdfColor(0.94, 0.96, 0.99);
  static const _tableHeaderBg = PdfColor(0.92, 0.95, 0.98);
  static const _zebraBg = PdfColor(0.98, 0.99, 1.0);
  static const _borderColor = PdfColor(0.80, 0.84, 0.90);

  static Future<Uint8List> buildPdf({
    required List<WorkOrder> workOrders,
    PdfPageFormat pageFormat = PdfPageFormat.letter,
    String title = 'REPORTE CONSOLIDADO DE ÓRDENES DE TRABAJO',
    String? subtitle,
    String? dateFilterLabel,
    String? areaFilterLabel,
    String issuedByName = 'Administración de Mantenimiento',
  }) async {
    final pdf = pw.Document();

    final totalCount = workOrders.length;
    final pendingCount = workOrders.where((o) => o.status == WorkOrderStatus.pending).length;
    final inProgressCount = workOrders.where((o) => o.status == WorkOrderStatus.inProgress).length;
    final completedCount = workOrders.where((o) => o.status == WorkOrderStatus.completed).length;
    final cancelledCount = workOrders.where((o) => o.status == WorkOrderStatus.cancelled).length;
    final compliancePct = totalCount > 0 ? (completedCount / totalCount) * 100.0 : 0.0;

    double totalActHours = 0.0;
    for (final o in workOrders) {
      totalActHours += (o.actualHours ?? 0.0);
    }

    final now = DateTime.now();
    final nowStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final isPortrait = pageFormat.width < pageFormat.height;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: isPortrait
            ? const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16)
            : const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 38,
                        height: 38,
                        decoration: pw.BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'M',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'GRUPO MACSA',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: _darkBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.Text(
                            'Sistema de Gestión de Mantenimiento Preventivo y Correctivo',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Página ${context.pageNumber} de ${context.pagesCount}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Emisión: $nowStr',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: _primaryBlue, thickness: 1.5),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Divider(color: _borderColor, thickness: 0.8),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Documento emitido por: $issuedByName | Grupo Macsa División Industrial',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'REG.GMC-MTN-REP-01',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _primaryBlue),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Banner de Título y Filtros
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: _lightBlueBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: _borderColor),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _darkBlue,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        pw.Text(
                          subtitle,
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      _buildFilterBadge('Periodo', dateFilterLabel ?? 'Histórico'),
                      pw.SizedBox(width: 8),
                      _buildFilterBadge('Área', areaFilterLabel ?? 'Todas'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Tarjetas KPI de Resumen
            pw.Row(
              children: [
                _buildKpiCard('Total OTs', '$totalCount', _darkBlue),
                pw.SizedBox(width: 8),
                _buildKpiCard('Pendientes', '$pendingCount', const PdfColor(0.85, 0.45, 0.0)),
                pw.SizedBox(width: 8),
                _buildKpiCard('En Progreso', '$inProgressCount', _primaryBlue),
                pw.SizedBox(width: 8),
                _buildKpiCard('Completadas', '$completedCount', const PdfColor(0.12, 0.60, 0.30)),
                pw.SizedBox(width: 8),
                _buildKpiCard('Canceladas', '$cancelledCount', PdfColors.grey600),
                pw.SizedBox(width: 8),
                _buildKpiCard('% Cumplimiento', '${compliancePct.toStringAsFixed(1)}%', const PdfColor(0.12, 0.60, 0.30)),
                pw.SizedBox(width: 8),
                _buildKpiCard('Horas Invertidas', '${totalActHours.toStringAsFixed(1)} h', _darkBlue),
              ],
            ),
            pw.SizedBox(height: 12),

            // Tabla de Órdenes de Trabajo
            if (workOrders.isEmpty)
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(30),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'No se encontraron órdenes de trabajo para los criterios seleccionados.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              )
            else
              _buildOrdersTable(workOrders, isPortrait: isPortrait),

            pw.SizedBox(height: 20),

            // Bloque de Firmas de Validación
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSignatureBox('Responsable de Emisión / Ejecución', issuedByName),
                _buildSignatureBox('Jefatura de Mantenimiento', 'Revisión y Aprobación'),
                _buildSignatureBox('Supervisión de Operaciones', 'Conformidad de Planta'),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildFilterBadge(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkBlue)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _borderColor),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              maxLines: 1,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildOrdersTable(List<WorkOrder> orders, {bool isPortrait = false}) {
    const tableHeaders = [
      'Folio OT',
      'Activo / Equipo',
      'Área',
      'Tipo / Clasif.',
      'Prioridad',
      'Estado',
      'Responsable',
      'Horas (Est/Real)',
      'Fecha Prog.',
      'Descripción / Fallo',
    ];

    final columnWidths = isPortrait
        ? const <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(48),
            1: pw.FlexColumnWidth(2.0),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.2),
            4: pw.FixedColumnWidth(40),
            5: pw.FixedColumnWidth(46),
            6: pw.FlexColumnWidth(1.3),
            7: pw.FixedColumnWidth(45),
            8: pw.FixedColumnWidth(45),
            9: pw.FlexColumnWidth(2.2),
          }
        : const <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(65),
            1: pw.FlexColumnWidth(2.2),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(1.3),
            4: pw.FixedColumnWidth(48),
            5: pw.FixedColumnWidth(55),
            6: pw.FlexColumnWidth(1.4),
            7: pw.FixedColumnWidth(55),
            8: pw.FixedColumnWidth(55),
            9: pw.FlexColumnWidth(2.5),
          };

    final headerFontSize = isPortrait ? 6.5 : 7.5;

    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: columnWidths,
      children: [
        // Fila Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _tableHeaderBg),
          children: tableHeaders.map((h) {
            return pw.Padding(
              padding: pw.EdgeInsets.symmetric(
                horizontal: isPortrait ? 2 : 4,
                vertical: isPortrait ? 4 : 5,
              ),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkBlue,
                ),
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),

        // Filas de Datos
        ...orders.asMap().entries.map((entry) {
          final index = entry.key;
          final o = entry.value;
          final isZebra = index.isOdd;
          final bgColor = isZebra ? _zebraBg : PdfColors.white;

          final estH = (o.estimatedHours ?? 0).toStringAsFixed(1);
          final actH = (o.actualHours ?? 0).toStringAsFixed(1);
          final hoursText = '$estH / $actH h';
          final progDate = o.scheduledDate != null
              ? '${o.scheduledDate!.day}/${o.scheduledDate!.month}/${o.scheduledDate!.year}'
              : '-';

          final cleanDesc = TextSanitizer.cleanDescription(o.description);

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bgColor),
            children: [
              // Folio
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  o.displayCorrelative,
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _darkBlue),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Activo
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      o.assetName,
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      maxLines: 2,
                    ),
                    pw.Text(
                      o.assetId,
                      style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              // Área
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  o.areaName ?? o.areaId ?? '-',
                  style: const pw.TextStyle(fontSize: 7),
                  maxLines: 2,
                ),
              ),
              // Tipo / Clasif.
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  o.isPreventive
                      ? 'Preventivo'
                      : (o.isCorrective ? 'Correctivo' : (o.requestedWorkTypes.firstOrNull ?? 'General')),
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
              // Prioridad
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _buildPriorityChip(o.priority),
              ),
              // Estado
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _buildStatusChip(o.status),
              ),
              // Responsable
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  o.assignedTo ?? 'Sin asignar',
                  style: const pw.TextStyle(fontSize: 7),
                  maxLines: 1,
                ),
              ),
              // Horas
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  hoursText,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Fecha Prog.
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  progDate,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              // Descripción
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  cleanDesc,
                  style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800),
                  maxLines: 2,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildStatusChip(WorkOrderStatus status) {
    final (label, color) = switch (status) {
      WorkOrderStatus.pending => ('Pendiente', const PdfColor(0.85, 0.45, 0.0)),
      WorkOrderStatus.inProgress => ('En Curso', _primaryBlue),
      WorkOrderStatus.completed => ('Completada', const PdfColor(0.12, 0.60, 0.30)),
      WorkOrderStatus.cancelled => ('Cancelada', PdfColors.grey600),
    };

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 6.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildPriorityChip(WorkOrderPriority priority) {
    final (label, color) = switch (priority) {
      WorkOrderPriority.high => ('Alta', const PdfColor(0.85, 0.15, 0.15)),
      WorkOrderPriority.medium => ('Media', const PdfColor(0.90, 0.55, 0.0)),
      WorkOrderPriority.low => ('Baja', const PdfColor(0.15, 0.55, 0.30)),
    };

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 6.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildSignatureBox(String title, String subtitle) {
    return pw.Container(
      width: 170,
      child: pw.Column(
        children: [
          pw.Container(
            height: 38,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkBlue),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}

