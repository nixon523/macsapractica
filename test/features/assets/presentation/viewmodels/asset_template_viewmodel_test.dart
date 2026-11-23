import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/domain/entities/asset_template.dart';
import 'package:macsapractica/features/assets/domain/usecases/asset_template_usecases.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/asset_template_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAssetTemplatesUseCase extends Mock implements GetAssetTemplatesUseCase {}
class MockSaveAssetTemplateUseCase extends Mock implements SaveAssetTemplateUseCase {}
class MockInstantiateAssetTemplateUseCase extends Mock implements InstantiateAssetTemplateUseCase {}
class MockDeleteAssetTemplateUseCase extends Mock implements DeleteAssetTemplateUseCase {}

void main() {
  late MockGetAssetTemplatesUseCase getTemplates;
  late MockSaveAssetTemplateUseCase saveTemplate;
  late MockInstantiateAssetTemplateUseCase instantiateTemplate;
  late MockDeleteAssetTemplateUseCase deleteTemplate;
  late AssetTemplateViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(const SaveAssetTemplateParams(sourceAssetCode: 'A1', name: 'N1'));
    registerFallbackValue(const InstantiateAssetTemplateParams(templateId: 1, targetAreaId: 'A1'));
  });

  setUp(() {
    getTemplates = MockGetAssetTemplatesUseCase();
    saveTemplate = MockSaveAssetTemplateUseCase();
    instantiateTemplate = MockInstantiateAssetTemplateUseCase();
    deleteTemplate = MockDeleteAssetTemplateUseCase();

    viewModel = AssetTemplateViewModel(
      getTemplatesUseCase: getTemplates,
      saveTemplateUseCase: saveTemplate,
      instantiateTemplateUseCase: instantiateTemplate,
      deleteTemplateUseCase: deleteTemplate,
    );
  });

  test('loadTemplates carga las plantillas correctamente', () async {
    when(() => getTemplates()).thenAnswer((_) async => [
          const AssetTemplate(
            id: 1,
            name: 'Plantilla Bomba',
            sourceAssetCode: 'A001-001',
          ),
        ]);

    await viewModel.loadTemplates();

    expect(viewModel.templates.length, equals(1));
    expect(viewModel.templates.first.name, equals('Plantilla Bomba'));
    expect(viewModel.errorMessage, isEmpty);
  });

  test('saveFromAsset guarda y refresca plantillas', () async {
    when(() => saveTemplate(any())).thenAnswer((_) async => 1);
    when(() => getTemplates()).thenAnswer((_) async => []);

    final ok = await viewModel.saveFromAsset(
      sourceAssetCode: 'A001-001',
      name: 'Nueva Plantilla',
    );

    expect(ok, isTrue);
    verify(() => saveTemplate(any())).called(1);
  });

  test('instantiate llama al caso de uso de instanciación', () async {
    when(() => instantiateTemplate(any())).thenAnswer(
      (_) async => const InstantiateAssetTemplateResult(
        newRootAssetCode: 'A002-001',
        totalInstantiatedNodes: 4,
      ),
    );

    final res = await viewModel.instantiate(
      templateId: 1,
      targetAreaId: 'A002',
      newRootName: 'Bomba 2',
    );

    expect(res, isNotNull);
    expect(res!.newRootAssetCode, equals('A002-001'));
  });

  test('deleteTemplate invoca eliminación y actualiza lista local', () async {
    when(() => getTemplates()).thenAnswer((_) async => [
          const AssetTemplate(id: 10, name: 'T10', sourceAssetCode: 'A1'),
        ]);
    await viewModel.loadTemplates();
    expect(viewModel.templates.length, equals(1));

    when(() => deleteTemplate(10)).thenAnswer((_) async {});

    final ok = await viewModel.deleteTemplate(10);
    expect(ok, isTrue);
    expect(viewModel.templates.isEmpty, isTrue);
  });
}
