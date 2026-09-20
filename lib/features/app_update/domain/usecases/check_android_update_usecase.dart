import 'package:flutter/foundation.dart';

import '../../../../core/config/app_version.dart';
import '../../../../core/utils/version_comparator.dart';
import '../entities/app_version_info.dart';
import '../repositories/app_update_repository.dart';

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    required this.isMandatory,
    this.versionInfo,
    required this.currentVersion,
  });

  final bool hasUpdate;
  final bool isMandatory;
  final AppVersionInfo? versionInfo;
  final String currentVersion;

  static UpdateCheckResult get none => UpdateCheckResult(
    hasUpdate: false,
    isMandatory: false,
    currentVersion: AppVersion.current,
  );
}

class CheckAndroidUpdateUseCase {
  const CheckAndroidUpdateUseCase(this._repository);

  final AppUpdateRepository _repository;

  Future<UpdateCheckResult> call() async {
    // Salvaguarda absoluta: Solo ejecuta en la plataforma nativa Android (nunca en Web ni Windows)
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return UpdateCheckResult.none;
    }

    try {
      final remoteInfo = await _repository.getLatestAndroidVersion();
      if (remoteInfo == null) return UpdateCheckResult.none;

      await AppVersion.initialize();
      final currentVersion = AppVersion.current;
      final hasNewer = VersionComparator.isNewer(remoteInfo.version, currentVersion);

      if (hasNewer) {
        return UpdateCheckResult(
          hasUpdate: true,
          isMandatory: remoteInfo.mandatory,
          versionInfo: remoteInfo,
          currentVersion: currentVersion,
        );
      }

      return UpdateCheckResult(
        hasUpdate: false,
        isMandatory: false,
        versionInfo: remoteInfo,
        currentVersion: currentVersion,
      );
    } catch (_) {
      return UpdateCheckResult.none;
    }
  }
}
