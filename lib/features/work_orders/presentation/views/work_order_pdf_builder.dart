import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/work_order.dart';

class WorkOrderPdfBuilder {
  // ─── Color palette (Grupo Macsa Corporate Blue & Slate) ───
  static const _primaryBlue = PdfColor(0.0, 0.33, 0.65); // #0055A5
  static const _primaryDarkBlue = PdfColor(0.0, 0.24, 0.49); // #003E7E
  static const _lightBlueBg = PdfColor(0.94, 0.96, 0.99); // #F0F6FC
  static const _headerBg = PdfColor(0.96, 0.97, 0.99);
  static const _borderColor = PdfColors.black;
  static const _outerBorderWidth = 1.5;

  // ─── Text styles ───
  static final _titleStyle = pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.black,
  );
  static final _correlativeStyle = pw.TextStyle(
    fontSize: 13,
    fontWeight: pw.FontWeight.bold,
    color: _primaryDarkBlue,
  );
  static final _sectionHeaderStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.white,
    letterSpacing: 0.3,
  );
  static final _labelBold = pw.TextStyle(
    fontSize: 9.5,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.black,
  );
  static const _bodyText = pw.TextStyle(fontSize: 9.5);
  static const _bodyTextSmall = pw.TextStyle(fontSize: 8.5);
  static final _tableHeader = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
  );
  static const _tableCell = pw.TextStyle(fontSize: 8.5);

  static String _cleanDescription(String raw) => TextSanitizer.cleanDescription(raw);

  static Future<Uint8List> buildPdf(WorkOrder order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════════════════════════
              // ENCABEZADO PRINCIPAL
              // ═══════════════════════════════════════
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor, width: _outerBorderWidth),
                ),
                child: pw.Column(
                  children: [
                    // Título + Correlativo + Clasificación
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      color: _lightBlueBg,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('ORDEN DE TRABAJO DE MANTENIMIENTO', style: _titleStyle),
                              pw.SizedBox(height: 3),
                              pw.Row(
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: pw.BoxDecoration(
                                      color: order.isPreventive
                                          ? _primaryBlue
                                          : const PdfColor(0.85, 0.40, 0.0),
                                      borderRadius: pw.BorderRadius.circular(2),
                                    ),
                                    child: pw.Text(
                                      order.isPreventive
                                          ? 'MANTENIMIENTO PREVENTIVO'
                                          : 'MANTENIMIENTO CORRECTIVO',
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (order.isPreventive &&
                                      order.preventiveScheduleId != null &&
                                      order.preventiveScheduleId!.isNotEmpty) ...[
                                    pw.SizedBox(width: 6),
                                    pw.Text(
                                      'Ref: ${order.preventiveScheduleId}',
                                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                                    ),
                                  ] else if (order.reportId != null &&
                                      order.reportId!.isNotEmpty) ...[
                                    pw.SizedBox(width: 6),
                                    pw.Text(
                                      'Avería: #${order.reportId}',
                                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              border: pw.Border.all(color: _primaryBlue, width: 1.2),
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              order.correlativeNumber ?? order.id,
                              style: _correlativeStyle,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ═══════════════════════════════════════
                    // SECCIÓN 1: SOLICITANTE
                    // ═══════════════════════════════════════
                    _buildSectionHeader('ÁREA PARA SER LLENADA POR EL SOLICITANTE'),

                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Fecha / Área / Equipos / Prioridad
                          pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                            columnWidths: const {
                              0: pw.FlexColumnWidth(1),
                              1: pw.FlexColumnWidth(1),
                            },
                            children: [
                              pw.TableRow(children: [
                                _fieldCell('Fecha:', _formatDate(order.createdAt ?? DateTime.now())),
                                _fieldCell('Área:', order.areaName ?? order.areaId ?? 'N/A'),
                              ]),
                              pw.TableRow(children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Equipos:', style: _labelBold),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        '${order.assetId} - ${order.assetName}',
                                        style: _bodyText,
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text('Prioridad:', style: _labelBold),
                                          pw.SizedBox(height: 2),
                                          pw.Text(order.priorityLabel, style: _bodyText),
                                        ],
                                      ),
                                      pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text('Clasificación:', style: _labelBold),
                                          pw.SizedBox(height: 2),
                                          pw.Text(
                                            order.isPreventive ? 'Preventivo' : 'Correctivo',
                                            style: pw.TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: pw.FontWeight.bold,
                                              color: order.isPreventive
                                                  ? _primaryBlue
                                                  : const PdfColor(0.85, 0.40, 0.0),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ],
                          ),
                          pw.SizedBox(height: 10),

                          // Tipo de trabajo solicitado
                          pw.Text('Tipo de trabajo solicitado:', style: _labelBold),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            ),
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCheckBox('Eléctrico', order.requestedWorkTypes.contains('electric')),
                                _buildCheckBox('Mecánico', order.requestedWorkTypes.contains('mechanical')),
                                _buildCheckBox('Soldadura', order.requestedWorkTypes.contains('welding') || order.requestedWorkTypes.contains('soldadura')),
                                _buildCheckBox('Refrigeración', order.requestedWorkTypes.contains('refrigeration')),
                                _buildCheckBox('Plomería', order.requestedWorkTypes.contains('plumbing')),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),

                          // Descripción de la falla
                          pw.Text(
                            'Descripción detalle de la falla y/o trabajo requerido:',
                            style: _labelBold,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            width: double.infinity,
                            constraints: const pw.BoxConstraints(minHeight: 45),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            ),
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_cleanDescription(order.description), style: _bodyText),
                          ),
                        ],
                      ),
                    ),

                    // ═══════════════════════════════════════
                    // SECCIÓN 2: MANTENIMIENTO
                    // ═══════════════════════════════════════
                    _buildSectionHeader('ÁREA PARA SER LLENADA POR PERSONAL DE MANTENIMIENTO'),

                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Personal / Horas
                          pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                            columnWidths: const {
                              0: pw.FlexColumnWidth(1),
                              1: pw.FlexColumnWidth(1),
                            },
                            children: [
                              pw.TableRow(children: [
                                _fieldCell(
                                  'Cantidad de personal asignado:',
                                  '${order.assignedStaffCount ?? ''}',
                                ),
                                _fieldCell(
                                  'Horas para realizar tarea:',
                                  order.estimatedHours != null
                                      ? '${order.estimatedHours} hrs'
                                      : '',
                                ),
                              ]),
                            ],
                          ),
                          pw.SizedBox(height: 10),

                          // Tabla de materiales
                          pw.Text(
                            'Material, Equipo, Herramienta y/o Refacciones a utilizar:',
                            style: _labelBold,
                          ),
                          pw.SizedBox(height: 4),
                          _buildMaterialsTable(order.materials),
                          pw.SizedBox(height: 10),

                          // Trabajo realizado
                          pw.Text(
                            'Descripción detallada del trabajo realizado, recomendaciones de uso y observaciones:',
                            style: _labelBold,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            width: double.infinity,
                            constraints: const pw.BoxConstraints(minHeight: 50),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            ),
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              _cleanDescription(order.workDoneDescription ?? ''),
                              style: _bodyText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ═══════════════════════════════════════
                    // SECCIÓN 3: CUMPLIMIENTO
                    // ═══════════════════════════════════════
                    _buildSectionHeader('CUMPLIMIENTO Y/O REPROGRAMACIÓN'),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: _buildComplianceTable(order),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ═══════════════════════════════════════
              // FIRMAS
              // ═══════════════════════════════════════
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildSignatureBox(
                    label: 'Responsable de Calidad\n(ACC / HACCP)',
                    name: order.accHaccpResponsible,
                  ),
                  _buildSignatureBox(
                    label: 'Resp. Mantenimiento\n(Ejecutor)',
                    name: order.maintenanceResponsible,
                  ),
                  _buildSignatureBox(
                    label: 'Jefe de Área',
                    name: order.areaHeadResponsible,
                  ),
                  _buildSignatureBox(
                    label: 'Jefe de\nMantenimiento',
                    name: order.maintenanceHeadResponsible,
                  ),
                ],
              ),

              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Copia Archivo', style: _bodyTextSmall),
                      pw.Text('Copia Sistema', style: _bodyTextSmall),
                    ],
                  ),
                  pw.Text('2 Edición 2026', style: _bodyTextSmall),
                  pw.Text(
                    'REG.GMC-MTN-001',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── Helper: Section header bar ───
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      color: _primaryBlue,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: pw.Center(
        child: pw.Text(title, style: _sectionHeaderStyle),
      ),
    );
  }

  // ─── Helper: Field cell for tables ───
  static pw.Widget _fieldCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: _labelBold),
          pw.SizedBox(height: 2),
          pw.Text(value, style: _bodyText),
        ],
      ),
    );
  }

  // ─── Helper: Checkbox ───
  static pw.Widget _buildCheckBox(String label, bool checked) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 11,
          height: 11,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
            color: checked ? PdfColors.white : PdfColors.white,
          ),
          alignment: pw.Alignment.center,
          child: checked
              ? pw.Text(
                  'X',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                )
              : pw.SizedBox(),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9.5)),
      ],
    );
  }

  // ─── Helper: Materials table ───
  static pw.Widget _buildMaterialsTable(List<WorkOrderMaterial> materials) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerBg),
        children: [
          _tableCellPad('N°', isHeader: true),
          _tableCellPad('Material, Equipo, Herramienta y/o Refacción', isHeader: true),
          _tableCellPad('Cantidad', isHeader: true),
        ],
      ),
    ];

    final rowCount = materials.length < 4 ? 4 : materials.length;
    for (int i = 0; i < rowCount; i++) {
      final mat = i < materials.length ? materials[i] : null;
      rows.add(
        pw.TableRow(
          children: [
            _tableCellPad('${i + 1}'),
            _tableCellPad(mat?.description ?? ''),
            _tableCellPad(mat != null ? '${mat.quantity} ${mat.unit}' : ''),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(5),
        2: pw.FlexColumnWidth(1.2),
      },
      children: rows,
    );
  }

  // ─── Helper: Compliance table ───
  static pw.Widget _buildComplianceTable(WorkOrder order) {
    final isCompletedStr = order.isCompleted == null
        ? ''
        : (order.isCompleted! ? 'Sí' : 'No');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(4),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            _tableCellPad('N°', isHeader: true),
            _tableCellPad('¿Cumplimiento\nde la tarea?', isHeader: true),
            _tableCellPad('En caso de no haber cumplido, anotar el motivo', isHeader: true),
            _tableCellPad('Fecha de\nReprogramación', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _tableCellPad('1'),
            _tableCellPad(isCompletedStr),
            _tableCellPad(order.unfulfillmentReason ?? ''),
            _tableCellPad(_formatDate(order.reprogramDate)),
          ],
        ),
      ],
    );
  }

  // ─── Helper: Table cell with padding ───
  static pw.Widget _tableCellPad(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: isHeader ? _tableHeader : _tableCell,
      ),
    );
  }

  // ─── Helper: Signature box ───
  static pw.Widget _buildSignatureBox({required String label, String? name}) {
    return pw.Container(
      width: 125,
      child: pw.Column(
        children: [
          pw.SizedBox(height: 30),
          pw.Container(
            width: 125,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.black, width: 1),
              ),
            ),
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Column(
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (name != null && name.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    name,
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
