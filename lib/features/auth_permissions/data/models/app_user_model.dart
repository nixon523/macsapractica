import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.userId,
    required super.username,
    super.displayName,
    super.role,
    super.permissions,
    super.disabled,
    super.mustChangePassword,
    super.passwordResetRequested,
    super.employeeId,
    super.employeePosition,
    super.employeeAreaName,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> map, [String? docId]) {
    final id = docId ??
        (map['userId'] ?? map['UserId'] ?? map['id'] ?? '')?.toString() ??
        '';
    final roleStr = (map['roleCode'] ??
            map['RoleCode'] ??
            map['role'] ??
            map['Role'])
        ?.toString();

    final rawPermissions = map['permissions'] ??
        map['Permissions'] ??
        map['PermissionsCsv'] ??
        map['permissionsCsv'];
    Set<String> perms = {};
    if (rawPermissions is List) {
      perms = rawPermissions.map((e) => e.toString()).toSet();
    } else if (rawPermissions is String && rawPermissions.trim().isNotEmpty) {
      perms = rawPermissions
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }

    final rawEmpId = map['employeeId'] ?? map['EmployeeId'] ?? map['EmpleadoId'];
    final int? parsedEmployeeId = rawEmpId == null
        ? null
        : (rawEmpId is int ? rawEmpId : int.tryParse(rawEmpId.toString()));

    final rawDisplay = map['displayName'] ?? map['DisplayName'];
    final rawEmpPos = map['employeePosition'] ?? map['EmployeePosition'];
    final rawEmpArea = map['employeeAreaName'] ?? map['EmployeeAreaName'];

    return AppUserModel(
      userId: id,
      username: (map['username'] ?? map['Username'] ?? '').toString(),
      displayName: rawDisplay != null ? TextSanitizer.fixEncoding(rawDisplay.toString()) : null,
      role: UserRole.fromCode(roleStr),
      permissions: perms,
      disabled: (map['disabled'] ?? map['Disabled']) == true ||
          (map['disabled'] ?? map['Disabled']) == 1,
      mustChangePassword:
          (map['mustChangePassword'] ?? map['MustChangePassword']) == true ||
              (map['mustChangePassword'] ?? map['MustChangePassword']) == 1,
      passwordResetRequested: (map['passwordResetRequested'] ??
              map['PasswordResetRequested']) ==
          true,
      employeeId: parsedEmployeeId,
      employeePosition:
          rawEmpPos != null ? TextSanitizer.fixEncoding(rawEmpPos.toString()) : null,
      employeeAreaName:
          rawEmpArea != null ? TextSanitizer.fixEncoding(rawEmpArea.toString()) : null,
    );
  }

  factory AppUserModel.fromFirestore(Map<String, dynamic> map, String docId) {
    return AppUserModel.fromJson(map, docId);
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'roleCode': role.code,
      'permissions': permissions.toList(),
      'disabled': disabled,
      'mustChangePassword': mustChangePassword,
      'passwordResetRequested': passwordResetRequested,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'displayName': displayName,
      'role': role.code,
      'permissions': permissions.toList(),
      'disabled': disabled,
      'mustChangePassword': mustChangePassword,
      'passwordResetRequested': passwordResetRequested,
    };
  }
}
