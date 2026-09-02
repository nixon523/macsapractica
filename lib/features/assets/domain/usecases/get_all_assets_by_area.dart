import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class GetAllAssetsByAreaParams {
  const GetAllAssetsByAreaParams({
    required this.areaId,
    this.forceRefresh = false,
  });

  final String areaId;
  final bool forceRefresh;
}

/// Devuelve TODOS los activos de un área (padres e hijos, excluyendo eliminados).
/// Usado para la vista de árbol jerárquico completo.
class GetAllAssetsByAreaUseCase
    implements UseCase<List<Asset>, GetAllAssetsByAreaParams> {
  const GetAllAssetsByAreaUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<List<Asset>> call(GetAllAssetsByAreaParams params) {
    return _repository.getAllAssetsByArea(
      params.areaId,
      forceRefresh: params.forceRefresh,
    );
  }
}
