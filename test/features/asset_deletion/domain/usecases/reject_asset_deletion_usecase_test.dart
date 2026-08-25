import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/asset_deletion/domain/entities/asset_delete_request.dart';
import 'package:macsapractica/features/asset_deletion/domain/repositories/asset_delete_repository.dart';
import 'package:macsapractica/features/asset_deletion/domain/usecases/reject_asset_deletion.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetDeleteRepository extends Mock implements AssetDeleteRepository {}

void main() {
  late MockAssetDeleteRepository repository;
  late RejectAssetDeletionUseCase useCase;

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
    registerFallbackValue('Solicitud incompleta');
  });

  setUp(() {
    repository = MockAssetDeleteRepository();
    useCase = RejectAssetDeletionUseCase(repository);
  });

  test('rechaza rechazar una solicitud que ya fue resuelta', () {
    expect(
      () => useCase(
        RejectAssetDeletionParams(
          request: requestWith(DeletionRequestStatus.rejected),
          rejectedByUserId: 'gerente',
          rejectedByUserName: 'Gerente de Operaciones',
          rejectReason: 'Solicitud incompleta',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.rejectRequest(
          request: any(named: 'request'),
          rejectedByUserId: any(named: 'rejectedByUserId'),
          rejectedByUserName: any(named: 'rejectedByUserName'),
          rejectReason: any(named: 'rejectReason'),
        ));
  });

  test('rechaza rechazar sin indicar el motivo', () {
    expect(
      () => useCase(
        RejectAssetDeletionParams(
          request: requestWith(DeletionRequestStatus.pending),
          rejectedByUserId: 'gerente',
          rejectedByUserName: 'Gerente de Operaciones',
          rejectReason: '  ',
        ),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    verifyNever(() => repository.rejectRequest(
          request: any(named: 'request'),
          rejectedByUserId: any(named: 'rejectedByUserId'),
          rejectedByUserName: any(named: 'rejectedByUserName'),
          rejectReason: any(named: 'rejectReason'),
        ));
  });

  test('rechaza una solicitud pendiente delegando en el repositorio', () async {
    when(() => repository.rejectRequest(
          request: any(named: 'request'),
          rejectedByUserId: any(named: 'rejectedByUserId'),
          rejectedByUserName: any(named: 'rejectedByUserName'),
          rejectReason: any(named: 'rejectReason'),
        )).thenAnswer((_) async {});

    final request = requestWith(DeletionRequestStatus.pending);
    await useCase(
      RejectAssetDeletionParams(
        request: request,
        rejectedByUserId: 'gerente',
        rejectedByUserName: 'Gerente de Operaciones',
        rejectReason: '  Solicitud incompleta  ',
      ),
    );

    verify(() => repository.rejectRequest(
          request: request,
          rejectedByUserId: 'gerente',
          rejectedByUserName: 'Gerente de Operaciones',
          rejectReason: 'Solicitud incompleta',
        )).called(1);
  });
}
