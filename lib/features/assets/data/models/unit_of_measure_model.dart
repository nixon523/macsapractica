import '../../domain/entities/unit_of_measure.dart';

class UnitOfMeasureModel extends UnitOfMeasure {
  const UnitOfMeasureModel({
    required super.id,
    required super.code,
    required super.name,
    super.isActive = true,
  });

  factory UnitOfMeasureModel.fromJson(Map<String, dynamic> json) {
    return UnitOfMeasureModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? json['UnidadMedidaId']?.toString() ?? '0') ?? 0,
      code: (json['code'] ?? json['Codigo'] ?? '').toString().trim(),
      name: (json['name'] ?? json['Nombre'] ?? '').toString().trim(),
      isActive: json['isActive'] == true ||
          json['Activo'] == true ||
          json['isActive'] == 1 ||
          json['Activo'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'isActive': isActive,
    };
  }
}
