import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../app/di/get_it.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/asset.dart';

/// Generador de Ficha Técnica y Hoja de Vida Individual en PDF
class AssetSinglePdfBuilder {
  static const _brandDark = PdfColor(0.08, 0.22, 0.38); // Azul Macsa oscuro
  static const _brandPrimary = PdfColor(0.12, 0.40, 0.65); // Azul Macsa medio
  static const _brandLight = PdfColor(0.92, 0.96, 1.00);
  static const _headerBg = PdfColor(0.95, 0.95, 0.95);
  static const _borderColor = PdfColors.grey400;

  static Future<Uint8List> buildPdf({
    required Asset asset,
    PdfPageFormat pageFormat = PdfPageFormat.letter,
    String? areaName,
    List<Asset> subComponents = const [],
    DateTime? startDate,
    DateTime? endDate,
    String issuedByName = 'Administrador de Sistema',
  }) async {
    final pdf = pw.Document();

    // Imagen técnica si existe
    pw.MemoryImage? assetImage;
    if (asset.imageData != null && asset.imageData!.trim().isNotEmpty) {
      final imgStr = asset.imageData!.trim();
      if (imgStr.startsWith('http://') ||
          imgStr.startsWith('https://') ||
          imgStr.startsWith('/image') ||
          imgStr.startsWith('image/')) {
        try {
          final apiClient = getIt<ApiClient>();
          final fullUrl = apiClient.resolveImageUrl(imgStr);
          final res = await http.get(Uri.parse(fullUrl));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            assetImage = pw.MemoryImage(res.bodyBytes);
          }
        } catch (_) {
          assetImage = null;
        }
      } else {
        try {
          String base64Str = imgStr;
          if (base64Str.contains(',')) {
            base64Str = base64Str.split(',').last;
          }
          final bytes = base64Decode(base64Str);
          assetImage = pw.MemoryImage(bytes);
        } catch (_) {
          assetImage = null;
        }
      }
    }

    // Filtrar historial según rango de fechas si se especifica
    final filteredHistory = asset.statusHistory.where((p) {
      if (startDate != null && p.startedAt.isBefore(startDate)) return false;
      if (endDate != null && p.endedAt != null && p.endedAt!.isAfter(endDate)) return false;
      return true;
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        header: (context) => _buildHeader(asset, areaName),
        footer: (context) => _buildFooter(context, issuedByName),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 10),

            // 1. Resumen y Datos Generales
            _buildSectionHeader('1. DATOS GENERALES DEL ACTIVO'),
            _buildGeneralInfo(asset, areaName, assetImage),
            pw.SizedBox(height: 12),

            // 2. Especificaciones y Atributos Dinámicos
            if (asset.dynamicAttributes.isNotEmpty) ...[
              _buildSectionHeader('2. ESPECIFICACIONES TÉCNICAS'),
              _buildDynamicAttributesTable(asset.dynamicAttributes),
              pw.SizedBox(height: 12),
            ],

            // 3. Indicadores de Desempeño y Disponibilidad
            _buildSectionHeader('3. INDICADORES DE DISPONIBILIDAD Y OPERABILIDAD'),
            _buildKpisSection(asset, startDate, endDate),
            pw.SizedBox(height: 12),

            // 4. Componentes y Sub-equipos
            if (subComponents.isNotEmpty) ...[
              _buildSectionHeader('4. SUB-EQUIPOS Y PARTES DEPENDIENTES (${subComponents.length})'),
              _buildSubComponentsTable(subComponents),
              pw.SizedBox(height: 12),
            ],

            // 5. Historial de Estados y Paradas
            _buildSectionHeader(
              filteredHistory.isEmpty
                  ? '5. BITÁCORA DE ESTADOS'
                  : '5. BITÁCORA DE ESTADOS (${filteredHistory.length} REGISTROS)',
            ),
            _buildStatusHistoryTable(filteredHistory),
            pw.SizedBox(height: 20),

            // 6. Firmas de Validación
            _buildSignaturesSection(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(Asset asset, String? areaName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
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
                'GRUPO MACSA',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandDark,
                ),
              ),
              pw.Text(
                'SISTEMA DE GESTIÓN DE MANTENIMIENTO (CMMS)',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: _brandLight,
              border: pw.Border.all(color: _brandPrimary),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'FICHA TÉCNICA: ${asset.id}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _brandDark,
              ),
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
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Emitido por: $issuedByName | Fecha: $dateStr',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _brandDark,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const pw.EdgeInsets.only(bottom: 6),
      color: _brandPrimary,
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildGeneralInfo(Asset asset, String? areaName, pw.MemoryImage? image) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              children: [
                _buildInfoRow('Código de Activo:', asset.id, 'Nivel Jerárquico:', _formatLevel(asset.level)),
                _buildInfoRow('Nombre del Activo:', asset.name, 'Estado Operativo:', _formatStatus(asset.status)),
                _buildInfoRow('Área:', areaName ?? asset.areaId, 'Código Padre:', asset.parentAssetId ?? 'Activo Raíz (Nivel 1)'),
                _buildInfoRow('Marca:', asset.brand ?? 'N/A', 'Modelo:', asset.model ?? 'N/A'),
                _buildInfoRow(
                  'Número de Serie:',
                  asset.serial ?? 'N/A',
                  'Tipo de Activo:',
                  asset.esEquipoProceso ? 'Equipo de Proceso (Crítico)' : 'Equipo Estándar',
                ),
                _buildInfoRow(
                  'Fecha de Alta:',
                  asset.createdAt != null
                      ? '${asset.createdAt!.day.toString().padLeft(2, '0')}/${asset.createdAt!.month.toString().padLeft(2, '0')}/${asset.createdAt!.year}'
                      : 'N/A',
                  'Disponibilidad:',
                  '${asset.availabilityPercentage.toStringAsFixed(1)} %',
                ),
              ],
            ),
          ),
          if (image != null) ...[
            pw.SizedBox(width: 8),
            pw.Container(
              width: 110,
              height: 100,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 0.5),
              ),
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label1, String val1, String label2, String val2) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: '$label1 ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _brandDark)),
                  pw.TextSpan(text: val1, style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
            ),
          ),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: '$label2 ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _brandDark)),
                  pw.TextSpan(text: val2, style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDynamicAttributesTable(Map<String, dynamic> attrs) {
    final entries = attrs.entries.toList();
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Parámetro / Atributo', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Valor / Especificación', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...entries.map(
          (e) => pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_formatKey(e.key), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.value?.toString() ?? 'N/A', style: const pw.TextStyle(fontSize: 8))),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpisSection(Asset asset, DateTime? startDate, DateTime? endDate) {
    final upDays = (asset.totalUptime.inHours / 24).toStringAsFixed(1);
    final downHours = (asset.totalDowntime.inMinutes / 60).toStringAsFixed(1);
    final dispPct = asset.availabilityPercentage.toStringAsFixed(1);

    return pw.Row(
      children: [
        _buildKpiCard('Tiempo Operativo', '$upDays días', _brandPrimary),
        pw.SizedBox(width: 6),
        _buildKpiCard('Fuera de Servicio', '$downHours hrs', PdfColors.red800),
        pw.SizedBox(width: 6),
        _buildKpiCard('Disponibilidad', '$dispPct %', PdfColors.green800),
        pw.SizedBox(width: 6),
        _buildKpiCard('Paradas Totales', '${asset.inactiveCount} eventos', PdfColors.orange800),
      ],
    );
  }

  static pw.Widget _buildKpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(3),
          color: _headerBg,
        ),
        child: pw.Column(
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSubComponentsTable(List<Asset> subComponents) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            _cell('Código', isHeader: true),
            _cell('Componente / Sub-equipo', isHeader: true),
            _cell('Nivel', isHeader: true),
            _cell('Marca/Modelo', isHeader: true),
            _cell('Estado', isHeader: true),
          ],
        ),
        ...subComponents.map(
          (c) => pw.TableRow(
            children: [
              _cell(c.id, bold: true),
              _cell(c.name),
              _cell(_formatLevel(c.level)),
              _cell('${c.brand ?? ''} ${c.model ?? ''}'.trim()),
              _cell(_formatStatus(c.status)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStatusHistoryTable(List<dynamic> history) {
    if (history.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderColor, width: 0.5),
        ),
        child: pw.Center(
          child: pw.Text(
            'No se registran cambios de estado en el periodo seleccionado (Activo continuo).',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            _cell('Fecha Inicio', isHeader: true),
            _cell('Fecha Fin', isHeader: true),
            _cell('Duración', isHeader: true),
            _cell('Estado', isHeader: true),
            _cell('Motivo / Observación', isHeader: true),
          ],
        ),
        ...history.map(
          (p) {
            final startStr = _formatDate(p.startedAt);
            final endStr = p.endedAt != null ? _formatDate(p.endedAt!) : 'Actual';
            final durStr = _formatDuration(p.duration);
            return pw.TableRow(
              children: [
                _cell(startStr),
                _cell(endStr),
                _cell(durStr),
                _cell(_formatStatus(p.status)),
                _cell(p.reason ?? 'Sin observación'),
              ],
            );
          },
        ),
      ],
    );
  }

  static pw.Widget _buildSignaturesSection() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Container(width: 160, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)))),
              pw.SizedBox(height: 4),
              pw.Text('Jefe de Área / Solicitante', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('Firma y Sello', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            children: [
              pw.Container(width: 160, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)))),
              pw.SizedBox(height: 4),
              pw.Text('Responsable de Mantenimiento', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('Firma y Sello', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool isHeader = false, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: (isHeader || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? _brandDark : PdfColors.black,
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes} min';
  }

  static String _formatLevel(AssetLevel level) {
    switch (level) {
      case AssetLevel.equipment: return 'Equipo';
      case AssetLevel.subEquipment: return 'Sub-equipo';
      case AssetLevel.part: return 'Parte';
      case AssetLevel.subPart: return 'Sub-parte';
    }
  }

  static String _formatStatus(AssetStatus status) {
    switch (status) {
      case AssetStatus.active: return 'Activo';
      case AssetStatus.inactive: return 'Inactivo';
      case AssetStatus.transferredDeactivated: return 'Transferido';
      case AssetStatus.deleted: return 'Eliminado';
    }
  }

  static String _formatKey(String key) => key.replaceAll('_', ' ').toUpperCase();
}
