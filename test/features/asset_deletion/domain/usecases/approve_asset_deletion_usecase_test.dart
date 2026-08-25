import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/asset_deletion/domain/entities/asset_delete_request.dart';
import 'package:macsapractica/features/asset_deletion/domain/repositories/asset_delete_repository.dart';
import 'package:macsapractica/features/asset_deletion/domain/usecases/approve_asset_deletion.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetDeleteRepository extends Mock implements AssetDeleteRepository {}

void main() {
  late MockAssetDeleteRepository repository;
  late ApproveAssetDeletionUseCase useCase;

  AssetDeleteRequest requestWith(DeletionRequestStatus status) =>
      AssetDeleteRequest(
        id: 'req1',
        assetId: 'A1-0001',
        assetName: 'Bomba centrífuga',
        areaId: 'A1',
        status: status,
        reason: 'Obsolescencia',
        requestedByUserId: 'jefe',
        requestedByUserName: 'Jefe de Área',
        requestedAt: DateTime(2026, 8, 6),
        subtreeCount: 3,
      );

  setUpAll(() {
    registerFallbackValue(requestWith(DeletionRequestStatus.pending));
    registerFallbackValue('gerente');
    registerFallbackValue('Gerente de Operaciones');
    registerFallbackValue('Aprobado');
  });

  setUp(() {
    repository = MockAssetDeleteRepository();
    useCase = ApproveAssetDeletionUseCase(repository);
  });

  test('rechaza aprobar una solicitud que ya fue resuelta', () {
    expect(
      () => useCase(
        ApproveAssetDeletionParams(
          request: requestWith(DeletionRequestStatus.approved),
          approvedByUserId: 'gerente',
          approvedByUserName: 'Gerente de Operaciones',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.approveRequest(
          request: any(named: 'request'),
          approvedByUserId: any(named: 'approvedByUserId'),
          approvedByUserName: any(named: 'approvedByUserName'),
          approveReason: any(named: 'approveReason'),
        ));
  });

  test('aprueba una solicitud pendiente delegando en el repositorio', () async {
    when(() => repository.approveRequest(
          request: any(named: 'request'),
          approvedByUserId: any(named: 'approvedByUserId'),
          approvedByUserName: any(named: 'approvedByUserName'),
          approveReason: any(named: 'approveReason'),
        )).thenAnswer((_) async {});

    final request = requestWith(DeletionRequestStatus.pending);
    await useCase(
      ApproveAssetDeletionParams(
        request: request,
        approvedByUserId: 'gerente',
        approvedByUserName: 'Gerente de Operaciones',
        approveReason: 'Aprobado',
      ),
    );

    verify(() => repository.approveRequest(
          request: request,
          approvedByUserId: 'gerente',
          approvedByUserName: 'Gerente de Operaciones',
          approveReason: 'Aprobado',
        )).called(1);
  });
}
