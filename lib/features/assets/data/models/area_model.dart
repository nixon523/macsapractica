import '../../domain/entities/area.dart';

class AreaModel extends Area {
  const AreaModel({
    required super.id,
    required super.name,
    required super.costCenter,
    super.assetCounter = 0,
  });

  factory AreaModel.fromJson(Map<String, dynamic> map, [String? docId]) {
    final areaId = docId ??
        (map['areaId'] ?? map['AreaId'] ?? map['id'] ?? map['Id'] ?? '')
            ?.toString() ??
        '';
    final assetCounter = map['assetCounter'] ?? map['AssetCounter'] ?? 0;

    return AreaModel(
      id: areaId,
      name: (map['name'] ?? map['Name'] ?? '').toString(),
      costCenter: (map['costCenter'] ?? map['CostCenter'] ?? '').toString(),
      assetCounter: assetCounter is int
          ? assetCounter
          : int.tryParse(assetCounter.toString()) ?? 0,
    );
  }

  factory AreaModel.fromFirestore(Map<String, dynamic> map, String docId) {
    return AreaModel.fromJson(map, docId);
  }

  factory AreaModel.fromEntity(Area area) {
    return AreaModel(
      id: area.id,
      name: area.name,
      costCenter: area.costCenter,
      assetCounter: area.assetCounter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'areaId': id,
      'name': name,
      'costCenter': costCenter,
      'assetCounter': assetCounter,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'costCenter': costCenter,
      'assetCounter': assetCounter,
    };
  }
}
