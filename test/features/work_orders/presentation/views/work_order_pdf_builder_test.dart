import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/work_orders/domain/entities/work_order.dart';
import 'package:macsapractica/features/work_orders/presentation/views/work_order_pdf_builder.dart';

void main() {
  final sampleOrder = WorkOrder(
    id: 'OT-2026-0001',
    correlativeNumber: 'OT-2026-0001',
    assetId: 'A003-001',
    assetName: 'Equipo de Prueba',
    areaId: 'A003',
    areaName: 'PLANTA PROCESADORA',
    description: 'Mantenimiento de motor principal y cambio de rodamientos',
    status: WorkOrderStatus.inProgress,
    priority: WorkOrderPriority.high,
    requestedWorkTypes: const ['electric', 'mechanical'],
    assignedTo: 'Kevin Mejia',
    assignedStaffCount: 2,
    estimatedHours: 4.5,
    actualHours: 3.0,
    scheduledDate: DateTime(2026, 11, 20),
    createdAt: DateTime(2026, 11, 19, 8, 30),
    createdByUserName: 'KMEJIA',
    maintenanceResponsible: 'Kevin Mejia',
    maintenanceHeadResponsible: 'Ing. Mantenimiento',
    materials: const [
      WorkOrderMaterial(description: 'Rodamiento SKF 6205', quantity: 2, unit: 'pz'),
      WorkOrderMaterial(description: 'Grasa sintética Mobil', quantity: 1, unit: 'lata'),
    ],
    workDoneDescription: 'Se completó el desmontaje y cambio de rodamientos de forma satisfactoria.',
    isCompleted: true,
  );

  group('WorkOrderPdfBuilder', () {
    test('genera documento PDF válido sin logoBytes (fallback)', () async {
      final bytes = await WorkOrderPdfBuilder.buildPdf(sampleOrder);

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Validar firma de archivo PDF (%PDF-)
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('genera documento PDF válido con logoBytes provistos', () async {
      // 1x1 transparente PNG bytes mínimos válidos
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final bytes = await WorkOrderPdfBuilder.buildPdf(
        sampleOrder,
        logoBytes: dummyPngBytes,
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('soporta orden preventiva con ref a calendario', () async {
      final prevOrder = sampleOrder.copyWith(
        requestedWorkTypes: const ['preventive'],
        preventiveScheduleId: 'PM-2026-0005',
      );

      final bytes = await WorkOrderPdfBuilder.buildPdf(prevOrder);
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('soporta firma de Jefe de Área cuando está definida o en blanco', () async {
      // Con jefe de área explícito
      final orderWithAreaHead = sampleOrder.copyWith(
        areaHeadResponsible: 'Ing. Carlos Rodriguez',
      );
      final bytes1 = await WorkOrderPdfBuilder.buildPdf(orderWithAreaHead);
      expect(bytes1.isNotEmpty, isTrue);

      // Sin jefe de área explícito (debe quedar en blanco para firma manual sin poner el usuario)
      final orderWithoutAreaHead = sampleOrder.copyWith(
        areaHeadResponsible: null,
      );
      final bytes2 = await WorkOrderPdfBuilder.buildPdf(orderWithoutAreaHead);
      expect(bytes2.isNotEmpty, isTrue);
    });
  });
}
