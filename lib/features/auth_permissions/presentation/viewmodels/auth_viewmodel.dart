import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/request_password_reset_usecase.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required this.loginUseCase,
    required ChangePasswordUseCase changePasswordUseCase,
    required RequestPasswordResetUseCase requestPasswordResetUseCase,
  })  : _changePasswordUseCase = changePasswordUseCase,
        _requestPasswordResetUseCase = requestPasswordResetUseCase;

  final LoginUseCase loginUseCase;
  final ChangePasswordUseCase _changePasswordUseCase;
  final RequestPasswordResetUseCase _requestPasswordResetUseCase;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;
  bool get mustChangePassword => _currentUser?.mustChangePassword ?? false;

  bool _isLoggingIn = false;
  bool get isLoggingIn => _isLoggingIn;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _successMessage = '';
  String get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoggingIn = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final user = await loginUseCase(
        LoginParams(username: username, password: password),
      );
      if (user == null) {
        _errorMessage = 'Usuario o contraseña incorrectos.';
        _isLoggingIn = false;
        notifyListeners();
        return false;
      }
      _currentUser = user;
      _isLoggingIn = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoggingIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({required String newPassword}) async {
    if (_currentUser == null) return false;

    _isProcessing = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      await _changePasswordUseCase(ChangePasswordParams(
        userId: _currentUser!.userId,
        newPassword: newPassword,
      ));

      // Actualizar el estado del usuario local
      _currentUser = AppUser(
        userId: _currentUser!.userId,
        username: _currentUser!.username,
        displayName: _currentUser!.displayName,
        role: _currentUser!.role,
        permissions: _currentUser!.permissions,
        disabled: _currentUser!.disabled,
        mustChangePassword: false,
      );

      _successMessage = 'Contraseña actualizada correctamente.';
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPasswordReset({
    required String username,
    String? details,
  }) async {
    _isProcessing = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      await _requestPasswordResetUseCase(RequestPasswordResetParams(
        username: username,
        details: details,
      ));
      _successMessage =
          'Se ha registrado tu solicitud de recuperación. Notifica a tu Administrador para que te asigne una clave temporal.';
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  bool hasPermission(String permission) =>
      _currentUser?.hasPermission(permission) ?? false;
}
