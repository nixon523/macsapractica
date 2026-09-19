import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/auth_permissions/data/models/app_user_model.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/app_user.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/user_role.dart';

void main() {
  group('AppUserModel', () {
    const map = <String, dynamic>{
      'username': 'admin',
      'displayName': 'Administrador',
      'role': 'admin',
      'permissions': <String>['asset.create', 'asset.transfer'],
      'disabled': false,
      'mustChangePassword': true,
    };

    test('fromFirestore construye el modelo sin credenciales', () {
      final model = AppUserModel.fromFirestore(map, 'u1');

      expect(model.userId, 'u1');
      expect(model.username, 'admin');
      expect(model.displayName, 'Administrador');
      expect(model.role, UserRole.admin);
      expect(model.permissions, {'asset.create', 'asset.transfer'});
      expect(model.disabled, isFalse);
      expect(model.mustChangePassword, isTrue);
    });

    test('fromFirestore ignora campos de credenciales si existieran', () {
      final model = AppUserModel.fromFirestore({
        ...map,
        'passwordSalt': 'sal',
        'passwordHash': 'hash',
        'passwordIterations': 100000,
      }, 'u1');

      expect(model.userId, 'u1');
      expect(model.username, 'admin');
      expect(model.mustChangePassword, isTrue);
    });

    test('fromFirestore asigna el rol por defecto (lector) si no viene', () {
      final model = AppUserModel.fromFirestore(
        {...map}..remove('role'),
        'u1',
      );

      expect(model.role, UserRole.lector);
    });

    test('fromFirestore detecta el flag disabled y mustChangePassword', () {
      final model = AppUserModel.fromFirestore({
        ...map,
        'disabled': true,
        'mustChangePassword': true,
      }, 'u1');

      expect(model.disabled, isTrue);
      expect(model.mustChangePassword, isTrue);
    });

    test('toFirestore NUNCA incluye la contraseña ni los hash', () {
      const model = AppUserModel(
        userId: 'u1',
        username: 'admin',
        displayName: 'Administrador',
        role: UserRole.admin,
        permissions: {'asset.create'},
        mustChangePassword: true,
      );

      final data = model.toFirestore();

      expect(data['username'], 'admin');
      expect(data['displayName'], 'Administrador');
      expect(data['role'], 'admin');
      expect(data['permissions'], ['asset.create']);
      expect(data['disabled'], isFalse);
      expect(data['mustChangePassword'], isTrue);
      // La seguridad de credenciales vive en el repositorio (salt+hash PBKDF2):
      // el modelo de presentación jamás puede escribir `password`/`passwordHash`.
      expect(data.containsKey('password'), isFalse);
      expect(data.containsKey('passwordHash'), isFalse);
      expect(data.containsKey('passwordSalt'), isFalse);
    });
  });

  group('AppUser RBAC', () {
    test('el admin accede a todo por el propio rol, sin importar su lista', () {
      const user = AppUser(
        userId: 'u1',
        username: 'admin',
        role: UserRole.admin,
        permissions: {},
      );

      expect(user.isAdmin, isTrue);
      expect(user.hasPermission('ot.edit_deadline'), isTrue);
      expect(user.hasPermission('work_order.create'), isTrue);
      expect(user.hasPermission('cualquier.cosa'), isTrue);
    });

    test('un rol no-admin se evalúa contra su lista de permisos y los permisos por defecto de su rol', () {
      const user = AppUser(
        userId: 'u2',
        username: 'reportador1',
        role: UserRole.reportador,
        permissions: {'asset.view', 'work_order.view'},
      );

      expect(user.isAdmin, isFalse);
      // Permisos propios del rol reportador
      expect(user.hasPermission('breakdown.report'), isTrue);
      expect(user.hasPermission('breakdown.view'), isTrue);
      // Permisos extra asignados
      expect(user.hasPermission('asset.view'), isTrue);
      expect(user.hasPermission('work_order.view'), isTrue);
      // Permisos no asignados
      expect(user.hasPermission('asset.delete.approve'), isFalse);
      expect(user.hasPermission('user.manage'), isFalse);
    });
  });
}
