import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/features/assets/domain/entities/asset.dart';
import 'package:macsapractica/features/assets/domain/usecases/get_assets_by_area.dart';
import 'package:macsapractica/features/assets/domain/usecases/search_assets.dart';
import 'package:macsapractica/features/assets/presentation/states/asset_state.dart';
import 'package:macsapractica/features/assets/presentation/viewmodels/asset_list_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAssetsByAreaUseCase extends Mock implements GetAssetsByAreaUseCase {}

class MockSearchAssetsUseCase extends Mock implements SearchAssetsUseCase {}

void main() {
  late MockGetAssetsByAreaUseCase useCase;
  late MockSearchAssetsUseCase searchUseCase;
  late AssetListViewModel viewModel;

  const asset = Asset(
    id: 'A1-0001',
    name: 'Bomba centrífuga',
    areaId: 'A1',
    stationId: 'S1',
    level: AssetLevel.equipment,
    ancestors: [],
    status: AssetStatus.active,
    dynamicAttributes: {},
  );

  setUpAll(() {
    registerFallbackValue(const GetAssetsByAreaParams(areaId: 'A1'));
    registerFallbackValue(const SearchAssetsParams(areaId: 'A1'));
  });

  setUp(() {
    useCase = MockGetAssetsByAreaUseCase();
    searchUseCase = MockSearchAssetsUseCase();
    viewModel = AssetListViewModel(
      getAssetsByAreaUseCase: useCase,
      searchAssetsUseCase: searchUseCase,
    );
  });

  test('estado inicial es initial con lista vacía', () {
    expect(viewModel.state.viewState, ViewState.initial);
    expect(viewModel.state.assets, isEmpty);
  });

  test('fetchAssets pasa por loading y termina en success', () async {
    when(() => useCase(any())).thenAnswer((_) async => const [asset]);

    final future = viewModel.fetchAssets('A1');

    expect(viewModel.state.viewState, ViewState.loading);

    await future;

    expect(viewModel.state.viewState, ViewState.success);
    expect(viewModel.state.assets, [asset]);
  });

  test('fetchAssets marca error cuando el use case lanza', () async {
    when(() => useCase(any())).thenThrow(Exception('red caída'));

    await viewModel.fetchAssets('A1');

    expect(viewModel.state.viewState, ViewState.error);
    expect(viewModel.state.errorMessage, contains('red caída'));
  });

  test('fetchAssets con forceRefresh propaga el parámetro', () async {
    when(() => useCase(any())).thenAnswer((_) async => const [asset]);

    await viewModel.fetchAssets('A1', forceRefresh: true);

    final captured = verify(() => useCase(captureAny())).captured.single
        as GetAssetsByAreaParams;
    expect(captured.areaId, 'A1');
    expect(captured.forceRefresh, isTrue);
  });

  test('search pasa por loading y termina en success con estado isSearching', () async {
    when(() => searchUseCase(any())).thenAnswer((_) async => const [asset]);

    final future = viewModel.search('A1', query: 'bomba');

    expect(viewModel.state.viewState, ViewState.loading);
    expect(viewModel.state.isSearching, isTrue);

    await future;

    expect(viewModel.state.viewState, ViewState.success);
    expect(viewModel.state.assets, [asset]);
    expect(viewModel.state.isSearching, isTrue);
  });

  test('search tokeniza la query y propaga estado al use case', () async {
    when(() => searchUseCase(any())).thenAnswer((_) async => const [asset]);

    await viewModel.search('A1', query: 'Bomba centrífuga', status: AssetStatus.inactive);

    final captured = verify(() => searchUseCase(captureAny())).captured.single
        as SearchAssetsParams;
    expect(captured.areaId, 'A1');
    expect(captured.tokens, ['bomba', 'centrifuga']);
    expect(captured.status, AssetStatus.inactive);
    expect(viewModel.state.statusFilter, AssetStatus.inactive);
  });

  test('search marca error cuando el use case lanza', () async {
    when(() => searchUseCase(any())).thenThrow(Exception('índice no existe'));

    await viewModel.search('A1', query: 'x');

    expect(viewModel.state.viewState, ViewState.error);
    expect(viewModel.state.errorMessage, contains('índice no existe'));
  });

  test('fetchAssets resetea el modo búsqueda', () async {
    when(() => searchUseCase(any())).thenAnswer((_) async => const [asset]);
    when(() => useCase(any())).thenAnswer((_) async => const [asset]);

    await viewModel.search('A1', query: 'bomba');
    expect(viewModel.state.isSearching, isTrue);

    await viewModel.fetchAssets('A1');

    expect(viewModel.state.isSearching, isFalse);
    expect(viewModel.state.statusFilter, isNull);
  });
}
