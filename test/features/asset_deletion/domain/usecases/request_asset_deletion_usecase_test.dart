import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/asset_deletion/domain/entities/asset_delete_request.dart';
import 'package:macsapractica/features/asset_deletion/domain/repositories/asset_delete_repository.dart';
import 'package:macsapractica/features/asset_deletion/domain/usecases/request_asset_deletion.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetDeleteRepository extends Mock implements AssetDeleteRepository {}

void main() {
  late MockAssetDeleteRepository repository;
  late RequestAssetDeletionUseCase useCase;

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

  const deletedAsset = Asset(
    id: 'A1-0002',
    name: 'Compresor de aire',
    areaId: 'A1',
    stationId: 'S2',
    level: AssetLevel.equipment,
    ancestors: [],
    status: AssetStatus.deleted,
    dynamicAttributes: {},
  );

  AssetDeleteRequest pendingRequest(Asset asset) => AssetDeleteRequest(
        id: 'req1',
        assetId: asset.id,
        assetName: asset.name,
        areaId: asset.areaId,
        status: DeletionRequestStatus.pending,
        reason: 'Obsolescencia',
        requestedByUserId: 'jefe',
        requestedByUserName: 'Jefe de Área',
        requestedAt: DateTime(2026, 8, 6),
        subtreeCount: 1,
      );

  setUpAll(() {
    registerFallbackValue(activeAsset);
    registerFallbackValue('Obsolescencia');
    registerFallbackValue('u1');
    registerFallbackValue('Jefe');
  });

  setUp(() {
    repository = MockAssetDeleteRepository();
    useCase = RequestAssetDeletionUseCase(repository);
  });

  test('rechaza una solicitud sin motivo', () {
    when(() => repository.getPendingRequestByAsset(any()))
        .thenAnswer((_) async => null);

    expect(
      () => useCase(
        const RequestAssetDeletionParams(
          asset: activeAsset,
          reason: '   ',
          userId: 'u1',
          userName: 'Jefe',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.createRequest(
          asset: any(named: 'asset'),
          reason: any(named: 'reason'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        ));
  });

  test('rechaza solicitar la baja de un activo ya eliminado', () {
    when(() => repository.getPendingRequestByAsset(any()))
        .thenAnswer((_) async => null);

    expect(
      () => useCase(
        const RequestAssetDeletionParams(
          asset: deletedAsset,
          reason: 'Obsolescencia',
          userId: 'u1',
          userName: 'Jefe',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.createRequest(
          asset: any(named: 'asset'),
          reason: any(named: 'reason'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        ));
  });

  test('rechaza cuando el activo ya tiene una solicitud pendiente', () {
    when(() => repository.getPendingRequestByAsset('A1-0001'))
        .thenAnswer((_) async => pendingRequest(activeAsset));

    expect(
      () => useCase(
        const RequestAssetDeletionParams(
          asset: activeAsset,
          reason: 'Obsolescencia',
          userId: 'u1',
          userName: 'Jefe',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.createRequest(
          asset: any(named: 'asset'),
          reason: any(named: 'reason'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        ));
  });

  test('crea la solicitud delegando en el repositorio (recorta el motivo)',
      () async {
    when(() => repository.getPendingRequestByAsset('A1-0001'))
        .thenAnswer((_) async => null);
    when(() => repository.createRequest(
          asset: any(named: 'asset'),
          reason: any(named: 'reason'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
        )).thenAnswer((_) async => pendingRequest(activeAsset));

    final result = await useCase(
      const RequestAssetDeletionParams(
        asset: activeAsset,
        reason: '  Obsolescencia  ',
        userId: 'u1',
        userName: 'Jefe',
      ),
    );

    expect(result.assetId, 'A1-0001');
    verify(() => repository.getPendingRequestByAsset('A1-0001')).called(1);
    verify(() => repository.createRequest(
          asset: activeAsset,
          reason: 'Obsolescencia',
          userId: 'u1',
          userName: 'Jefe',
        )).called(1);
  });
}
