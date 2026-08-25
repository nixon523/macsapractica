import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/user_role.dart';

void main() {
  group('UserRole', () {
    test('fromCode mapea códigos conocidos y usa lector como fallback', () {
      expect(UserRole.fromCode('admin'), UserRole.admin);
      expect(UserRole.fromCode('jefe'), UserRole.jefe);
      expect(UserRole.fromCode('lector'), UserRole.lector);
      expect(UserRole.fromCode('reportador'), UserRole.reportador);
      expect(UserRole.fromCode(null), UserRole.lector);
      expect(UserRole.fromCode('inventado'), UserRole.lector);
    });

    test('el admin incluye todos los permisos del sistema', () {
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
          AppPermissions.kardexView,
          AppPermissions.breakdownReport,
          AppPermissions.breakdownView,
          AppPermissions.breakdownManage,
          AppPermissions.userManage,
        ]),
      );
    });

    test('el jefe tiene acceso a dashboard, activos (solo ver), OT, averías (gestionar), preventivo, kardex', () {
      final perms = UserRole.jefe.defaultPermissions;

      // Permisos que SÍ debe tener
      expect(
        perms,
        containsAll([
          AppPermissions.dashboardView,
          AppPermissions.assetView,
          AppPermissions.workOrderView,
          AppPermissions.workOrderCreate,
          AppPermissions.workOrderPrint,
          AppPermissions.preventiveView,
          AppPermissions.kardexView,
          AppPermissions.breakdownView,
          AppPermissions.breakdownManage,
        ]),
      );

      // Permisos que NO debe tener
      expect(perms, isNot(contains(AppPermissions.assetCreate)));
      expect(perms, isNot(contains(AppPermissions.assetEdit)));
      expect(perms, isNot(contains(AppPermissions.assetTransfer)));
      expect(perms, isNot(contains(AppPermissions.assetDeleteRequest)));
      expect(perms, isNot(contains(AppPermissions.assetDeleteApprove)));
      expect(perms, isNot(contains(AppPermissions.breakdownReport)));
      expect(perms, isNot(contains(AppPermissions.userManage)));
    });

    test('el lector solo tiene permisos de lectura (sin acciones)', () {
      final perms = UserRole.lector.defaultPermissions;

      expect(
        perms,
        containsAll([
          AppPermissions.dashboardView,
          AppPermissions.assetView,
          AppPermissions.workOrderView,
          AppPermissions.preventiveView,
          AppPermissions.kardexView,
          AppPermissions.breakdownView,
        ]),
      );
      expect(perms, isNot(contains(AppPermissions.assetCreate)));
      expect(perms, isNot(contains(AppPermissions.assetEdit)));
      expect(perms, isNot(contains(AppPermissions.assetTransfer)));
      expect(perms, isNot(contains(AppPermissions.assetDeleteApprove)));
      expect(perms, isNot(contains(AppPermissions.workOrderCreate)));
      expect(perms, isNot(contains(AppPermissions.workOrderPrint)));
      expect(perms, isNot(contains(AppPermissions.breakdownReport)));
      expect(perms, isNot(contains(AppPermissions.breakdownManage)));
      expect(perms, isNot(contains(AppPermissions.userManage)));
    });

    test('el reportador solo reporta averías y ve el estado de sus reportes', () {
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
  });
}
