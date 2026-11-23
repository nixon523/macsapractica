import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/network/session_manager.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/app_user.dart';
import 'package:macsapractica/features/auth_permissions/domain/entities/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionManager.instance.clear();
  });

  group('SessionManager & Concurrency', () {
    test('saveSession guarda sesión y notifySessionExpired emite en stream y limpia', () async {
      final user = const AppUser(
        userId: '1',
        username: 'admin',
        displayName: 'Administrador',
        role: UserRole.admin,
      );

      SessionManager.instance.saveSession(token: 'jwt-token-123', user: user);
      expect(SessionManager.instance.isAuthenticated, isTrue);
      expect(SessionManager.instance.token, equals('jwt-token-123'));
      expect(SessionManager.instance.currentUser?.username, equals('admin'));

      String? expiredReason;
      final sub = SessionManager.instance.onSessionExpired.listen((reason) {
        expiredReason = reason;
      });

      SessionManager.instance.notifySessionExpired('Sesión desplazada por otro dispositivo.');

      // Esperar emisión en microtask
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(expiredReason, equals('Sesión desplazada por otro dispositivo.'));
      expect(SessionManager.instance.isAuthenticated, isFalse);
      expect(SessionManager.instance.token, isNull);
      expect(SessionManager.instance.currentUser, isNull);

      await sub.cancel();
    });

    test('clear limpia variables en memoria', () {
      final user = const AppUser(
        userId: '2',
        username: 'supervisor',
        displayName: 'Supervisor Planta',
        role: UserRole.jefe,
      );

      SessionManager.instance.saveSession(token: 'token-abc', user: user);
      expect(SessionManager.instance.isAuthenticated, isTrue);

      SessionManager.instance.clear();
      expect(SessionManager.instance.isAuthenticated, isFalse);
      expect(SessionManager.instance.token, isNull);
      expect(SessionManager.instance.currentUser, isNull);
    });
  });
}
