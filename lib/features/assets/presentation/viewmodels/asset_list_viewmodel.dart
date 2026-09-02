import 'package:flutter/foundation.dart';

import '../../domain/entities/asset.dart';
import '../../domain/usecases/get_all_assets_by_area.dart';
import '../../domain/usecases/get_assets_by_area.dart';
import '../../domain/usecases/get_assets_by_parent.dart';
import '../../domain/usecases/search_assets.dart';
import '../states/asset_state.dart';

class AssetListViewModel extends ChangeNotifier {
  AssetListViewModel({
    required this.getAssetsByAreaUseCase,
    required GetAllAssetsByAreaUseCase getAllAssetsByAreaUseCase,
    GetAssetsByParentUseCase? getAssetsByParentUseCase,
    SearchAssetsUseCase? searchAssetsUseCase,
  })  : _getAllAssetsByAreaUseCase = getAllAssetsByAreaUseCase,
        _getAssetsByParentUseCase = getAssetsByParentUseCase,
        _searchAssetsUseCase = searchAssetsUseCase;

  final GetAssetsByAreaUseCase getAssetsByAreaUseCase;
  final GetAllAssetsByAreaUseCase _getAllAssetsByAreaUseCase;
  final GetAssetsByParentUseCase? _getAssetsByParentUseCase;
  final SearchAssetsUseCase? _searchAssetsUseCase;

  AssetState _state = const AssetState();
  AssetState get state => _state;

  Future<void> fetchAssets(
    String areaId, {
    String? parentAssetId,
    bool forceRefresh = false,
  }) async {
    _state = _state.copyWith(
      viewState: ViewState.loading,
      errorMessage: '',
      isSearching: false,
      statusFilter: null,
    );
    notifyListeners();

    try {
      final List<Asset> assets;
      if (parentAssetId == null) {
        assets = await getAssetsByAreaUseCase(
          GetAssetsByAreaParams(
            areaId: areaId,
            forceRefresh: forceRefresh,
          ),
        );
      } else {
        final useCase = _getAssetsByParentUseCase;
        if (useCase == null) {
          throw StateError(
            'GetAssetsByParentUseCase no configurado para el drill-down.',
          );
        }
        assets = await useCase(
          GetAssetsByParentParams(
            areaId: areaId,
            parentAssetId: parentAssetId,
            forceRefresh: forceRefresh,
          ),
        );
      }

      _state = _state.copyWith(
        viewState: ViewState.success,
        assets: assets,
      );
    } catch (e) {
      _state = _state.copyWith(
        viewState: ViewState.error,
        errorMessage: e.toString(),
      );
    } finally {
      notifyListeners();
    }
  }

  /// Obtiene TODOS los activos del área (padres e hijos) y los ordena
  /// jerárquicamente para la vista de árbol completo.
  Future<void> fetchAllAssets(
    String areaId, {
    AssetStatus? status,
  }) async {
    _state = _state.copyWith(
      viewState: ViewState.loading,
      errorMessage: '',
      isSearching: true,
      statusFilter: status,
    );
    notifyListeners();

    try {
      var assets = await _getAllAssetsByAreaUseCase(
        GetAllAssetsByAreaParams(areaId: areaId),
      );

      // Filtrar por estado si se especifica
      if (status != null) {
        assets = assets.where((a) => a.status == status).toList();
      }

      final sorted = sortHierarchically(assets);

      _state = _state.copyWith(
        viewState: ViewState.success,
        assets: sorted,
      );
    } catch (e) {
      _state = _state.copyWith(
        viewState: ViewState.error,
        errorMessage: e.toString(),
      );
    } finally {
      notifyListeners();
    }
  }

  /// Búsqueda server-side por tokens y estado (índices compuestos).
  /// Con query vacía y sin estado, la consulta se delega igualmente al server
  /// con solo el filtro de área (ordenada por nombre).
  Future<void> search(
    String areaId, {
    String query = '',
    AssetStatus? status,
  }) async {
    final useCase = _searchAssetsUseCase;
    if (useCase == null) {
      _state = _state.copyWith(
        viewState: ViewState.error,
        errorMessage: 'SearchAssetsUseCase no configurado.',
        isSearching: true,
      );
      notifyListeners();
      return;
    }

    final tokens = query.trim().isEmpty ? const <String>[] : Asset.tokenize(query);

    // Si no hay tokens de búsqueda, obtener todos los activos y filtrar por estado
    if (tokens.isEmpty) {
      return fetchAllAssets(areaId, status: status);
    }

    _state = _state.copyWith(
      viewState: ViewState.loading,
      errorMessage: '',
      isSearching: true,
      statusFilter: status,
    );
    notifyListeners();

    try {
      final rawAssets = await useCase(
        SearchAssetsParams(
          areaId: areaId,
          tokens: tokens,
          status: status,
        ),
      );

      // Aplicar filtro de estado localmente (el API no lo soporta)
      final filteredAssets = status != null
          ? rawAssets.where((a) => a.status == status).toList()
          : rawAssets;

      final assets = sortHierarchically(filteredAssets);

      _state = _state.copyWith(
        viewState: ViewState.success,
        assets: assets,
      );
    } catch (e) {
      _state = _state.copyWith(
        viewState: ViewState.error,
        errorMessage: e.toString(),
      );
    } finally {
      notifyListeners();
    }
  }

  /// Ordena una lista de activos jerárquicamente en recorrido DFS:
  /// Cada padre va seguido inmediatamente por sus activos hijos, con sangría visual.
  static List<Asset> sortHierarchically(List<Asset> assets) {
    if (assets.isEmpty) return const [];

    final assetMap = {for (final a in assets) a.id: a};
    final childrenMap = <String?, List<Asset>>{};

    for (final a in assets) {
      final parentKey = (a.parentAssetId != null && assetMap.containsKey(a.parentAssetId))
          ? a.parentAssetId
          : null;
      childrenMap.putIfAbsent(parentKey, () => []).add(a);
    }

    for (final list in childrenMap.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    final sorted = <Asset>[];
    final visited = <String>{};

    void traverse(String? parentId) {
      final children = childrenMap[parentId] ?? [];
      for (final child in children) {
        if (visited.add(child.id)) {
          sorted.add(child);
          traverse(child.id);
        }
      }
    }

    traverse(null);

    for (final a in assets) {
      if (!visited.contains(a.id)) {
        sorted.add(a);
      }
    }

    return sorted;
  }
}
