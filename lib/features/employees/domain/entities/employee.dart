/// Entidad de dominio que representa a un empleado del sistema o técnico de mantenimiento.
class Employee {
  const Employee({
    required this.id,
    required this.fullName,
    this.areaId,
    this.areaName,
    this.positionId,
    required this.position,
    this.isMaintenance = true,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String fullName;
  final String? areaId;
  final String? areaName;
  final int? positionId;
  final String position;
  final bool isMaintenance;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Employee copyWith({
    int? id,
    String? fullName,
    String? areaId,
    String? areaName,
    int? positionId,
    String? position,
    bool? isMaintenance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      areaId: areaId ?? this.areaId,
      areaName: areaName ?? this.areaName,
      positionId: positionId ?? this.positionId,
      position: position ?? this.position,
      isMaintenance: isMaintenance ?? this.isMaintenance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

