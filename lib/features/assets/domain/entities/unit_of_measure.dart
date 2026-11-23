class UnitOfMeasure {
  const UnitOfMeasure({
    required this.id,
    required this.code,
    required this.name,
    this.isActive = true,
  });

  final int id;
  final String code;
  final String name;
  final bool isActive;

  String get displayName => '$code ($name)';

  UnitOfMeasure copyWith({
    int? id,
    String? code,
    String? name,
    bool? isActive,
  }) {
    return UnitOfMeasure(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitOfMeasure &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}
