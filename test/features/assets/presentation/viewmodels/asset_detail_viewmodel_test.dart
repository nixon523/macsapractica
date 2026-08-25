import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:macsapractica/features/assets/domain/repositories/asset_repository.dart';
import 'package:macsapractica/features/assets/domain/usecases/get_assets_by_parent.dart';
import 'package:macsapractica/features/assets/domain/usecases/reactivate_asset_usecase.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/asset_detail_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAssetsByParentUseCase extends Mock
    implements GetAssetsByParentUseCase {}

class MockReactivateAssetUseCase extends Mock implements ReactivateAssetUseCase {}

class MockAssetRepository extends Mock implements AssetRepository {}

void main() {
  late MockGetAssetsByParentUseCase getChildrenUseCase;
  late MockReactivateAssetUseCase reactivateUseCase;
  late MockAssetRepository mockAssetRepository;
  late AssetDetailViewModel viewModel;

  const child = Asset(
    id: 'A1-0001-01',
    name: 'Motor eléctrico',
    areaId: 'A1',
    stationId: 'S1',
    parentAssetId: 'A1-0001',
    level: AssetLevel.subEquipment,
    ancestors: ['A1-0001'],
    status: AssetStatus.active,
    dynamicAttributes: {},
  );

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
    registerFallbackValue(const GetAssetsByParentParams(areaId: 'A1'));
    registerFallbackValue(
      const ReactivateAssetParams(
        asset: deactivatedAsset,
        userId: 'u1',
        userName: 'Admin',
      ),
    );
    registerFallbackValue(AssetStatus.inactive);
  });

  setUp(() {
    getChildrenUseCase = MockGetAssetsByParentUseCase();
    reactivateUseCase = MockReactivateAssetUseCase();
    mockAssetRepository = MockAssetRepository();
    viewModel = AssetDetailViewModel(
      getAssetsByParentUseCase: getChildrenUseCase,
      reactivateAssetUseCase: reactivateUseCase,
      assetRepository: mockAssetRepository,
    );
  });

  group('loadChildren', () {
    test('estado inicial es initial con hijos vacíos', () {
      expect(viewModel.viewState, DetailViewState.initial);
      expect(viewModel.children, isEmpty);
    });

    test('pasa por loading y termina en success con los hijos', () async {
      when(() => getChildrenUseCase(any()))
          .thenAnswer((_) async => const [child]);

      final future = viewModel.loadChildren(
        areaId: 'A1',
        parentAssetId: 'A1-0001',
      );

      expect(viewModel.viewState, DetailViewState.loading);

      await future;

      expect(viewModel.viewState, DetailViewState.success);
      expect(viewModel.children, const [child]);
      expect(viewModel.errorMessage, isEmpty);
    });

    test('marca error cuando el use case lanza', () async {
      when(() => getChildrenUseCase(any()))
          .thenThrow(Exception('red caída'));

      await viewModel.loadChildren(
        areaId: 'A1',
        parentAssetId: 'A1-0001',
      );

      expect(viewModel.viewState, DetailViewState.error);
      expect(viewModel.errorMessage, contains('red caída'));
    });
  });

  group('reactivate', () {
    test('devuelve true y limpia el error cuando la reactivación es exitosa',
        () async {
      when(() => reactivateUseCase(any())).thenAnswer((_) async {});

      final ok = await viewModel.reactivate(
        asset: deactivatedAsset,
        userId: 'u1',
        userName: 'Admin',
      );

      expect(ok, isTrue);
      expect(viewModel.isReactivating, isFalse);
      expect(viewModel.reactivationError, isNull);
    });

    test('devuelve false y guarda el error cuando falla', () async {
      when(() => reactivateUseCase(any()))
          .thenThrow(Exception('sin conexión'));

      final ok = await viewModel.reactivate(
        asset: deactivatedAsset,
        userId: 'u1',
        userName: 'Admin',
      );

      expect(ok, isFalse);
      expect(viewModel.isReactivating, isFalse);
      expect(viewModel.reactivationError, contains('sin conexión'));
    });
  });

  group('toggleActiveStatus', () {
    test('inactiva o reactiva el activo delegando en el repositorio', () async {
      when(() => mockAssetRepository.toggleAssetActiveStatus(
            assetId: any(named: 'assetId'),
            newStatus: any(named: 'newStatus'),
            reason: any(named: 'reason'),
            userId: any(named: 'userId'),
            userName: any(named: 'userName'),
          )).thenAnswer((_) async {});

      final ok = await viewModel.toggleActiveStatus(
        assetId: 'A1-0001',
        newStatus: AssetStatus.inactive,
        reason: 'Falla en rodamiento',
        userId: 'u1',
        userName: 'Admin',
      );

      expect(ok, isTrue);
      expect(viewModel.viewState, DetailViewState.success);
      expect(viewModel.errorMessage, isEmpty);
    });

    test('captura error cuando el repositorio falla al cambiar estado', () async {
      when(() => mockAssetRepository.toggleAssetActiveStatus(
            assetId: any(named: 'assetId'),
            newStatus: any(named: 'newStatus'),
            reason: any(named: 'reason'),
            userId: any(named: 'userId'),
            userName: any(named: 'userName'),
          )).thenThrow(Exception('Error de base de datos'));

      final ok = await viewModel.toggleActiveStatus(
        assetId: 'A1-0001',
        newStatus: AssetStatus.inactive,
        reason: 'Falla en rodamiento',
        userId: 'u1',
        userName: 'Admin',
      );

      expect(ok, isFalse);
      expect(viewModel.viewState, DetailViewState.error);
      expect(viewModel.errorMessage, contains('Error de base de datos'));
    });
  });
}
