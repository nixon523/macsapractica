import '../entities/app_version_info.dart';

abstract class AppUpdateRepository {
  Future<AppVersionInfo?> getLatestAndroidVersion();
}
