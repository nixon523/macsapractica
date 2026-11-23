import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/assets/domain/repositories/asset_repository.dart';
import 'package:macsapractica/features/assets/domain/usecases/clone_asset_tree_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetRepository extends Mock implements AssetRepository {}

void main() {
  late MockAssetRepository repository;
  late CloneAssetTreeUseCase useCase;

  setUp(() {
    repository = MockAssetRepository();
    useCase = CloneAssetTreeUseCase(repository);
  });

  test('valida que el código de activo origen no esté vacío', () {
    expect(
      () => useCase(const CloneAssetTreeParams(
        sourceAssetCode: '   ',
        targetAreaId: 'A002',
      )),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('valida que el área de destino no esté vacía', () {
    expect(
      () => useCase(const CloneAssetTreeParams(
        sourceAssetCode: 'A001-001',
        targetAreaId: '',
      )),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('delega la clonación al repositorio con los parámetros provistos', () async {
    when(() => repository.cloneAssetTree(
          sourceAssetCode: 'A001-001',
          targetAreaId: 'A002',
          newRootName: 'Clasificadora 2',
          newSerial: 'SER-999',
          observations: 'Clonada para línea 2',
          copyAttributes: true,
        )).thenAnswer((_) async => {
          'NuevoCodigoActivoRaiz': 'A002-001',
          'TotalNodosClonados': 4,
        });

    final result = await useCase(const CloneAssetTreeParams(
      sourceAssetCode: 'A001-001',
      targetAreaId: 'A002',
      newRootName: 'Clasificadora 2',
      newSerial: 'SER-999',
      observations: 'Clonada para línea 2',
      copyAttributes: true,
    ));

    expect(result.newRootAssetCode, equals('A002-001'));
    expect(result.totalClonedNodes, equals(4));

    verify(() => repository.cloneAssetTree(
          sourceAssetCode: 'A001-001',
          targetAreaId: 'A002',
          newRootName: 'Clasificadora 2',
          newSerial: 'SER-999',
          observations: 'Clonada para línea 2',
          copyAttributes: true,
        )).called(1);
  });
}
