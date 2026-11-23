class Brand {
  const Brand({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.totalAssetsAssociated = 0,
  });

  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int totalAssetsAssociated;

  Brand copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
    int? totalAssetsAssociated,
  }) {
    return Brand(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      totalAssetsAssociated:
          totalAssetsAssociated ?? this.totalAssetsAssociated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Brand &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
