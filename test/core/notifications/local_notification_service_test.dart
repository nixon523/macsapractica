import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:macsapractica/core/notifications/local_notification_service.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  });

  group('LocalNotificationService', () {
    late MockFlutterLocalNotificationsPlugin mockPlugin;
    late LocalNotificationService service;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      service = LocalNotificationService(plugin: mockPlugin);

      when(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
    });

    test('showBreakdownNotification formats title and body and calls plugin',
        () async {
      await service.showBreakdownNotification(
        reportId: 'rep-123',
        assetId: 'EQ-001',
        assetName: 'Torno CNC',
        reportedBy: 'Juan Perez',
        areaId: 'A-01',
      );

      verify(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: '🚨 Nueva Avería: EQ-001',
          body: 'Juan Perez reportó falla en Torno CNC (Área A-01).',
          notificationDetails: any(named: 'notificationDetails'),
          payload: 'breakdown:rep-123',
        ),
      ).called(1);
    });

    test('showWorkOrderNotification formats title and body and calls plugin',
        () async {
      await service.showWorkOrderNotification(
        orderId: 'ot-456',
        correlative: 'OT-2026-0005',
        assetName: 'Bomba de Agua',
        description: 'Fuga en el sello',
      );

      verify(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: '⚠️ OT Alta Prioridad: OT-2026-0005',
          body: 'Bomba de Agua — Fuga en el sello',
          notificationDetails: any(named: 'notificationDetails'),
          payload: 'work_order:ot-456',
        ),
      ).called(1);
    });

    test('showPasswordResetNotification formats title and body and calls plugin',
        () async {
      await service.showPasswordResetNotification(
        username: 'jperez',
        displayName: 'Juan Perez',
      );

      verify(
        () => mockPlugin.show(
          id: any(named: 'id'),
          title: '🔑 Solicitud de Contraseña',
          body: 'Juan Perez (@jperez) solicitó una clave temporal.',
          notificationDetails: any(named: 'notificationDetails'),
          payload: 'password_reset:jperez',
        ),
      ).called(1);
    });
  });
}
