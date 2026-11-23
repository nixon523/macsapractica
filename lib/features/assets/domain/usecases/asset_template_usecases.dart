import '../../../../core/error/failures.dart';
import '../entities/asset_template.dart';
import '../repositories/asset_template_repository.dart';

class GetAssetTemplatesUseCase {
  const GetAssetTemplatesUseCase(this._repository);

  final AssetTemplateRepository _repository;

  Future<List<AssetTemplate>> call() {
    return _repository.getTemplates();
  }
}

class SaveAssetTemplateParams {
  const SaveAssetTemplateParams({
    required this.sourceAssetCode,
    required this.name,
    this.description,
  });

  final String sourceAssetCode;
  final String name;
  final String? description;
}

class SaveAssetTemplateUseCase {
  const SaveAssetTemplateUseCase(this._repository);

  final AssetTemplateRepository _repository;

  Future<int> call(SaveAssetTemplateParams params) {
    if (params.sourceAssetCode.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'El código de activo origen es obligatorio.',
      );
    }
    if (params.name.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'El nombre de la plantilla es obligatorio.',
      );
    }

    return _repository.saveTemplateFromAsset(
      sourceAssetCode: params.sourceAssetCode.trim(),
      name: params.name.trim(),
      description: params.description?.trim(),
    );
  }
}

class InstantiateAssetTemplateParams {
  const InstantiateAssetTemplateParams({
    required this.templateId,
    required this.targetAreaId,
    this.newRootName,
    this.newSerial,
    this.observations,
    this.copyAttributes = true,
  });

  final int templateId;
  final String targetAreaId;
  final String? newRootName;
  final String? newSerial;
  final String? observations;
  final bool copyAttributes;
}

class InstantiateAssetTemplateResult {
  const InstantiateAssetTemplateResult({
    required this.newRootAssetCode,
    required this.totalInstantiatedNodes,
  });

  final String newRootAssetCode;
  final int totalInstantiatedNodes;

  factory InstantiateAssetTemplateResult.fromMap(Map<String, dynamic> map) {
    return InstantiateAssetTemplateResult(
      newRootAssetCode: (map['NuevoCodigoActivoRaiz'] ??
              map['nuevoCodigoActivoRaiz'] ??
              map['newRootAssetCode'] ??
              map['newAssetCode'] ??
              '')
          .toString(),
      totalInstantiatedNodes: int.tryParse((map['TotalNodosInstanciados'] ??
                  map['totalNodosInstanciados'] ??
                  map['totalInstantiatedNodes'] ??
                  1)
              .toString()) ??
          1,
    );
  }
}

class InstantiateAssetTemplateUseCase {
  const InstantiateAssetTemplateUseCase(this._repository);

  final AssetTemplateRepository _repository;

  Future<InstantiateAssetTemplateResult> call(
      InstantiateAssetTemplateParams params) async {
    if (params.templateId <= 0) {
      throw const ValidationFailure(
        message: 'ID de plantilla inválido.',
      );
    }
    if (params.targetAreaId.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'El área de destino es obligatoria.',
      );
    }

    final rawResult = await _repository.instantiateTemplate(
      templateId: params.templateId,
      targetAreaId: params.targetAreaId.trim(),
      newRootName: params.newRootName?.trim(),
      newSerial: params.newSerial?.trim(),
      observations: params.observations?.trim(),
      copyAttributes: params.copyAttributes,
    );

    return InstantiateAssetTemplateResult.fromMap(rawResult);
  }
}

class DeleteAssetTemplateUseCase {
  const DeleteAssetTemplateUseCase(this._repository);

  final AssetTemplateRepository _repository;

  Future<void> call(int templateId) {
    return _repository.deleteTemplate(templateId);
  }
}
