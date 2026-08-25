import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.userId,
    required this.username,
    this.displayName,
    this.role = UserRole.lector,
    this.permissions = const {},
    this.disabled = false,
    this.mustChangePassword = false,
    this.passwordResetRequested = false,
  });

  final String userId;
  final String username;
  final String? displayName;
  final UserRole role;
  final Set<String> permissions;
  final bool disabled;
  final bool mustChangePassword;
  final bool passwordResetRequested;

  bool get isAdmin => role == UserRole.admin;

  /// El Gestor del Sistema (admin) tiene acceso total por el propio rol.
  /// Cualquier otro rol se evalúa contra su lista de permisos.
  bool hasPermission(String permission) =>
      role == UserRole.admin || permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          username == other.username &&
          displayName == other.displayName &&
          role == other.role &&
          disabled == other.disabled &&
          mustChangePassword == other.mustChangePassword &&
          passwordResetRequested == other.passwordResetRequested &&
          permissions.length == other.permissions.length &&
          permissions.containsAll(other.permissions);

  @override
  int get hashCode => Object.hash(
        userId,
        username,
        displayName,
        role,
        disabled,
        mustChangePassword,
        passwordResetRequested,
        permissions,
      );
}
