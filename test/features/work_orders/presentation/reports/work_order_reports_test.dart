import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/work_orders/domain/entities/work_order.dart';
import 'package:macsapractica/features/work_orders/presentation/reports/work_order_excel_builder.dart';
import 'package:macsapractica/features/work_orders/presentation/reports/work_order_report_pdf_builder.dart';

void main() {
  final sampleOrders = [
    WorkOrder(
      id: 'OT-2026-0001',
      correlativeNumber: 'OT-2026-0001',
      assetId: 'DEMO-SW-001',
      assetName: 'Switch Principal Cisco',
      areaId: 'A1',
      areaName: 'TIC\'S',
      description: 'Mantenimiento preventivo mensual de switch central',
      status: WorkOrderStatus.completed,
      priority: WorkOrderPriority.high,
      requestedWorkTypes: const ['preventive', 'electric'],
      assignedTo: 'Kevin Mejia',
      estimatedHours: 2.0,
      actualHours: 2.5,
      scheduledDate: DateTime(2026, 10, 24),
      createdAt: DateTime(2026, 10, 20),
      materials: const [
        WorkOrderMaterial(description: 'Cable UTP Cat6', quantity: 15, unit: 'm'),
        WorkOrderMaterial(description: 'Conectores RJ45', quantity: 4, unit: 'pz'),
      ],
    ),
    WorkOrder(
      id: 'OT-2026-0002',
      correlativeNumber: 'OT-2026-0002',
      assetId: 'DEMO-AP-001',
      assetName: 'Access Point Ubiquiti',
      areaId: 'A1',
      areaName: 'TIC\'S',
      description: 'Revisión por caída intermitente de señal wifi',
      status: WorkOrderStatus.pending,
      priority: WorkOrderPriority.medium,
      requestedWorkTypes: const ['corrective'],
      assignedTo: 'Tecnico 1',
      estimatedHours: 1.5,
      actualHours: 0.0,
      scheduledDate: DateTime(2026, 10, 26),
      createdAt: DateTime(2026, 10, 25),
    ),
  ];

  group('WorkOrderExcelBuilder', () {
    test('genera archivo Excel válido con bytes no vacíos', () async {
      final bytes = await WorkOrderExcelBuilder.buildWorkOrdersExcel(
        workOrders: sampleOrders,
        areaNamesMap: {'A1': 'TIC\'S'},
        dateFilterLabel: 'Octubre 2026',
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Validar firma del archivo zip/xlsx (PK\x03\x04)
      expect(bytes[0], equals(0x50));
      expect(bytes[1], equals(0x4B));
    });

    test('soporta lista vacía sin fallar', () async {
      final bytes = await WorkOrderExcelBuilder.buildWorkOrdersExcel(
        workOrders: const [],
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  group('WorkOrderReportPdfBuilder', () {
    test('genera documento PDF válido con bytes no vacíos', () async {
      final bytes = await WorkOrderReportPdfBuilder.buildPdf(
        workOrders: sampleOrders,
        dateFilterLabel: 'Octubre 2026',
        areaFilterLabel: 'TIC\'S',
        issuedByName: 'Supervisor de Mantenimiento',
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Validar cabecera PDF (%PDF-)
      final headerStr = String.fromCharCodes(bytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });

    test('soporta lista vacía generando página formal con aviso', () async {
      final bytes = await WorkOrderReportPdfBuilder.buildPdf(
        workOrders: const [],
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}

