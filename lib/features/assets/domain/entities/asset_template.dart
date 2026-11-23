import 'dart:convert';

class AssetTemplateNode {
  final int id;
  final int templateId;
  final int? parentNodeId;
  final String level;
  final String relativeName;
  final String? brand;
  final String? model;
  final int order;
  final Map<String, dynamic> dynamicAttributes;

  const AssetTemplateNode({
    required this.id,
    required this.templateId,
    this.parentNodeId,
    required this.level,
    required this.relativeName,
    this.brand,
    this.model,
    required this.order,
    this.dynamicAttributes = const {},
  });

  factory AssetTemplateNode.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> attrs = {};
    final rawAttrs = json['dynamicAttributes'] ??
        json['DynamicAttributes'] ??
        json['AtributosDinamicos'] ??
        json['atributosDinamicos'];
    if (rawAttrs is Map) {
      attrs = Map<String, dynamic>.from(rawAttrs);
    } else if (rawAttrs is String && rawAttrs.isNotEmpty) {
      try {
        attrs = Map<String, dynamic>.from(jsonDecode(rawAttrs) as Map);
      } catch (_) {}
    }

    return AssetTemplateNode(
      id: int.tryParse((json['id'] ?? json['NodoId'] ?? json['nodoId'] ?? 0).toString()) ?? 0,
      templateId: int.tryParse((json['templateId'] ?? json['PlantillaId'] ?? json['plantillaId'] ?? 0).toString()) ?? 0,
      parentNodeId: json['parentNodeId'] != null || json['NodoPadreId'] != null || json['nodoPadreId'] != null
          ? int.tryParse((json['parentNodeId'] ?? json['NodoPadreId'] ?? json['nodoPadreId']).toString())
          : null,
      level: (json['level'] ?? json['Nivel'] ?? json['nivel'] ?? 'equipment').toString(),
      relativeName: (json['relativeName'] ?? json['NombreRelativo'] ?? json['nombreRelativo'] ?? '').toString(),
      brand: (json['brand'] ?? json['Marca'] ?? json['marca'])?.toString(),
      model: (json['model'] ?? json['Modelo'] ?? json['modelo'])?.toString(),
      order: int.tryParse((json['order'] ?? json['Orden'] ?? json['orden'] ?? 0).toString()) ?? 0,
      dynamicAttributes: attrs,
    );
  }
}

class AssetTemplate {
  final int id;
  final String name;
  final String? description;
  final String sourceAssetCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int totalNodes;
  final List<AssetTemplateNode> nodes;

  const AssetTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.sourceAssetCode,
    this.createdAt,
    this.updatedAt,
    this.totalNodes = 0,
    this.nodes = const [],
  });

  factory AssetTemplate.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    final rawNodes = json['nodes'] ?? json['Nodes'] ?? json['nodos'] ?? json['Nodos'];
    final nodesList = (rawNodes is List)
        ? rawNodes
            .whereType<Map>()
            .map((e) => AssetTemplateNode.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AssetTemplateNode>[];

    return AssetTemplate(
      id: int.tryParse((json['id'] ?? json['PlantillaId'] ?? json['plantillaId'] ?? 0).toString()) ?? 0,
      name: (json['name'] ?? json['Nombre'] ?? json['nombre'] ?? '').toString(),
      description: (json['description'] ?? json['Descripcion'] ?? json['descripcion'])?.toString(),
      sourceAssetCode: (json['sourceAssetCode'] ?? json['CodigoActivoOrigen'] ?? json['codigoActivoOrigen'] ?? '').toString(),
      createdAt: parseDate(json['createdAt'] ?? json['CreadoEn'] ?? json['creadoEn']),
      updatedAt: parseDate(json['updatedAt'] ?? json['ActualizadoEn'] ?? json['actualizadoEn']),
      totalNodes: int.tryParse((json['totalNodes'] ?? json['TotalNodos'] ?? json['totalNodos'] ?? nodesList.length).toString()) ??
          nodesList.length,
      nodes: nodesList,
    );
  }
}
