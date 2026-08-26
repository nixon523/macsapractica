import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementación del repositorio de autenticación contra la API REST (SQL Server).
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<AppUser?> login({
    required String username,
    required String password,
  }) {
    return _remoteDataSource.login(username: username, password: password);
  }

  @override
  Future<AppUser?> getUserById(String userId) {
    return _remoteDataSource.getUserById(userId);
  }

  @override
  Future<List<AppUser>> getAllUsers() {
    return _remoteDataSource.getAllUsers();
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String displayName,
    required String password,
    required UserRole role,
    Set<String> permissions = const {},
    bool mustChangePassword = true,
  }) {
    return _remoteDataSource.createUser(
      username: username,
      displayName: displayName,
      password: password,
      role: role,
      permissions: permissions,
      mustChangePassword: mustChangePassword,
    );
  }

  @override
  Future<void> updateUser({
    required String userId,
    String? displayName,
    UserRole? role,
    String? newPassword,
    Set<String>? permissions,
  }) {
    return _remoteDataSource.updateUser(
      userId: userId,
      displayName: displayName,
      role: role,
      newPassword: newPassword,
      permissions: permissions,
    );
  }

  @override
  Future<void> toggleUserDisabled({
    required String userId,
    required bool disabled,
  }) {
    return _remoteDataSource.toggleUserDisabled(
      userId: userId,
      disabled: disabled,
    );
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) {
    return _remoteDataSource.changePassword(
      userId: userId,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> resetPasswordTemporary({
    required String userId,
    required String temporaryPassword,
  }) {
    return _remoteDataSource.resetPasswordTemporary(
      userId: userId,
      temporaryPassword: temporaryPassword,
    );
  }

  @override
  Future<void> requestPasswordReset({
    required String username,
    String? details,
  }) {
    return _remoteDataSource.requestPasswordReset(
      username: username,
      details: details,
    );
  }
}
