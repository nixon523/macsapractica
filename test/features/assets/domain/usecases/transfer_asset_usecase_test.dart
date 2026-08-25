import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:macsapractica/features/assets/domain/repositories/asset_repository.dart';
import 'package:macsapractica/features/assets/domain/usecases/transfer_asset_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetRepository extends Mock implements AssetRepository {}

void main() {
  late MockAssetRepository repository;
  late TransferAssetUseCase useCase;

  const activeAsset = Asset(
    id: 'A1-0001',
    name: 'Bomba centrífuga',
    brand: 'KSB',
    model: 'Etanorm 80',
    areaId: 'A1',
    stationId: 'S1',
    level: AssetLevel.equipment,
    ancestors: [],
    status: AssetStatus.active,
    dynamicAttributes: {},
  );

  setUpAll(() {
    registerFallbackValue(activeAsset);
    registerFallbackValue('A2');
    registerFallbackValue('A2-0045');
    registerFallbackValue('u1');
    registerFallbackValue('Admin');
  });

  setUp(() {
    repository = MockAssetRepository();
    useCase = TransferAssetUseCase(repository);
  });

  test('rechaza transferir un activo que no está ACTIVO', () {
    const inactiveAsset = Asset(
      id: 'A1-0001',
      name: 'Bomba centrífuga',
      areaId: 'A1',
      stationId: 'S1',
      level: AssetLevel.equipment,
      ancestors: [],
      status: AssetStatus.transferredDeactivated,
      dynamicAttributes: {},
    );

    expect(
      () => useCase(
        const TransferAssetParams(
          sourceAsset: inactiveAsset,
          targetAreaId: 'A2',
          newAssetId: 'A2-0045',
          userId: 'u1',
          userName: 'Admin',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.transferAsset(
          sourceAsset: any(named: 'sourceAsset'),
          targetAreaId: any(named: 'targetAreaId'),
          newAssetId: any(named: 'newAssetId'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        ));
  });

  test('transfiere un activo ACTIVO delegando en el repositorio', () async {
    when(() => repository.transferAsset(
          sourceAsset: any(named: 'sourceAsset'),
          targetAreaId: any(named: 'targetAreaId'),
          newAssetId: any(named: 'newAssetId'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        )).thenAnswer((_) async {});

    await useCase(
      const TransferAssetParams(
        sourceAsset: activeAsset,
        targetAreaId: 'A2',
        newAssetId: 'A2-0045',
        userId: 'u1',
        userName: 'Admin',
      ),
    );

    verify(() => repository.transferAsset(
          sourceAsset: activeAsset,
          targetAreaId: 'A2',
          newAssetId: 'A2-0045',
          userId: 'u1',
          userName: 'Admin',
        )).called(1);
  });

  test('rechaza un área destino vacía', () {
    expect(
      () => useCase(
        const TransferAssetParams(
          sourceAsset: activeAsset,
          targetAreaId: ' ',
          newAssetId: 'A2-0045',
          userId: 'u1',
          userName: 'Admin',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
