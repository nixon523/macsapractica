import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/employee_position.dart';

class EmployeePositionModel extends EmployeePosition {
  const EmployeePositionModel({
    required super.id,
    required super.name,
    super.isMaintenance,
    super.isActive,
  });

  factory EmployeePositionModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val, {bool defaultVal = true}) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return defaultVal;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return EmployeePositionModel(
      id: parseInt(json['PuestoId'] ?? json['puestoId'] ?? json['id']),
      name: TextSanitizer.fixEncoding(
          (json['Nombre'] ?? json['nombre'] ?? json['name'] ?? '').toString().trim()),
      isMaintenance: parseBool(
        json['EsMantenimiento'] ?? json['esMantenimiento'] ?? json['isMaintenance'],
        defaultVal: true,
      ),
      isActive: parseBool(
        json['Activo'] ?? json['activo'] ?? json['isActive'],
        defaultVal: true,
      ),
    );
  }
}

