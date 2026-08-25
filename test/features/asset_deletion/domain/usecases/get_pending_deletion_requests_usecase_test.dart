import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/usecases/usecase.dart';
import 'package:macsapractica/features/asset_deletion/domain/entities/asset_delete_request.dart';
import 'package:macsapractica/features/asset_deletion/domain/repositories/asset_delete_repository.dart';
import 'package:macsapractica/features/asset_deletion/domain/usecases/get_pending_deletion_requests.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetDeleteRepository extends Mock implements AssetDeleteRepository {}

void main() {
  late MockAssetDeleteRepository repository;
  late GetPendingDeletionRequestsUseCase useCase;

  setUp(() {
    repository = MockAssetDeleteRepository();
    useCase = GetPendingDeletionRequestsUseCase(repository);
  });

  test('delega en el repositorio y devuelve las solicitudes pendientes',
      () async {
    final request = AssetDeleteRequest(
      id: 'req1',
      assetId: 'A1-0001',
      assetName: 'Bomba centrífuga',
      areaId: 'A1',
      status: DeletionRequestStatus.pending,
      reason: 'Obsolescencia',
      requestedByUserId: 'jefe',
      requestedByUserName: 'Jefe de Área',
      requestedAt: DateTime(2026, 8, 6),
      subtreeCount: 1,
    );

    when(() => repository.getPendingRequests())
        .thenAnswer((_) async => [request]);

    final result = await useCase(const NoParams());

    expect(result, hasLength(1));
    expect(result.first.assetId, 'A1-0001');
    verify(() => repository.getPendingRequests()).called(1);
  });
}
