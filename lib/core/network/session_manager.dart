import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth_permissions/data/models/app_user_model.dart';
import '../../features/auth_permissions/domain/entities/app_user.dart';

/// Almacena y gestiona el token JWT y los datos del usuario autenticado,
/// persistiendo la sesión de forma segura y automática en el almacenamiento local.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _keyToken = 'macsa_session_token';
  static const _keyUser = 'macsa_session_user';

  final _sessionExpiredController = StreamController<String>.broadcast();
  Stream<String> get onSessionExpired => _sessionExpiredController.stream;

  String? _token;
  AppUser? _currentUser;

  String? get token => _token;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Notifica a la aplicación que la sesión expiró (por inactividad o desplazamiento concurrente).
  void notifySessionExpired([String message = 'Tu sesión ha expirado.']) {
    clear();
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(message);
    }
  }

  /// Restaura la sesión persistida al iniciar la app.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_keyToken);
      final savedUserJson = prefs.getString(_keyUser);

      if (savedToken != null && savedToken.isNotEmpty && savedUserJson != null && savedUserJson.isNotEmpty) {
        final map = jsonDecode(savedUserJson) as Map<String, dynamic>;
        _token = savedToken;
        _currentUser = AppUserModel.fromJson(map);
      }
    } catch (_) {
      // Si ocurre un error de lectura o deserialización, continúa en blanco
      _token = null;
      _currentUser = null;
    }
  }

  void saveSession({required String token, required AppUser user}) {
    _token = token;
    _currentUser = user;
    _persistSession(token, user);
  }

  void updateUser(AppUser user) {
    _currentUser = user;
    if (_token != null) {
      _persistSession(_token!, user);
    }
  }

  void clear() {
    _token = null;
    _currentUser = null;
    _clearPersisted();
  }

  Future<void> _persistSession(String token, AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);

      final model = user is AppUserModel
          ? user
          : AppUserModel(
              userId: user.userId,
              username: user.username,
              displayName: user.displayName,
              role: user.role,
              permissions: user.permissions,
              disabled: user.disabled,
              mustChangePassword: user.mustChangePassword,
              passwordResetRequested: user.passwordResetRequested,
              employeeId: user.employeeId,
              employeePosition: user.employeePosition,
              employeeAreaName: user.employeeAreaName,
            );
      await prefs.setString(_keyUser, jsonEncode(model.toJson()));
    } catch (_) {}
  }

  Future<void> _clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
    } catch (_) {}
  }
}
