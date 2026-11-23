class AssetAttributeDefinition {
  const AssetAttributeDefinition({
    required this.id,
    required this.name,
    this.description,
    this.defaultUnitId,
    this.defaultUnitCode,
    this.defaultUnitName,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? description;
  final int? defaultUnitId;
  final String? defaultUnitCode;
  final String? defaultUnitName;
  final bool isActive;

  String get displayName => defaultUnitCode != null && defaultUnitCode!.isNotEmpty
      ? '$name [$defaultUnitCode]'
      : name;

  AssetAttributeDefinition copyWith({
    int? id,
    String? name,
    String? description,
    int? defaultUnitId,
    String? defaultUnitCode,
    String? defaultUnitName,
    bool? isActive,
  }) {
    return AssetAttributeDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      defaultUnitId: defaultUnitId ?? this.defaultUnitId,
      defaultUnitCode: defaultUnitCode ?? this.defaultUnitCode,
      defaultUnitName: defaultUnitName ?? this.defaultUnitName,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetAttributeDefinition &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
