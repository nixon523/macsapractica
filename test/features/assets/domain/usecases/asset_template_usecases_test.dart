import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/core/error/failures.dart';
import 'package:macsapractica/features/assets/domain/entities/asset_template.dart';
import 'package:macsapractica/features/assets/domain/repositories/asset_template_repository.dart';
import 'package:macsapractica/features/assets/domain/usecases/asset_template_usecases.dart';
import 'package:mocktail/mocktail.dart';

class MockAssetTemplateRepository extends Mock implements AssetTemplateRepository {}

void main() {
  late MockAssetTemplateRepository repository;
  late GetAssetTemplatesUseCase getTemplatesUseCase;
  late SaveAssetTemplateUseCase saveTemplateUseCase;
  late InstantiateAssetTemplateUseCase instantiateUseCase;
  late DeleteAssetTemplateUseCase deleteUseCase;

  setUp(() {
    repository = MockAssetTemplateRepository();
    getTemplatesUseCase = GetAssetTemplatesUseCase(repository);
    saveTemplateUseCase = SaveAssetTemplateUseCase(repository);
    instantiateUseCase = InstantiateAssetTemplateUseCase(repository);
    deleteUseCase = DeleteAssetTemplateUseCase(repository);
  });

  test('GetAssetTemplatesUseCase retorna lista de plantillas', () async {
    when(() => repository.getTemplates()).thenAnswer((_) async => [
          const AssetTemplate(
            id: 1,
            name: 'Plantilla Molino',
            sourceAssetCode: 'A001-001',
            totalNodes: 5,
          ),
        ]);

    final result = await getTemplatesUseCase();
    expect(result.length, equals(1));
    expect(result.first.name, equals('Plantilla Molino'));
  });

  test('SaveAssetTemplateUseCase valida campos obligatorios', () {
    expect(
      () => saveTemplateUseCase(const SaveAssetTemplateParams(
        sourceAssetCode: '',
        name: 'Molino',
      )),
      throwsA(isA<ValidationFailure>()),
    );

    expect(
      () => saveTemplateUseCase(const SaveAssetTemplateParams(
        sourceAssetCode: 'A001-001',
        name: '   ',
      )),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('InstantiateAssetTemplateUseCase valida templateId y targetAreaId', () {
    expect(
      () => instantiateUseCase(const InstantiateAssetTemplateParams(
        templateId: 0,
        targetAreaId: 'A001',
      )),
      throwsA(isA<ValidationFailure>()),
    );

    expect(
      () => instantiateUseCase(const InstantiateAssetTemplateParams(
        templateId: 1,
        targetAreaId: '  ',
      )),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('InstantiateAssetTemplateUseCase delega al repositorio e interpreta respuesta', () async {
    when(() => repository.instantiateTemplate(
          templateId: 1,
          targetAreaId: 'A003',
          newRootName: 'Molino Nuevo',
          newSerial: null,
          observations: null,
          copyAttributes: true,
        )).thenAnswer((_) async => {
          'NuevoCodigoActivoRaiz': 'A003-005',
          'TotalNodosInstanciados': 3,
        });

    final res = await instantiateUseCase(const InstantiateAssetTemplateParams(
      templateId: 1,
      targetAreaId: 'A003',
      newRootName: 'Molino Nuevo',
      copyAttributes: true,
    ));

    expect(res.newRootAssetCode, equals('A003-005'));
    expect(res.totalInstantiatedNodes, equals(3));
  });

  test('DeleteAssetTemplateUseCase delega eliminación al repositorio', () async {
    when(() => repository.deleteTemplate(1)).thenAnswer((_) async {});

    await deleteUseCase(1);
    verify(() => repository.deleteTemplate(1)).called(1);
  });
}
