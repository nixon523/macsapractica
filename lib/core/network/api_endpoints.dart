/// Centraliza todas las rutas relativas de la API REST de Macsa CMMS en español.
abstract final class ApiEndpoints {
  // Auth & Sesión
  static const String login = '/autenticacion/login';
  static const String me = '/autenticacion/yo';
  static const String changePassword = '/autenticacion/yo/password';
  static const String passwordResetRequests = '/autenticacion/solicitudes-reinicio-password';
  static String resolvePasswordReset(dynamic id) =>
      '/autenticacion/solicitudes-reinicio-password/$id/resolver';
  static const String androidVersion = '/app/version-android';
  static const String downloadApk = '/app/descargar-apk';

  // Usuarios
  static const String users = '/usuarios';
  static String userById(dynamic id) => '/usuarios/$id';
  static String toggleUserDisabled(dynamic id) => '/usuarios/$id/deshabilitado';

  // Áreas
  static const String areas = '/areas';
  static String areaById(String areaId) => '/areas/$areaId';

  // Activos
  static const String assets = '/activos';
  static const String uploadAssetImage = '/activos/upload-imagen';
  static const String assetSearch = '/activos/buscar';
  static String assetBySerial(String serial) =>
      '/activos/serie/${Uri.encodeComponent(serial)}';
  static String assetsByArea(String areaId) =>
      '/activos/area/${Uri.encodeComponent(areaId)}';
  static String assetByCode(String assetCode) =>
      '/activos/${Uri.encodeComponent(assetCode)}';
  static String transferAsset(String assetCode) =>
      '/activos/${Uri.encodeComponent(assetCode)}/traspasar';
  static String reactivateAsset(String assetCode) =>
      '/activos/${Uri.encodeComponent(assetCode)}/reactivar';
  static String toggleAssetStatus(String assetCode) =>
      '/activos/${Uri.encodeComponent(assetCode)}/estado';
  static String cloneAssetTree(String assetCode) =>
      '/activos/${Uri.encodeComponent(assetCode)}/clonar-arbol';

  // Plantillas de Activos (Estructuras Jerárquicas)
  static const String assetTemplates = '/plantillas-activos';
  static String assetTemplateById(dynamic id) => '/plantillas-activos/$id';
  static const String saveAssetTemplate = '/plantillas-activos/desde-activo';
  static String instantiateAssetTemplate(dynamic id) =>
      '/plantillas-activos/$id/instanciar';

  // Solicitudes de Baja
  static const String deletionRequests = '/solicitudes-baja';
  static const String pendingDeletionRequests = '/solicitudes-baja/pendientes';
  static String pendingDeletionByAsset(String assetCode) =>
      '/solicitudes-baja/activo/${Uri.encodeComponent(assetCode)}';
  static String approveDeletionRequest(dynamic id) =>
      '/solicitudes-baja/$id/aprobar';
  static String rejectDeletionRequest(dynamic id) =>
      '/solicitudes-baja/$id/rechazar';

  // Órdenes de Trabajo (OTs)
  static const String workOrders = '/ordenes-trabajo';
  static const String openWorkOrders = '/ordenes-trabajo/abiertas';
  static String updateWorkOrderStatus(dynamic id) =>
      '/ordenes-trabajo/$id/estado';
  static String updateWorkOrderDetails(dynamic id) =>
      '/ordenes-trabajo/$id';

  // Reportes de Averías
  static const String breakdownReports = '/reportes-averia';
  static const String openBreakdownReports = '/reportes-averia/abiertos';
  static const String myBreakdownReports = '/reportes-averia/mis-reportes';
  static String linkBreakdownWorkOrder(dynamic id) =>
      '/reportes-averia/$id/vincular-orden-trabajo';
  static String resolveBreakdownReport(dynamic id) =>
      '/reportes-averia/$id/resolver';
  static String rejectBreakdownReport(dynamic id) =>
      '/reportes-averia/$id/rechazar';

  // Planes Preventivos
  static const String preventiveSchedules = '/planes-preventivos';
  static String amendPreventiveSchedule(dynamic id) =>
      '/planes-preventivos/$id';
  static String recordPreventiveExecution(dynamic id) =>
      '/planes-preventivos/$id/ejecuciones';
  static String togglePreventiveStatus(dynamic id) =>
      '/planes-preventivos/$id/estado';
  static String generateMonthlyWorkOrder(dynamic id) =>
      '/planes-preventivos/$id/generar-ot-mes';

  // Kardex
  static const String kardexLogs = '/kardex';
  static String kardexByEntity(String entityId) =>
      '/kardex/entidad/${Uri.encodeComponent(entityId)}';

  // Dashboard
  static const String dashboardStats = '/dashboard/estadisticas';

  // Reportes de Operación & Analítica Avanzada
  static const String operationReports         = '/reportes-operacion';
  static const String operationReportsWeek     = '/reportes-operacion/semana';
  static const String processEquipment         = '/reportes-operacion/equipos';
  static String operationReportsByAsset(String assetCode) =>
      '/reportes-operacion/activo/${Uri.encodeComponent(assetCode)}';
  static String operationReportMetrics(String assetCode) =>
      '/reportes-operacion/metricas/${Uri.encodeComponent(assetCode)}';
  static String toggleProcessEquipment(String assetCode) =>
      '/reportes-operacion/equipos/${Uri.encodeComponent(assetCode)}/proceso';

  // Empleados & Puestos
  static const String employees = '/empleados';
  static String employeeById(dynamic id) => '/empleados/$id';
  static String toggleEmployeeStatus(dynamic id) => '/empleados/$id/estado';
  static const String employeePositions = '/empleados/puestos';
  static String employeePositionById(dynamic id) => '/empleados/puestos/$id';

  // Catálogos dinámicos (Roles, Permisos, Puestos, Atributos, Unidades, Marcas, Enums)
  static const String catalogs = '/catalogos';
  static const String unitsOfMeasure = '/catalogos/unidades';
  static String unitOfMeasureById(dynamic id) => '/catalogos/unidades/$id';
  static const String attributeCatalog = '/catalogos/atributos';
  static String attributeCatalogById(dynamic id) => '/catalogos/atributos/$id';
  static const String brands = '/catalogos/marcas';
  static String brandById(dynamic id) => '/catalogos/marcas/$id';

  // Analítica & Reportería de Mantenimiento / OEE
  static const String maintenanceByCostCenter =
      '/dashboard/mantenimientos-centro-costo';
  static const String maintenanceByCostCenterDetails =
      '/dashboard/mantenimientos-centro-costo/detalle';
  static String analyticsAssetHistory(String assetCode) =>
      '/reportes-operacion/analitica/historial-activo/${Uri.encodeComponent(assetCode)}';
  static const String analyticsSeasonality =
      '/reportes-operacion/analitica/estacionalidad';
  static const String analyticsTopFailures =
      '/reportes-operacion/analitica/top-fallas';
  static const String analyticsPartsConsumption =
      '/reportes-operacion/analitica/consumo-repuestos';
  static const String analyticsOeeGeneral =
      '/reportes-operacion/analitica/oee-general';
}
