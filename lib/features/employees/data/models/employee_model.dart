import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/employee.dart';

class EmployeeModel extends Employee {
  const EmployeeModel({
    required super.id,
    required super.fullName,
    super.areaId,
    super.areaName,
    super.positionId,
    required super.position,
    super.isMaintenance = true,
    super.isActive = true,
    super.createdAt,
    super.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    final rawId = json['EmpleadoId'] ?? json['empleadoId'] ?? json['id'] ?? 0;
    final int id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final rawIsMaint = json['EsMantenimiento'] ?? json['esMantenimiento'] ?? json['isMaintenance'];
    final bool isMaintenance = rawIsMaint is bool
        ? rawIsMaint
        : (rawIsMaint == 1 || rawIsMaint == '1');

    final rawActive = json['Activo'] ?? json['activo'] ?? json['isActive'];
    final bool isActive = rawActive is bool
        ? rawActive
        : (rawActive == 1 || rawActive == '1' || rawActive == null);

    final rawAreaName = json['NombreArea'] ?? json['nombreArea'] ?? json['areaName'];
    final rawPositionId = json['PuestoId'] ?? json['puestoId'] ?? json['positionId'];
    final int? positionId = rawPositionId is int
        ? rawPositionId
        : (rawPositionId != null ? int.tryParse(rawPositionId.toString()) : null);

    return EmployeeModel(
      id: id,
      fullName: TextSanitizer.fixEncoding(
          (json['NombreCompleto'] ?? json['nombreCompleto'] ?? json['fullName'] ?? '').toString()),
      areaId: (json['AreaId'] ?? json['areaId'])?.toString(),
      areaName: rawAreaName != null ? TextSanitizer.fixEncoding(rawAreaName.toString()) : null,
      positionId: positionId,
      position: TextSanitizer.fixEncoding(
          (json['Puesto'] ?? json['puesto'] ?? json['position'] ?? '').toString()),
      isMaintenance: isMaintenance,
      isActive: isActive,
      createdAt: parseDate(json['CreadoEn'] ?? json['creadoEn'] ?? json['createdAt']),
      updatedAt: parseDate(json['ActualizadoEn'] ?? json['actualizadoEn'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'areaId': areaId,
      'areaName': areaName,
      if (positionId != null) 'positionId': positionId,
      'position': position,
      'isMaintenance': isMaintenance,
      'isActive': isActive,
    };
  }
}

