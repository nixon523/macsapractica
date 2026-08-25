class Area {
  final String id;
  final String name;
  final String costCenter;
  final int assetCounter;

  const Area({
    required this.id,
    required this.name,
    required this.costCenter,
    this.assetCounter = 0,
  });

  Area copyWith({
    String? name,
    String? costCenter,
    int? assetCounter,
  }) {
    return Area(
      id: id,
      name: name ?? this.name,
      costCenter: costCenter ?? this.costCenter,
      assetCounter: assetCounter ?? this.assetCounter,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Area &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          costCenter == other.costCenter &&
          assetCounter == other.assetCounter;

  @override
  int get hashCode => Object.hash(id, name, costCenter, assetCounter);
}
