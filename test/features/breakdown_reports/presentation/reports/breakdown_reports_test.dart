import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/breakdown_reports/domain/entities/breakdown_report.dart';
import 'package:macsapractica/features/breakdown_reports/presentation/reports/breakdown_report_excel_builder.dart';
import 'package:macsapractica/features/breakdown_reports/presentation/reports/breakdown_report_pdf_builder.dart';

void main() {
  final sampleReports = [
    BreakdownReport(
      id: 'REP-2026-0001',
      assetId: 'DEMO-SW-001',
      assetName: 'Switch Cisco',
      areaId: 'TIC\'S',
      description: 'Falla en puerto de enlace de fibra óptica',
      severity: BreakdownSeverity.high,
      reportedByUserId: 'usr-1',
      reportedByUserName: 'Operador 1',
      reportedAt: DateTime(2026, 10, 24, 8, 30),
      status: BreakdownReportStatus.inWorkOrder,
      workOrderId: 'OT-2026-0001',
    ),
    BreakdownReport(
      id: 'REP-2026-0002',
      assetId: 'DEMO-IMP-001',
      assetName: 'Impresora Epson',
      areaId: 'TIC\'S',
      description: 'Atasco constante de papel en bandeja 2',
      severity: BreakdownSeverity.low,
      reportedByUserId: 'usr-2',
      reportedByUserName: 'Secretaría',
      reportedAt: DateTime(2026, 10, 25, 11, 0),
      status: BreakdownReportStatus.resolved,
      resolvedByUserId: 'usr-3',
      resolvedByUserName: 'Kevin Mejia',
      resolvedAt: DateTime(2026, 10, 25, 12, 15),
    ),
  ];

  group('BreakdownReportExcelBuilder', () {
    test('genera archivo Excel válido con bytes no vacíos', () async {
      final bytes = await BreakdownReportExcelBuilder.buildBreakdownExcel(
        reports: sampleReports,
        areaNamesMap: {'TIC\'S': 'Tecnologías de Información'},
        dateFilterLabel: 'Semana 43',
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Validar firma del archivo zip/xlsx (PK\x03\x04)
      expect(bytes[0], equals(0x50));
      expect(bytes[1], equals(0x4B));
    });

    test('soporta lista vacía sin fallar', () async {
      final bytes = await BreakdownReportExcelBuilder.buildBreakdownExcel(
        reports: const [],
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  group('BreakdownReportPdfBuilder', () {
    test('genera documento PDF válido con bytes no vacíos', () async {
      final bytes = await BreakdownReportPdfBuilder.buildPdf(
        reports: sampleReports,
        dateFilterLabel: 'Semana 43',
        areaFilterLabel: 'TIC\'S',
        issuedByName: 'Supervisor de Turno',
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Validar cabecera PDF (%PDF-)
      final headerStr = String.fromCharCodes(bytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });

    test('soporta lista vacía generando página formal con aviso', () async {
      final bytes = await BreakdownReportPdfBuilder.buildPdf(
        reports: const [],
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}

