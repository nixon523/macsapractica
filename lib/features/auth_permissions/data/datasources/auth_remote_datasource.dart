import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/session_manager.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../models/app_user_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required ApiClient apiClient,
    SessionManager? sessionManager,
  })  : _apiClient = apiClient,
        _sessionManager = sessionManager ?? SessionManager.instance;

  final ApiClient _apiClient;
  final SessionManager _sessionManager;

  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: {
        'username': username.trim(),
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      final token = response['token']?.toString();
      final userData = response['user'] as Map<String, dynamic>?;
      if (token != null && userData != null) {
        final user = AppUserModel.fromJson(userData);
        _sessionManager.saveSession(token: token, user: user);
        return user;
      }
    }
    return null;
  }

  Future<AppUser?> getUserById(String userId) async {
    final response = await _apiClient.get(ApiEndpoints.userById(userId));
    if (response is Map<String, dynamic>) {
      return AppUserModel.fromJson(response);
    }
    return null;
  }

  Future<List<AppUser>> getAllUsers() async {
    final response = await _apiClient.get(ApiEndpoints.users);
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => AppUserModel.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<AppUser> createUser({
    required String username,
    required String displayName,
    required String password,
    required UserRole role,
    bool mustChangePassword = true,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.users,
      body: {
        'username': username.trim(),
        'displayName': displayName.trim(),
        'roleCode': role.code,
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      return AppUserModel.fromJson(response);
    }
    return AppUserModel(
      userId: '',
      username: username,
      displayName: displayName,
      role: role,
      permissions: role.defaultPermissions,
      mustChangePassword: mustChangePassword,
    );
  }

  Future<void> updateUser({
    required String userId,
    String? displayName,
    UserRole? role,
    String? newPassword,
  }) async {
    await _apiClient.put(
      ApiEndpoints.userById(userId),
      body: {
        if (displayName != null) 'displayName': displayName.trim(),
        if (role != null) 'roleCode': role.code,
        if (newPassword != null && newPassword.isNotEmpty)
          'newPassword': newPassword,
      },
    );
  }

  Future<void> toggleUserDisabled({
    required String userId,
    required bool disabled,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.toggleUserDisabled(userId),
      body: {'disabled': disabled},
    );
  }

  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    // Si la API tiene cambio propio con currentPassword, enviamos newPassword
    await _apiClient.put(
      ApiEndpoints.changePassword,
      body: {
        'currentPassword': newPassword, // o soporte para reseteo directo
        'newPassword': newPassword,
      },
    );
  }

  Future<void> resetPasswordTemporary({
    required String userId,
    required String temporaryPassword,
  }) async {
    await _apiClient.put(
      ApiEndpoints.userById(userId),
      body: {
        'newPassword': temporaryPassword,
      },
    );
  }

  Future<void> requestPasswordReset({
    required String username,
    String? details,
  }) async {
    await _apiClient.post(
      ApiEndpoints.passwordResetRequests,
      body: {
        'username': username.trim(),
      },
    );
  }
}
