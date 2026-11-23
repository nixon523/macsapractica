import '../../domain/entities/asset_attribute_definition.dart';

class AssetAttributeDefinitionModel extends AssetAttributeDefinition {
  const AssetAttributeDefinitionModel({
    required super.id,
    required super.name,
    super.description,
    super.defaultUnitId,
    super.defaultUnitCode,
    super.defaultUnitName,
    super.isActive = true,
  });

  factory AssetAttributeDefinitionModel.fromJson(Map<String, dynamic> json) {
    final rawDefaultUnitId = json['defaultUnitId'] ?? json['UnidadMedidaIdDefecto'];
    final defaultUnitId = rawDefaultUnitId != null
        ? (rawDefaultUnitId is int
            ? rawDefaultUnitId
            : int.tryParse(rawDefaultUnitId.toString()))
        : null;

    return AssetAttributeDefinitionModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? json['AtributoId']?.toString() ?? '0') ?? 0,
      name: (json['name'] ?? json['Nombre'] ?? '').toString().trim(),
      description: json['description']?.toString() ?? json['Descripcion']?.toString(),
      defaultUnitId: defaultUnitId,
      defaultUnitCode: json['defaultUnitCode']?.toString(),
      defaultUnitName: json['defaultUnitName']?.toString(),
      isActive: json['isActive'] == true ||
          json['Activo'] == true ||
          json['isActive'] == 1 ||
          json['Activo'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'defaultUnitId': defaultUnitId,
      'defaultUnitCode': defaultUnitCode,
      'defaultUnitName': defaultUnitName,
      'isActive': isActive,
    };
  }
}
