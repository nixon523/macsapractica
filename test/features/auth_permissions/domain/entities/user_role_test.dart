import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/user_role.dart';

void main() {
  group('UserRole', () {
    test('fromCode mapea códigos conocidos y usa lector como fallback', () {
      expect(UserRole.fromCode('admin'), UserRole.admin);
      expect(UserRole.fromCode('jefe'), UserRole.jefe);
      expect(UserRole.fromCode('jefe_area'), UserRole.jefeArea);
      expect(UserRole.fromCode('lector'), UserRole.lector);
      expect(UserRole.fromCode('reportador'), UserRole.reportador);
      expect(UserRole.fromCode(null), UserRole.lector);
      expect(UserRole.fromCode('inventado'), UserRole.lector);
    });

    test('el admin incluye todos los permisos del sistema de forma exclusiva', () {
      final perms = UserRole.admin.defaultPermissions;

      expect(
        perms,
        containsAll([
          AppPermissions.dashboardView,
          AppPermissions.assetView,
          AppPermissions.assetCreate,
          AppPermissions.assetEdit,
          AppPermissions.assetTransfer,
          AppPermissions.assetDeleteRequest,
          AppPermissions.assetDeleteApprove,
          AppPermissions.workOrderView,
          AppPermissions.workOrderCreate,
          AppPermissions.workOrderPrint,
          AppPermissions.preventiveView,
          AppPermissions.preventiveManage,
          AppPermissions.kardexView,
          AppPermissions.breakdownReport,
          AppPermissions.breakdownView,
          AppPermissions.breakdownManage,
          AppPermissions.operationReportView,
          AppPermissions.operationReportEdit,
          AppPermissions.employeeManage,
          AppPermissions.userManage,
        ]),
      );
    });

    test('el jefe de mantenimiento gestiona operación y personal técnico, sin user.manage ni aprobar bajas', () {
      final perms = UserRole.jefe.defaultPermissions;

      expect(
        perms,
        containsAll([
          AppPermissions.dashboardView,
          AppPermissions.assetView,
          AppPermissions.assetCreate,
          AppPermissions.assetEdit,
          AppPermissions.assetTransfer,
          AppPermissions.assetDeleteRequest,
          AppPermissions.workOrderView,
          AppPermissions.workOrderCreate,
          AppPermissions.workOrderPrint,
          AppPermissions.preventiveView,
          AppPermissions.preventiveManage,
          AppPermissions.kardexView,
          AppPermissions.breakdownReport,
          AppPermissions.breakdownView,
          AppPermissions.breakdownManage,
          AppPermissions.operationReportView,
          AppPermissions.operationReportEdit,
          AppPermissions.employeeManage,
        ]),
      );

      // Exclusivos de Administrador
      expect(perms, isNot(contains(AppPermissions.assetDeleteApprove)));
      expect(perms, isNot(contains(AppPermissions.userManage)));
    });

    test('el jefe de área tiene acceso operativo limitado sin editar activos ni gestionar OTs o usuarios', () {
      final perms = UserRole.jefeArea.defaultPermissions;

      expect(
        perms,
        containsAll([
          AppPermissions.dashboardView,
          AppPermissions.assetView,
          AppPermissions.workOrderView,
          AppPermissions.workOrderPrint,
          AppPermissions.preventiveView,
          AppPermissions.breakdownReport,
          AppPermissions.breakdownView,
          AppPermissions.operationReportView,
          AppPermissions.operationReportEdit,
        ]),
      );

      expect(perms, isNot(contains(AppPermissions.assetCreate)));
      expect(perms, isNot(contains(AppPermissions.assetEdit)));
      expect(perms, isNot(contains(AppPermissions.assetTransfer)));
      expect(perms, isNot(contains(AppPermissions.assetDeleteApprove)));
      expect(perms, isNot(contains(AppPermissions.workOrderCreate)));
      expect(perms, isNot(contains(AppPermissions.preventiveManage)));
      expect(perms, isNot(contains(AppPermissions.breakdownManage)));
      expect(perms, isNot(contains(AppPermissions.employeeManage)));
      expect(perms, isNot(contains(AppPermissions.userManage)));
    });

    test('el gerente (lector) ve todo el sistema y genera reportes sin modificar datos', () {
      final perms = UserRole.lector.defaultPermissions;

      expect(
        perms,
        containsAll([
          AppPermissions.dashboardView,
          AppPermissions.assetView,
          AppPermissions.workOrderView,
          AppPermissions.workOrderPrint,
          AppPermissions.preventiveView,
          AppPermissions.kardexView,
          AppPermissions.breakdownView,
          AppPermissions.operationReportView,
        ]),
      );
      expect(perms, isNot(contains(AppPermissions.assetCreate)));
      expect(perms, isNot(contains(AppPermissions.assetEdit)));
      expect(perms, isNot(contains(AppPermissions.assetTransfer)));
      expect(perms, isNot(contains(AppPermissions.assetDeleteApprove)));
      expect(perms, isNot(contains(AppPermissions.workOrderCreate)));
      expect(perms, isNot(contains(AppPermissions.preventiveManage)));
      expect(perms, isNot(contains(AppPermissions.breakdownReport)));
      expect(perms, isNot(contains(AppPermissions.breakdownManage)));
      expect(perms, isNot(contains(AppPermissions.operationReportEdit)));
      expect(perms, isNot(contains(AppPermissions.employeeManage)));
      expect(perms, isNot(contains(AppPermissions.userManage)));
    });

    test('el supervisor (reportador) solo reporta averías y consulta reportes', () {
      final perms = UserRole.reportador.defaultPermissions;

      expect(
        perms,
        containsAll([
          AppPermissions.breakdownReport,
          AppPermissions.breakdownView,
        ]),
      );
      expect(perms, isNot(contains(AppPermissions.dashboardView)));
      expect(perms, isNot(contains(AppPermissions.assetView)));
      expect(perms, isNot(contains(AppPermissions.workOrderView)));
      expect(perms, isNot(contains(AppPermissions.workOrderCreate)));
      expect(perms, isNot(contains(AppPermissions.kardexView)));
      expect(perms, isNot(contains(AppPermissions.breakdownManage)));
      expect(perms, isNot(contains(AppPermissions.userManage)));
    });

    test('suggestFromPosition sugiere el rol adecuado según el puesto del empleado', () {
      expect(UserRole.suggestFromPosition('Jefe de Mantenimiento'), UserRole.jefe);
      expect(UserRole.suggestFromPosition('Jefe de Aseguramiento de Calidad'), UserRole.jefeArea);
      expect(UserRole.suggestFromPosition('Supervisor de Planta y Producción'), UserRole.reportador);
      expect(UserRole.suggestFromPosition('Gerente de Operaciones'), UserRole.lector);
    });
  });
}
