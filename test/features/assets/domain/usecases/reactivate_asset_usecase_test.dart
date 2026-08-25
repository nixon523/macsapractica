import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:macsapractica/features/assets/domain/repositories/asset_repository.dart';
import 'package:macsapractica/features/assets/domain/usecases/reactivate_asset_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetRepository extends Mock implements AssetRepository {}

void main() {
  late MockAssetRepository repository;
  late ReactivateAssetUseCase useCase;

  const deactivatedAsset = Asset(
    id: 'A1-0001',
    name: 'Bomba centrífuga',
    areaId: 'A1',
    stationId: 'S1',
    level: AssetLevel.equipment,
    ancestors: [],
    status: AssetStatus.transferredDeactivated,
    transferredToId: 'A2-0001',
    dynamicAttributes: {},
  );

  setUpAll(() {
    registerFallbackValue(deactivatedAsset);
    registerFallbackValue('u1');
    registerFallbackValue('Admin');
  });

  setUp(() {
    repository = MockAssetRepository();
    useCase = ReactivateAssetUseCase(repository);
  });

  test('rechaza reactivar un activo que NO está deshabilitado', () {
    const activeAsset = Asset(
      id: 'A1-0001',
      name: 'Bomba centrífuga',
      areaId: 'A1',
      stationId: 'S1',
      level: AssetLevel.equipment,
      ancestors: [],
      status: AssetStatus.active,
      dynamicAttributes: {},
    );

    expect(
      () => useCase(
        const ReactivateAssetParams(
          asset: activeAsset,
          userId: 'u1',
          userName: 'Admin',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.reactivateAsset(
          asset: any(named: 'asset'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        ));
  });

  test('reactiva un activo deshabilitado delegando en el repositorio', () async {
    when(() => repository.reactivateAsset(
          asset: any(named: 'asset'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        )).thenAnswer((_) async {});

    await useCase(
      const ReactivateAssetParams(
        asset: deactivatedAsset,
        userId: 'u1',
        userName: 'Admin',
      ),
    );

    verify(() => repository.reactivateAsset(
          asset: deactivatedAsset,
          userId: 'u1',
          userName: 'Admin',
        )).called(1);
  });
}
