import 'dart:convert';

import '../../domain/entities/asset.dart';

class AssetModel extends Asset {
  const AssetModel({
    required super.id,
    required super.name,
    super.brand,
    super.model,
    required super.areaId,
    required super.stationId,
    super.parentAssetId,
    required super.level,
    required super.ancestors,
    required super.status,
    super.transferredToId,
    required super.dynamicAttributes,
    super.imageData,
    super.serial,
    super.observations,
    super.statusHistory = const [],
    super.createdAt,
    super.esEquipoProceso = false,
  });

  factory AssetModel.fromJson(Map<String, dynamic> map, [String? docId]) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      try {
        return (d as dynamic).toDate();
      } catch (_) {
        if (d is String) return DateTime.tryParse(d);
      }
      return null;
    }

    final id = docId ??
        (map['CodigoActivo'] ??
                map['codigoActivo'] ??
                map['assetCode'] ??
                map['AssetCode'] ??
                map['id'] ??
                map['Id'] ??
                '')
            ?.toString() ??
        '';

    final statusStr =
        (map['status'] ?? map['Status'] ?? map['Estado'] ?? map['estado'] ?? 'active').toString();
    final status = AssetStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => AssetStatus.active,
    );

    final areaId = (map['areaId'] ?? map['AreaId'] ?? map['area'] ?? map['Area'] ?? '').toString();
    final stationId = (map['stationId'] ?? map['StationId'] ?? map['EstacionId'] ?? map['estacionId'] ?? '').toString();
    final parentAssetId =
        (map['parentAssetId'] ?? map['ParentAssetCode'] ?? map['parentAssetCode'] ?? map['CodigoActivoPadre'] ?? map['codigoActivoPadre'])
            ?.toString();

    final levelStr =
        (map['level'] ?? map['Level'] ?? map['Nivel'] ?? map['nivel'] ?? 'equipment').toString();
    final level = AssetLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == levelStr.toLowerCase(),
      orElse: () => AssetLevel.equipment,
    );

    // Ancestors: puede venir como lista o como string separado por comas (AncestorsPath de SQL o RutaAncestros)
    List<String> ancestors = [];
    final rawAncestors = map['ancestors'] ?? map['Ancestors'];
    if (rawAncestors is List) {
      ancestors = rawAncestors.map((e) => e.toString()).toList();
    } else {
      final path =
          (map['ancestorsPath'] ?? map['AncestorsPath'] ?? map['RutaAncestros'] ?? map['rutaAncestros'])?.toString();
      if (path != null && path.trim().isNotEmpty) {
        ancestors = path
            .split(RegExp(r'[/,]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    // DynamicAttributes: puede venir como Map o como JSON String (AtributosDinamicos)
    Map<String, dynamic> dynamicAttrs = {};
    final rawAttrs = map['dynamicAttributes'] ?? map['DynamicAttributes'] ?? map['AtributosDinamicos'] ?? map['atributosDinamicos'];
    if (rawAttrs is Map) {
      dynamicAttrs = Map<String, dynamic>.from(rawAttrs);
    } else if (rawAttrs is String && rawAttrs.isNotEmpty) {
      try {
        dynamicAttrs = Map<String, dynamic>.from(jsonDecode(rawAttrs) as Map);
      } catch (_) {}
    }

    final createdAt = parseDate(map['CreadoEn'] ??
            map['creadoEn'] ??
            map['createdAt'] ??
            map['CreatedAt']) ??
        parseDate(map['ActualizadoEn'] ??
            map['actualizadoEn'] ??
            map['updatedAt'] ??
            map['UpdatedAt']);

    final rawHistory = map['statusHistory'] ?? map['StatusHistory'];
    var history = <AssetStatusPeriod>[];
    if (rawHistory is List) {
      history = rawHistory
          .map((e) => e is Map
              ? AssetStatusPeriod.fromMap(Map<String, dynamic>.from(e))
              : null)
          .whereType<AssetStatusPeriod>()
          .toList();
    }

    if (history.isEmpty && status != AssetStatus.deleted) {
      final start = createdAt ?? DateTime(2026, 8, 1);
      history = [
        AssetStatusPeriod(
          status: status,
          startedAt: start,
          areaId: areaId,
          reason: 'Registro inicial del activo',
        ),
      ];
    }

    final serial = (map['serial'] ?? map['Serial'] ?? map['Serie'] ?? map['serie'])?.toString();
    final transferredToId =
        (map['transferredToId'] ?? map['TransferredToId'])?.toString();
    final brand = (map['brand'] ?? map['Brand'] ?? map['Marca'] ?? map['marca'])?.toString();
    final model = (map['model'] ?? map['Model'] ?? map['Modelo'] ?? map['modelo'])?.toString();
    final imageData = (map['imageData'] ?? map['ImageData'] ?? map['DatosImagen'] ?? map['datosImagen'])?.toString();
    final observations = (map['observations'] ?? map['Observations'] ?? map['Observaciones'] ?? map['observaciones'])?.toString();
    final esEquipoProceso = _parseBool(
      map['esEquipoProceso'] ?? map['EsEquipoProceso'] ?? map['es_equipo_proceso'],
    );

    return AssetModel(
      id: id,
      name: (map['name'] ?? map['Name'] ?? map['Nombre'] ?? map['nombre'] ?? '').toString(),
      brand: brand,
      model: model,
      areaId: areaId,
      stationId: stationId,
      parentAssetId: parentAssetId,
      level: level,
      ancestors: ancestors,
      status: status,
      transferredToId: transferredToId,
      dynamicAttributes: dynamicAttrs,
      imageData: imageData,
      serial: serial,
      observations: observations,
      statusHistory: history,
      createdAt: createdAt,
      esEquipoProceso: esEquipoProceso,
    );
  }

  factory AssetModel.fromFirestore(Map<String, dynamic> map, String docId) {
    return AssetModel.fromJson(map, docId);
  }

  factory AssetModel.fromEntity(Asset asset) {
    return AssetModel(
      id: asset.id,
      name: asset.name,
      brand: asset.brand,
      model: asset.model,
      areaId: asset.areaId,
      stationId: asset.stationId,
      parentAssetId: asset.parentAssetId,
      level: asset.level,
      ancestors: asset.ancestors,
      status: asset.status,
      transferredToId: asset.transferredToId,
      dynamicAttributes: asset.dynamicAttributes,
      imageData: asset.imageData,
      serial: asset.serial,
      observations: asset.observations,
      statusHistory: asset.statusHistory,
      createdAt: asset.createdAt,
      esEquipoProceso: asset.esEquipoProceso,
    );
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    return v.toString().toLowerCase() == 'true' || v.toString() == '1';
  }

  /// Tokens de búsqueda "contiene" de un activo (ID, nombre, serial, marca, modelo).
  static List<String> buildSearchTerms({
    required String id,
    required String name,
    String? serial,
    String? brand,
    String? model,
  }) {
    return Asset.tokenize(
      '$id $name ${serial ?? ''} ${brand ?? ''} ${model ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assetCode': id,
      'name': name,
      'brand': brand,
      'model': model,
      'areaId': areaId,
      'stationId': stationId,
      'parentAssetCode': parentAssetId,
      'level': level.name,
      'status': status.name,
      'serial': serial,
      'observations': observations,
      'dynamicAttributes': dynamicAttributes,
      'imageData': imageData,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'areaId': areaId,
      'stationId': stationId,
      'parentAssetId': parentAssetId,
      'level': level.name,
      'ancestors': ancestors,
      'status': status.name,
      'transferredToId': transferredToId,
      'dynamicAttributes': dynamicAttributes,
      'imageData': imageData,
      if (observations != null) 'observations': observations,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      if (createdAt != null) 'createdAt': createdAt,
      'searchTerms': buildSearchTerms(
        id: id,
        name: name,
        serial: serial,
        brand: brand,
        model: model,
      ),
      if (serial != null && serial!.isNotEmpty) 'serial': serial,
    };
  }
}

