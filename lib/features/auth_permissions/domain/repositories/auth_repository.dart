import '../entities/app_user.dart';
import '../entities/user_role.dart';

abstract class AuthRepository {
  Future<AppUser?> login({required String username, required String password});
  Future<AppUser?> getUserById(String userId);
  Future<List<AppUser>> getAllUsers();

  /// Crea un usuario nuevo con contraseña temporal hasheada (PBKDF2).
  /// Setea `mustChangePassword: true` por defecto.
  /// Lanza [ValidationFailure] si el username ya existe.
  Future<AppUser> createUser({
    required String username,
    required String displayName,
    required String password,
    required UserRole role,
    Set<String> permissions = const {},
    bool mustChangePassword = true,
  });

  /// Actualiza displayName, rol y opcionalmente la contraseña.
  Future<void> updateUser({
    required String userId,
    String? displayName,
    UserRole? role,
    String? newPassword,
    Set<String>? permissions,
  });

  /// Habilita o deshabilita un usuario.
  Future<void> toggleUserDisabled({
    required String userId,
    required bool disabled,
  });

  /// Cambia la contraseña del usuario (cambio obligatorio o voluntario).
  /// Setea `mustChangePassword: false` y actualiza el hash PBKDF2.
  Future<void> changePassword({
    required String userId,
    required String newPassword,
  });

  /// Restablece una contraseña temporal para un usuario (realizado por el Admin).
  /// Desbloquea la cuenta, resetea intentos fallidos y activa `mustChangePassword: true`.
  Future<void> resetPasswordTemporary({
    required String userId,
    required String temporaryPassword,
  });

  /// Registra una solicitud de recuperación de contraseña desde la pantalla de login.
  Future<void> requestPasswordReset({
    required String username,
    String? details,
  });
}
