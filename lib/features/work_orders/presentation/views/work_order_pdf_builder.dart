import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/work_order.dart';

class WorkOrderPdfBuilder {
  // ─── Color palette (Grupo Macsa Corporate Blue & Accent Red) ───
  // Azul institucional extraído de los formatos oficiales de Grupo Macsa
  static const _primaryBlue = PdfColor(0.012, 0.255, 0.651); // #0341A6
  static const _primaryDarkBlue = PdfColor(0.0, 0.15, 0.45); // #002673
  static const _accentRed = PdfColor(0.753, 0.102, 0.102); // #C01A1A (# de Orden / Solicitud)
  static const _lightBlueBg = PdfColor(0.95, 0.97, 1.0); // #F2F6FC
  static const _headerBg = PdfColor(0.96, 0.97, 0.99); // Fondo sutil para cabeceras de tablas
  static const _borderColor = PdfColors.black;
  static const _outerBorderWidth = 1.0;

  // ─── Text styles ───
  static final _companyTitleStyle = pw.TextStyle(
    fontSize: 12.5,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.black,
  );
  static const _companySubtitleStyle = pw.TextStyle(
    fontSize: 7.5,
    color: PdfColors.grey800,
  );
  static final _docTitleStyle = pw.TextStyle(
    fontSize: 11.5,
    fontWeight: pw.FontWeight.bold,
    color: _primaryBlue,
    letterSpacing: 0.3,
  );
  static final _sectionHeaderStyle = pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.white,
    letterSpacing: 0.4,
  );
  static final _labelBold = pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.black,
  );
  static const _bodyText = pw.TextStyle(fontSize: 9);
  static const _bodyTextSmall = pw.TextStyle(fontSize: 8);
  static final _tableHeader = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.black,
  );
  static const _tableCell = pw.TextStyle(fontSize: 8.5);

  static String _cleanDescription(String raw) => TextSanitizer.cleanDescription(raw);

  static Future<Uint8List> buildPdf(
    WorkOrder order, {
    Uint8List? logoBytes,
  }) async {
    // Si no se proporcionaron los bytes del logo, intentar cargarlos del asset bundle
    if (logoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/images/macsa_logo.png');
        logoBytes = byteData.buffer.asUint8List();
      } catch (_) {
        logoBytes = null;
      }
    }

    final pdf = pw.Document();
    final createdAt = order.createdAt ?? DateTime.now();
    final printNow = DateTime.now();
    final printDateStr =
        '${printNow.day.toString().padLeft(2, '0')}/${printNow.month.toString().padLeft(2, '0')}/${printNow.year} '
        '${printNow.hour.toString().padLeft(2, '0')}:${printNow.minute.toString().padLeft(2, '0')}:${printNow.second.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════════════════════════
              // ENCABEZADO INSTITUCIONAL CON LOGO
              // ═══════════════════════════════════════
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Logo Grupo Macsa
                  if (logoBytes != null && logoBytes.isNotEmpty)
                    pw.Container(
                      width: 54,
                      height: 54,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(
                        pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  else
                    pw.Container(
                      width: 50,
                      height: 50,
                      margin: const pw.EdgeInsets.only(right: 12),
                      decoration: pw.BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'MACSA',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),

                  // Empresa + Domicilio + Título
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'GRUPO MARISCOS CANALES S.A DE C.V',
                          style: _companyTitleStyle,
                        ),
                        pw.SizedBox(height: 1.5),
                        pw.Text(
                          'CASERIO AGUA ZARCA, ALDEA DE LAURE, SAN LORENZO, VALLE',
                          style: _companySubtitleStyle,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'ORDEN DE TRABAJO DE MANTENIMIENTO',
                          style: _docTitleStyle,
                        ),
                      ],
                    ),
                  ),

                  // Lado Derecho: # Orden (rojo) + Tipo Mantenimiento + Fecha Impresión
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        printDateStr,
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 2),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: '# de Orden : ',
                              style: pw.TextStyle(
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.TextSpan(
                              text: order.correlativeNumber ?? order.id,
                              style: pw.TextStyle(
                                fontSize: 11.5,
                                fontWeight: pw.FontWeight.bold,
                                color: _accentRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      if (order.isPreventive &&
                          order.preventiveScheduleId != null &&
                          order.preventiveScheduleId!.isNotEmpty) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'Ref: ${order.preventiveScheduleId}',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ] else if (order.reportId != null &&
                          order.reportId!.isNotEmpty) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'Avería: #${order.reportId}',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),

              // Barra de Metadatos de Emisión (Fecha, Hora, Usuario, Área, Prioridad)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _lightBlueBg,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Fecha: ', style: _labelBold),
                        pw.Text(_formatDate(createdAt), style: _bodyText),
                        pw.SizedBox(width: 14),
                        pw.Text('Hora: ', style: _labelBold),
                        pw.Text(_formatFullTime(createdAt), style: _bodyText),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Text('Usuario: ', style: _labelBold),
                        pw.Text(
                          (order.createdByUserName ?? order.assignedTo ?? 'SISTEMA').toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryDarkBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════
              // CONTENIDO DE LA ORDEN DE TRABAJO
              // ═══════════════════════════════════════
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor, width: _outerBorderWidth),
                ),
                child: pw.Column(
                  children: [
                    // ═══════════════════════════════════════
                    // SECCIÓN 1: SOLICITANTE
                    // ═══════════════════════════════════════
                    _buildSectionHeader('ÁREA PARA SER LLENADA POR EL SOLICITANTE'),

                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Área / Equipo / Prioridad
                          pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                            columnWidths: const {
                              0: pw.FlexColumnWidth(1.2),
                              1: pw.FlexColumnWidth(1),
                            },
                            children: [
                              pw.TableRow(children: [
                                _fieldCell('Área Solicitante:', order.areaName ?? order.areaId ?? 'N/A'),
                                _fieldCell('Prioridad de Atención:', order.priorityLabel),
                              ]),
                              pw.TableRow(children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Equipo / Activo:', style: _labelBold),
                                      pw.SizedBox(height: 1.5),
                                      pw.Text(
                                        '${order.assetId} - ${order.assetName}',
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          fontWeight: pw.FontWeight.bold,
                                          color: _primaryDarkBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Clasificación:', style: _labelBold),
                                      pw.SizedBox(height: 1.5),
                                      pw.Text(
                                        order.isPreventive ? 'Preventivo' : 'Correctivo',
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          fontWeight: pw.FontWeight.bold,
                                          color: order.isPreventive
                                              ? _primaryBlue
                                              : const PdfColor(0.85, 0.40, 0.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ],
                          ),
                          pw.SizedBox(height: 8),

                          // Tipo de trabajo solicitado
                          pw.Text('Tipo de trabajo solicitado:', style: _labelBold),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            ),
                            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
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
                          pw.SizedBox(height: 8),

                          // Descripción de la falla
                          pw.Text(
                            'Descripción detalle de la falla y/o trabajo requerido:',
                            style: _labelBold,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Container(
                            width: double.infinity,
                            constraints: const pw.BoxConstraints(minHeight: 40),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            ),
                            padding: const pw.EdgeInsets.all(5),
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
                      padding: const pw.EdgeInsets.all(8),
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
                                  order.assignedStaffCount != null ? '${order.assignedStaffCount}' : 'N/D',
                                ),
                                _fieldCell(
                                  'Horas estimadas para la tarea:',
                                  order.estimatedHours != null
                                      ? '${order.estimatedHours} hrs'
                                      : 'N/D',
                                ),
                              ]),
                            ],
                          ),
                          pw.SizedBox(height: 8),

                          // Tabla de materiales con encabezado en Azul Corporativo
                          pw.Text(
                            'Material, Equipo, Herramienta y/o Refacciones a utilizar:',
                            style: _labelBold,
                          ),
                          pw.SizedBox(height: 3),
                          _buildMaterialsTable(order.materials),
                          pw.SizedBox(height: 8),

                          // Trabajo realizado
                          pw.Text(
                            'Descripción detallada del trabajo realizado, recomendaciones de uso y observaciones:',
                            style: _labelBold,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Container(
                            width: double.infinity,
                            constraints: const pw.BoxConstraints(minHeight: 45),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            ),
                            padding: const pw.EdgeInsets.all(5),
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
                      padding: const pw.EdgeInsets.all(8),
                      child: _buildComplianceTable(order),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ═══════════════════════════════════════
              // FIRMAS INSTITUCIONALES (JEFE DE ÁREA / EJECUTÓ / APROBÓ)
              // ═══════════════════════════════════════
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSignatureBox(
                    label: 'JEFE DE ÁREA',
                    roleSublabel: 'Área donde se realizó el trabajo',
                    name: order.areaHeadResponsible,
                    width: 160,
                  ),
                  _buildSignatureBox(
                    label: 'EJECUTÓ',
                    roleSublabel: 'Responsable Mantenimiento',
                    name: order.maintenanceResponsible ?? order.assignedTo,
                    width: 160,
                  ),
                  _buildSignatureBox(
                    label: 'APROBÓ',
                    roleSublabel: 'Jefatura de Mantenimiento',
                    name: order.maintenanceHeadResponsible,
                    width: 160,
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Text('Copia Archivo', style: _bodyTextSmall),
                      pw.SizedBox(width: 12),
                      pw.Text('Copia Sistema', style: _bodyTextSmall),
                    ],
                  ),
                  pw.Text('2 Edición 2026', style: _bodyTextSmall),
                  pw.Text(
                    'REG.GMC-MTN-001',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryBlue,
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
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: pw.Center(
        child: pw.Text(title, style: _sectionHeaderStyle),
      ),
    );
  }

  // ─── Helper: Field cell for tables ───
  static pw.Widget _fieldCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: _labelBold),
          pw.SizedBox(height: 1.5),
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
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
            color: PdfColors.white,
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
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
      ],
    );
  }

  // ─── Helper: Materials table con diseño sobrio original ───
  static pw.Widget _buildMaterialsTable(List<WorkOrderMaterial> materials) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerBg),
        children: [
          _tableCellPad('N°', isHeader: true, align: pw.TextAlign.center),
          _tableCellPad('Material, Equipo, Herramienta y/o Refacción', isHeader: true),
          _tableCellPad('Unidad', isHeader: true, align: pw.TextAlign.center),
          _tableCellPad('Cantidad', isHeader: true, align: pw.TextAlign.center),
        ],
      ),
    ];

    final rowCount = materials.length < 4 ? 4 : materials.length;
    for (int i = 0; i < rowCount; i++) {
      final mat = i < materials.length ? materials[i] : null;
      rows.add(
        pw.TableRow(
          children: [
            _tableCellPad('${i + 1}', align: pw.TextAlign.center),
            _tableCellPad(mat?.description ?? ''),
            _tableCellPad(mat?.unit ?? '', align: pw.TextAlign.center),
            _tableCellPad(mat != null ? '${mat.quantity}' : '', align: pw.TextAlign.center),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FlexColumnWidth(5),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
      },
      children: rows,
    );
  }

  // ─── Helper: Compliance table con diseño sobrio original ───
  static pw.Widget _buildComplianceTable(WorkOrder order) {
    final isCompletedStr = order.isCompleted == null
        ? ''
        : (order.isCompleted! ? 'Sí' : 'No');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(4),
        3: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            _tableCellPad('N°', isHeader: true, align: pw.TextAlign.center),
            _tableCellPad('¿Cumplimiento\nde la tarea?', isHeader: true, align: pw.TextAlign.center),
            _tableCellPad('En caso de no haber cumplido, anotar el motivo', isHeader: true),
            _tableCellPad('Fecha de\nReprogramación', isHeader: true, align: pw.TextAlign.center),
          ],
        ),
        pw.TableRow(
          children: [
            _tableCellPad('1', align: pw.TextAlign.center),
            _tableCellPad(isCompletedStr, align: pw.TextAlign.center),
            _tableCellPad(order.unfulfillmentReason ?? ''),
            _tableCellPad(_formatDate(order.reprogramDate), align: pw.TextAlign.center),
          ],
        ),
      ],
    );
  }

  // ─── Helper: Table cell with padding ───
  static pw.Widget _tableCellPad(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: isHeader ? _tableHeader : _tableCell,
      ),
    );
  }

  // ─── Helper: Signature box idéntico al formato oficial Macsa ───
  static pw.Widget _buildSignatureBox({
    required String label,
    String? roleSublabel,
    String? name,
    double width = 160,
  }) {
    return pw.Container(
      width: width,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            height: 18,
            alignment: pw.Alignment.bottomCenter,
            child: pw.Text(
              name != null && name.trim().isNotEmpty ? name.toUpperCase() : '',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(
            width: width,
            height: 1,
            color: PdfColors.black,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
              letterSpacing: 0.5,
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (roleSublabel != null && roleSublabel.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              roleSublabel,
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _formatFullTime(DateTime dt) {
    const weekdays = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$weekday ${dt.day} de $month de ${dt.year} $hh:$mm';
  }
}
