import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:macsapractica/core/notifications/notification_queue.dart';

void main() {
  testWidgets('NotificationQueue enqueues and displays SnackBar with action',
      (tester) async {
    final queue = NotificationQueue();
    var actionTapped = false;
    var soundPlayed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  queue.enqueue(
                    context,
                    NotificationItem(
                      icon: Icons.warning,
                      iconColor: Colors.amber,
                      message: 'Alerta de prueba',
                      actionLabel: 'Ver',
                      onAction: () => actionTapped = true,
                      soundCallback: () => soundPlayed = true,
                    ),
                  );
                },
                child: const Text('Trigger'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Alerta de prueba'), findsOneWidget);
    expect(find.text('Ver'), findsOneWidget);
    expect(soundPlayed, isTrue);

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(actionTapped, isTrue);

    queue.clear();
  });
}
