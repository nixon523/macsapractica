import '../../../../core/usecases/usecase.dart';
import '../entities/asset.dart';
import '../repositories/asset_repository.dart';

class FindAssetBySerialParams {
  const FindAssetBySerialParams(this.serial);

  final String serial;
}

/// Busca globalmente un equipo por su número de serie físico.
///
/// Retorna el [Asset] existente si el serial ya está registrado (y el activo
/// no está dado de baja), o `null` si el serial está disponible.
///
/// Se usa desde el formulario de creación con debounce para mostrar al
/// operador una advertencia no bloqueante antes de guardar.
class FindAssetBySerialUseCase
    implements UseCase<Asset?, FindAssetBySerialParams> {
  const FindAssetBySerialUseCase(this._repository);

  final AssetRepository _repository;

  @override
  Future<Asset?> call(FindAssetBySerialParams params) {
    final serial = params.serial.trim();
    if (serial.isEmpty) return Future.value(null);
    return _repository.findAssetBySerial(serial);
  }
}
