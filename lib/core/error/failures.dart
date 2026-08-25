import '../../../features/assets/domain/entities/asset.dart';

abstract class Failure {
  const Failure({this.message = 'Ha ocurrido un error inesperado.'});

  final String message;

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Error de conexión con el servidor.'});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Error al leer la información local.'});
}

class ValidationFailure extends Failure {
  const ValidationFailure({super.message = 'Los datos proporcionados no son válidos.'});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'No tienes permisos para realizar esta acción.'});
}

/// Se lanza cuando un equipo nuevo intentar usar un serial que ya existe
/// globalmente en otra área o en la misma.
///
/// Es una advertencia NO bloqueante: la UI muestra el activo en conflicto
/// ([conflictingAsset]) para que el operador decida si continuar o corregir.
class SerialConflictFailure extends Failure {
  const SerialConflictFailure({
    required this.conflictingAsset,
    super.message = 'Ya existe un activo con este número de serie.',
  });

  /// El activo que ya tiene el mismo serial, incluyendo su ID y área.
  final Asset conflictingAsset;
}
