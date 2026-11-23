import '../../domain/entities/brand.dart';

class BrandModel extends Brand {
  const BrandModel({
    required super.id,
    required super.name,
    super.description,
    super.isActive,
    super.totalAssetsAssociated,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }

    return BrandModel(
      id: parseInt(json['id'] ?? json['MarcaId']),
      name: (json['name'] ?? json['Nombre'] ?? '').toString(),
      description: json['description']?.toString() ?? json['Descripcion']?.toString(),
      isActive: json['isActive'] as bool? ??
          (json['Activo'] == 1 || json['Activo'] == true || json['Activo'] == '1'),
      totalAssetsAssociated: parseInt(json['totalAssetsAssociated'] ?? json['TotalActivosAsociados']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'isActive': isActive,
    };
  }
}
