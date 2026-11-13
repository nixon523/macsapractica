/// Identificadores de permisos usados por el RBAC de la aplicación.
///
/// Convención: `modulo.accion`. El rol `admin` (Administrador del Sistema) tiene
/// acceso total por el propio rol; los demás roles reciben los permisos por
/// defecto de su rol y pueden ampliarse por usuario.
class AppPermissions {
  AppPermissions._();

  static const dashboardView = 'dashboard.view';
  static const assetView = 'asset.view';
  static const assetCreate = 'asset.create';
  static const assetEdit = 'asset.edit';
  static const assetTransfer = 'asset.transfer';
  static const assetDeleteRequest = 'asset.delete.request';
  static const assetDeleteApprove = 'asset.delete.approve';
  static const workOrderView = 'work_order.view';
  static const workOrderCreate = 'work_order.create';
  static const workOrderPrint = 'work_order.print';
  static const preventiveView = 'preventive.view';
  static const preventiveManage = 'preventive.manage';
  static const kardexView = 'kardex.view';
  static const breakdownReport = 'breakdown.report';
  static const breakdownView = 'breakdown.view';
  static const breakdownManage = 'breakdown.manage';
  static const operationReportView = 'operation_report.view';
  static const operationReportEdit = 'operation_report.edit';
  static const employeeManage = 'employee.manage';
  static const userManage = 'user.manage';
}

enum UserRole {
  admin('admin', 'Administrador'),
  jefe('jefe', 'Jefe de Mantenimiento'),
  jefeArea('jefe_area', 'Jefe de Área'),
  reportador('reportador', 'Supervisor (Reportador)'),
  lector('lector', 'Gerente (Solo Lectura / KPIs)');

  const UserRole(this.code, this.label);

  /// Código persistido en base de datos (`dbo.Usuario.CodigoRol`).
  final String code;

  /// Etiqueta legible para la interfaz.
  final String label;

  static UserRole fromCode(String? code) {
    return UserRole.values.firstWhere(
      (e) => e.code == code,
      orElse: () => UserRole.lector,
    );
  }

  /// Descripción resumida del alcance de cada rol para la UI de administración.
  String get description => switch (this) {
        UserRole.admin =>
          'Acceso total absoluto del sistema. Único rol autorizado para gestionar usuarios y aprobar bajas definitivas.',
        UserRole.jefe =>
          'Gestión integral de mantenimiento: activos, órdenes de trabajo, preventivos, averías, reportes de operación y personal técnico.',
        UserRole.jefeArea =>
          'Acceso operativo limitado: consulta dashboard, equipos, OTs y preventivos; reporta/ve averías y registra reportes de operación.',
        UserRole.reportador =>
          'Enfocado en piso de planta: reportar averías con fotografía y dar seguimiento al estado de los reportes.',
        UserRole.lector =>
          'Visibilidad total en modo consulta: dashboards, KPIs, analítica OEE, Kardex y generación de reportes PDF/Excel sin modificar datos.',
      };

  /// Sugiere el rol más apropiado a partir del puesto del empleado en el catálogo.
  static UserRole suggestFromPosition(
    String position, {
    bool isMaintenance = false,
  }) {
    final p = position
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    if (p.contains('gerente') || p.contains('director') || p.contains('auditor')) {
      return UserRole.lector;
    }
    if (p.contains('jefe') && (p.contains('mantenimiento') || p.contains('mtto'))) {
      return UserRole.jefe;
    }
    if (p.contains('jefe') || p.contains('coordinador') || p.contains('encargado')) {
      return UserRole.jefeArea;
    }
    if (p.contains('supervisor') || p.contains('operador') || p.contains('tecnico') || isMaintenance) {
      return UserRole.reportador;
    }
    return UserRole.reportador;
  }

  /// Permisos por defecto del rol.
  Set<String> get defaultPermissions => switch (this) {
        UserRole.admin => {
            AppPermissions.dashboardView,
            AppPermissions.assetView,
            AppPermissions.assetCreate,
            AppPermissions.assetEdit,
            AppPermissions.assetTransfer,
            AppPermissions.assetDeleteRequest,
            AppPermissions.assetDeleteApprove,
            AppPermissions.workOrderView,
            AppPermissions.workOrderCreate,
            AppPermissions.workOrderPrint,
            AppPermissions.preventiveView,
            AppPermissions.preventiveManage,
            AppPermissions.kardexView,
            AppPermissions.breakdownReport,
            AppPermissions.breakdownView,
            AppPermissions.breakdownManage,
            AppPermissions.operationReportView,
            AppPermissions.operationReportEdit,
            AppPermissions.employeeManage,
            AppPermissions.userManage,
          },
        UserRole.jefe => {
            AppPermissions.dashboardView,
            AppPermissions.assetView,
            AppPermissions.assetCreate,
            AppPermissions.assetEdit,
            AppPermissions.assetTransfer,
            AppPermissions.assetDeleteRequest,
            AppPermissions.workOrderView,
            AppPermissions.workOrderCreate,
            AppPermissions.workOrderPrint,
            AppPermissions.preventiveView,
            AppPermissions.preventiveManage,
            AppPermissions.kardexView,
            AppPermissions.breakdownReport,
            AppPermissions.breakdownView,
            AppPermissions.breakdownManage,
            AppPermissions.operationReportView,
            AppPermissions.operationReportEdit,
            AppPermissions.employeeManage,
          },
        UserRole.jefeArea => {
            AppPermissions.dashboardView,
            AppPermissions.assetView,
            AppPermissions.workOrderView,
            AppPermissions.workOrderPrint,
            AppPermissions.preventiveView,
            AppPermissions.breakdownReport,
            AppPermissions.breakdownView,
            AppPermissions.operationReportView,
            AppPermissions.operationReportEdit,
          },
        UserRole.reportador => {
            AppPermissions.breakdownReport,
            AppPermissions.breakdownView,
          },
        UserRole.lector => {
            AppPermissions.dashboardView,
            AppPermissions.assetView,
            AppPermissions.workOrderView,
            AppPermissions.workOrderPrint,
            AppPermissions.preventiveView,
            AppPermissions.kardexView,
            AppPermissions.breakdownView,
            AppPermissions.operationReportView,
          },
      };
}
