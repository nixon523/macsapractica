import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/network/api_client.dart';
import 'package:macsapractica/core/network/api_endpoints.dart';
import 'package:macsapractica/features/employees/data/models/employee_model.dart';

void main() {
  group('Configuración de red sin hardcoding de IP LAN', () {
    test('defaultBaseUrl no contiene IP LAN hardcodeada', () {
      expect(ApiClient.defaultBaseUrl.contains('192.168.'), isFalse);
      expect(ApiClient.defaultBaseUrl, endsWith('/api'));
    });

    test('ApiEndpoints expone el endpoint dinámico de catálogos', () {
      expect(ApiEndpoints.catalogs, '/catalogos');
    });
  });

  group('EmployeeModel normalizado (PuestoId + Área)', () {
    test('parsea PuestoId, Puesto y NombreArea desde SQL Server', () {
      final emp = EmployeeModel.fromJson({
        'EmpleadoId': 12,
        'NombreCompleto': 'Juan Pérez',
        'AreaId': 'A1',
        'NombreArea': 'Producción',
        'PuestoId': 3,
        'Puesto': 'Técnico Electromecánico',
        'EsMantenimiento': 1,
        'Activo': 1,
      });

      expect(emp.id, 12);
      expect(emp.positionId, 3);
      expect(emp.position, 'Técnico Electromecánico');
      expect(emp.areaId, 'A1');
      expect(emp.areaName, 'Producción');
      expect(emp.isMaintenance, isTrue);
      expect(emp.isActive, isTrue);
      expect(emp.toJson()['positionId'], 3);
    });
  });

  group('Responsive UI sin desbordamientos en móvil, tablet y desktop', () {
    for (final size in const [
      Size(360, 780), // Móvil compacto
      Size(768, 1024), // Tablet
      Size(1280, 800), // Desktop
    ]) {
      testWidgets('ConstrainedBox dialog no desborda en ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.assignment_turned_in_outlined),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Título largo de diálogo responsive para verificación',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          content: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: const SizedBox(
                              width: double.maxFinite,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      decoration: InputDecoration(labelText: 'Campo 1'),
                                    ),
                                    SizedBox(height: 12),
                                    TextField(
                                      decoration: InputDecoration(labelText: 'Campo 2'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () {}, child: const Text('Cancelar')),
                            ElevatedButton(onPressed: () {}, child: const Text('Guardar')),
                          ],
                        ),
                      );
                    },
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        expect(find.text('Guardar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
