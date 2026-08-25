import '../../features/auth_permissions/domain/entities/app_user.dart';

/// Almacena y gestiona en memoria el token JWT y los datos del usuario autenticado.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  String? _token;
  AppUser? _currentUser;

  String? get token => _token;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void saveSession({required String token, required AppUser user}) {
    _token = token;
    _currentUser = user;
  }

  void updateUser(AppUser user) {
    _currentUser = user;
  }

  void clear() {
    _token = null;
    _currentUser = null;
  }
}
