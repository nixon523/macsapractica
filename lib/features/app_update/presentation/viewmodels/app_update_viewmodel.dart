import 'package:flutter/foundation.dart';

import '../../domain/entities/app_version_info.dart';
import '../../domain/usecases/check_android_update_usecase.dart';

class AppUpdateViewModel extends ChangeNotifier {
  AppUpdateViewModel({
    required CheckAndroidUpdateUseCase checkAndroidUpdateUseCase,
  }) : _checkAndroidUpdateUseCase = checkAndroidUpdateUseCase;

  final CheckAndroidUpdateUseCase _checkAndroidUpdateUseCase;

  bool _isChecking = false;
  bool _hasUpdate = false;
  bool _isMandatory = false;
  AppVersionInfo? _versionInfo;
  String _currentVersion = '';
  bool _dismissedOptional = false;

  bool get isChecking => _isChecking;
  bool get hasUpdate => _hasUpdate;
  bool get isMandatory => _isMandatory;
  AppVersionInfo? get versionInfo => _versionInfo;
  String get currentVersion => _currentVersion;
  bool get shouldShowDialog => _hasUpdate && (_isMandatory || !_dismissedOptional);

  Future<void> checkForUpdates() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    _isChecking = true;
    notifyListeners();

    try {
      final result = await _checkAndroidUpdateUseCase();
      _hasUpdate = result.hasUpdate;
      _isMandatory = result.isMandatory;
      _versionInfo = result.versionInfo;
      _currentVersion = result.currentVersion;
    } catch (_) {
      _hasUpdate = false;
      _isMandatory = false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  void dismissOptional() {
    _dismissedOptional = true;
    notifyListeners();
  }
}
