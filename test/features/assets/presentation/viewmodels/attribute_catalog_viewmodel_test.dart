import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:macsapractica/features/assets/domain/entities/asset_attribute_definition.dart';
import 'package:macsapractica/features/assets/domain/entities/unit_of_measure.dart';
import 'package:macsapractica/features/assets/domain/usecases/attribute_catalog_usecases.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/attribute_catalog_viewmodel.dart';

class MockGetAttributeCatalogUseCase extends Mock implements GetAttributeCatalogUseCase {}
class MockSaveAttributeDefinitionUseCase extends Mock implements SaveAttributeDefinitionUseCase {}
class MockDeleteAttributeDefinitionUseCase extends Mock implements DeleteAttributeDefinitionUseCase {}
class MockGetUnitsOfMeasureUseCase extends Mock implements GetUnitsOfMeasureUseCase {}
class MockSaveUnitOfMeasureUseCase extends Mock implements SaveUnitOfMeasureUseCase {}
class MockDeleteUnitOfMeasureUseCase extends Mock implements DeleteUnitOfMeasureUseCase {}

void main() {
  late MockGetAttributeCatalogUseCase mockGetAttrs;
  late MockSaveAttributeDefinitionUseCase mockSaveAttr;
  late MockDeleteAttributeDefinitionUseCase mockDeleteAttr;
  late MockGetUnitsOfMeasureUseCase mockGetUnits;
  late MockSaveUnitOfMeasureUseCase mockSaveUnit;
  late MockDeleteUnitOfMeasureUseCase mockDeleteUnit;
  late AttributeCatalogViewModel viewModel;

  setUp(() {
    mockGetAttrs = MockGetAttributeCatalogUseCase();
    mockSaveAttr = MockSaveAttributeDefinitionUseCase();
    mockDeleteAttr = MockDeleteAttributeDefinitionUseCase();
    mockGetUnits = MockGetUnitsOfMeasureUseCase();
    mockSaveUnit = MockSaveUnitOfMeasureUseCase();
    mockDeleteUnit = MockDeleteUnitOfMeasureUseCase();

    viewModel = AttributeCatalogViewModel(
      getAttributeCatalogUseCase: mockGetAttrs,
      saveAttributeDefinitionUseCase: mockSaveAttr,
      deleteAttributeDefinitionUseCase: mockDeleteAttr,
      getUnitsOfMeasureUseCase: mockGetUnits,
      saveUnitOfMeasureUseCase: mockSaveUnit,
      deleteUnitOfMeasureUseCase: mockDeleteUnit,
    );
  });

  group('AttributeCatalogViewModel', () {
    final tUnits = [
      const UnitOfMeasure(id: 1, code: 'kW', name: 'Kilovatios'),
      const UnitOfMeasure(id: 2, code: 'V', name: 'Voltios'),
    ];

    final tAttrs = [
      const AssetAttributeDefinition(
        id: 1,
        name: 'Potencia',
        defaultUnitId: 1,
        defaultUnitCode: 'kW',
      ),
      const AssetAttributeDefinition(
        id: 2,
        name: 'Voltaje',
        defaultUnitId: 2,
        defaultUnitCode: 'V',
      ),
    ];

    test('loadAll carga atributos y unidades exitosamente', () async {
      when(() => mockGetAttrs(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => tAttrs);
      when(() => mockGetUnits(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => tUnits);

      await viewModel.loadAll();

      expect(viewModel.attributes, tAttrs);
      expect(viewModel.units, tUnits);
      expect(viewModel.isLoading, false);
      expect(viewModel.errorMessage, isNull);
    });

    test('saveAttribute guarda un nuevo atributo y refresca la lista', () async {
      when(() => mockSaveAttr(
            id: any(named: 'id'),
            name: any(named: 'name'),
            description: any(named: 'description'),
            defaultUnitId: any(named: 'defaultUnitId'),
            isActive: any(named: 'isActive'),
          )).thenAnswer((_) async => const AssetAttributeDefinition(id: 3, name: 'Presión'));
      when(() => mockGetAttrs(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => [
                ...tAttrs,
                const AssetAttributeDefinition(id: 3, name: 'Presión'),
              ]);

      final ok = await viewModel.saveAttribute(name: 'Presión', defaultUnitId: 5);

      expect(ok, true);
      expect(viewModel.attributes.length, 3);
      expect(viewModel.isLoading, false);
    });

    test('deleteAttribute elimina un atributo y actualiza el estado', () async {
      when(() => mockDeleteAttr(1)).thenAnswer((_) async {});
      when(() => mockGetAttrs(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => [tAttrs[1]]);

      final ok = await viewModel.deleteAttribute(1);

      expect(ok, true);
      expect(viewModel.attributes.length, 1);
      verify(() => mockDeleteAttr(1)).called(1);
    });

    test('saveUnit guarda una nueva unidad de medida', () async {
      when(() => mockSaveUnit(
            id: any(named: 'id'),
            code: any(named: 'code'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
          )).thenAnswer((_) async => const UnitOfMeasure(id: 3, code: 'PSI', name: 'Libras'));
      when(() => mockGetUnits(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => [...tUnits, const UnitOfMeasure(id: 3, code: 'PSI', name: 'Libras')]);
      when(() => mockGetAttrs(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => tAttrs);

      final ok = await viewModel.saveUnit(code: 'PSI', name: 'Libras');

      expect(ok, true);
      expect(viewModel.units.length, 3);
    });

    test('deleteUnit elimina una unidad de medida', () async {
      when(() => mockDeleteUnit(1)).thenAnswer((_) async {});
      when(() => mockGetUnits(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => [tUnits[1]]);
      when(() => mockGetAttrs(includeInactive: any(named: 'includeInactive')))
          .thenAnswer((_) async => tAttrs);

      final ok = await viewModel.deleteUnit(1);

      expect(ok, true);
      expect(viewModel.units.length, 1);
      verify(() => mockDeleteUnit(1)).called(1);
    });
  });
}
