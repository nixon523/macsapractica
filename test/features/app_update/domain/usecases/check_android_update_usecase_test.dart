import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:macsapractica/features/app_update/domain/entities/app_version_info.dart';
import 'package:macsapractica/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:macsapractica/features/app_update/domain/usecases/check_android_update_usecase.dart';

class MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

void main() {
  late MockAppUpdateRepository mockRepo;
  late CheckAndroidUpdateUseCase useCase;

  setUp(() {
    mockRepo = MockAppUpdateRepository();
    useCase = CheckAndroidUpdateUseCase(mockRepo);
  });

  group('CheckAndroidUpdateUseCase', () {
    test('en plataformas no-Android o Web retorna UpdateCheckResult.none sin llamar al repositorio', () async {
      // En entorno flutter test por defecto TargetPlatform no es android (es linux/macos/windows)
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final result = await useCase();

      expect(result.hasUpdate, isFalse);
      verifyNever(() => mockRepo.getLatestAndroidVersion());

      debugDefaultTargetPlatformOverride = null;
    });

    test('en plataforma Android detecta versión superior obligatoria', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      when(() => mockRepo.getLatestAndroidVersion()).thenAnswer(
        (_) async => const AppVersionInfo(
          id: 2,
          version: '2.0.0',
          downloadUrl: 'http://server/app.apk',
          mandatory: true,
        ),
      );

      final result = await useCase();

      expect(result.hasUpdate, isTrue);
      expect(result.isMandatory, isTrue);
      expect(result.versionInfo?.version, '2.0.0');

      debugDefaultTargetPlatformOverride = null;
    });

    test('en plataforma Android detecta versión superior opcional', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      when(() => mockRepo.getLatestAndroidVersion()).thenAnswer(
        (_) async => const AppVersionInfo(
          id: 2,
          version: '1.9.0',
          downloadUrl: 'http://server/app.apk',
          mandatory: false,
        ),
      );

      final result = await useCase();

      expect(result.hasUpdate, isTrue);
      expect(result.isMandatory, isFalse);

      debugDefaultTargetPlatformOverride = null;
    });

    test('en plataforma Android no reporta actualización si la versión es igual o inferior', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      when(() => mockRepo.getLatestAndroidVersion()).thenAnswer(
        (_) async => const AppVersionInfo(
          id: 1,
          version: '1.0.0',
          mandatory: false,
        ),
      );

      final result = await useCase();

      expect(result.hasUpdate, isFalse);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
