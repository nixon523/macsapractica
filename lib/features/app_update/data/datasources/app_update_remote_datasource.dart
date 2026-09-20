import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/app_version_info.dart';

abstract class AppUpdateRemoteDataSource {
  Future<AppVersionInfo?> getLatestAndroidVersion();
}

class AppUpdateRemoteDataSourceImpl implements AppUpdateRemoteDataSource {
  const AppUpdateRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AppVersionInfo?> getLatestAndroidVersion() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.androidVersion);
      if (response is Map<String, dynamic>) {
        return AppVersionInfo.fromJson(response);
      }
      return null;
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure(message: 'Error al consultar versión de Android: ');
    }
  }
}
