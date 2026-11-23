import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/asset_repository.dart';

class CloneAssetTreeParams {
  const CloneAssetTreeParams({
    required this.sourceAssetCode,
    required this.targetAreaId,
    this.newRootName,
    this.newSerial,
    this.observations,
    this.copyAttributes = true,
  });

  final String sourceAssetCode;
  final String targetAreaId;
  final String? newRootName;
  final String? newSerial;
  final String? observations;
  final bool copyAttributes;
}

class CloneAssetTreeResult {
  const CloneAssetTreeResult({
    required this.newRootAssetCode,
    required this.totalClonedNodes,
  });

  final String newRootAssetCode;
  final int totalClonedNodes;

  factory CloneAssetTreeResult.fromMap(Map<String, dynamic> map) {
    return CloneAssetTreeResult(
      newRootAssetCode: (map['NuevoCodigoActivoRaiz'] ??
              map['nuevoCodigoActivoRaiz'] ??
              map['newRootAssetCode'] ??
              map['newAssetCode'] ??
              '')
          .toString(),
      totalClonedNodes: int.tryParse((map['TotalNodosClonados'] ??
                  map['totalNodosClonados'] ??
                  map['totalClonedNodes'] ??
                  1)
              .toString()) ??
          1,
    );
  }
}

class CloneAssetTreeUseCase
    implements UseCase<CloneAssetTreeResult, CloneAssetTreeParams> {
  const CloneAssetTreeUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<CloneAssetTreeResult> call(CloneAssetTreeParams params) async {
    if (params.sourceAssetCode.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'El código de activo origen es requerido para clonar.',
      );
    }
    if (params.targetAreaId.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'El área de destino es requerida.',
      );
    }

    final rawResult = await _repository.cloneAssetTree(
      sourceAssetCode: params.sourceAssetCode.trim(),
      targetAreaId: params.targetAreaId.trim(),
      newRootName: params.newRootName?.trim(),
      newSerial: params.newSerial?.trim(),
      observations: params.observations?.trim(),
      copyAttributes: params.copyAttributes,
    );

    return CloneAssetTreeResult.fromMap(rawResult);
  }
}
