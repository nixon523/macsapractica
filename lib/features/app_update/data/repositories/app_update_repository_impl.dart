import '../../domain/entities/app_version_info.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/app_update_remote_datasource.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  const AppUpdateRepositoryImpl(this._remoteDataSource);

  final AppUpdateRemoteDataSource _remoteDataSource;

  @override
  Future<AppVersionInfo?> getLatestAndroidVersion() {
    return _remoteDataSource.getLatestAndroidVersion();
  }
}
