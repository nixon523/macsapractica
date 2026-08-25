import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/get_all_users.dart';
import '../../domain/usecases/create_user_usecase.dart';
import '../../domain/usecases/update_user_usecase.dart';
import '../../domain/usecases/toggle_user_disabled_usecase.dart';
import '../../domain/usecases/reset_password_temporary_usecase.dart';
import '../../../../core/usecases/usecase.dart';

class UserListViewModel extends ChangeNotifier {
  UserListViewModel({
    required GetAllUsersUseCase getAllUsersUseCase,
    required CreateUserUseCase createUserUseCase,
    required UpdateUserUseCase updateUserUseCase,
    required ToggleUserDisabledUseCase toggleUserDisabledUseCase,
    required ResetPasswordTemporaryUseCase resetPasswordTemporaryUseCase,
  })  : _getAllUsersUseCase = getAllUsersUseCase,
        _createUserUseCase = createUserUseCase,
        _updateUserUseCase = updateUserUseCase,
        _toggleUserDisabledUseCase = toggleUserDisabledUseCase,
        _resetPasswordTemporaryUseCase = resetPasswordTemporaryUseCase;

  final GetAllUsersUseCase _getAllUsersUseCase;
  final CreateUserUseCase _createUserUseCase;
  final UpdateUserUseCase _updateUserUseCase;
  final ToggleUserDisabledUseCase _toggleUserDisabledUseCase;
  final ResetPasswordTemporaryUseCase _resetPasswordTemporaryUseCase;

  List<AppUser> _users = [];
  List<AppUser> get users => _users;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _successMessage = '';
  String get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _users = await _getAllUsersUseCase(const NoParams());
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser({
    required String username,
    required String displayName,
    required String password,
    required UserRole role,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      await _createUserUseCase(CreateUserParams(
        username: username,
        displayName: displayName,
        password: password,
        role: role,
      ));
      _successMessage = 'Usuario "$username" creado con contraseña temporal.';
      _isSaving = false;
      notifyListeners();
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser({
    required String userId,
    String? displayName,
    UserRole? role,
    String? newPassword,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      await _updateUserUseCase(UpdateUserParams(
        userId: userId,
        displayName: displayName,
        role: role,
        newPassword: newPassword,
      ));
      _successMessage = 'Usuario actualizado correctamente.';
      _isSaving = false;
      notifyListeners();
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPasswordTemporary({
    required String userId,
    required String temporaryPassword,
  }) async {
    _isSaving = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      await _resetPasswordTemporaryUseCase(ResetPasswordTemporaryParams(
        userId: userId,
        temporaryPassword: temporaryPassword,
      ));
      _successMessage = 'Contraseña temporal asignada y cuenta desbloqueada.';
      _isSaving = false;
      notifyListeners();
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleDisabled({
    required String userId,
    required bool disabled,
  }) async {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      await _toggleUserDisabledUseCase(ToggleUserDisabledParams(
        userId: userId,
        disabled: disabled,
      ));
      _successMessage = disabled
          ? 'Usuario deshabilitado.'
          : 'Usuario habilitado.';
      notifyListeners();
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
