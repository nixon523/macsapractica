class EmployeePosition {
  const EmployeePosition({
    required this.id,
    required this.name,
    this.isMaintenance = true,
    this.isActive = true,
  });

  final int id;
  final String name;
  final bool isMaintenance;
  final bool isActive;

  EmployeePosition copyWith({
    int? id,
    String? name,
    bool? isMaintenance,
    bool? isActive,
  }) {
    return EmployeePosition(
      id: id ?? this.id,
      name: name ?? this.name,
      isMaintenance: isMaintenance ?? this.isMaintenance,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeePosition &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

