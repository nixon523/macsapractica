/// Centraliza todas las rutas relativas de la API REST de Macsa CMMS en español.
abstract final class ApiEndpoints {
  // Auth & Sesión
  static const String login = '/autenticacion/login';
  static const String me = '/autenticacion/yo';
  static const String changePassword = '/autenticacion/yo/password';
  static const String passwordResetRequests = '/autenticacion/solicitudes-reinicio-password';
  static String resolvePasswordReset(dynamic id) =>
      '/autenticacion/solicitudes-reinicio-password/$id/resolver';

  // Usuarios
  static const String users = '/usuarios';
  static String userById(dynamic id) => '/usuarios/$id';
  static String toggleUserDisabled(dynamic id) => '/usuarios/$id/deshabilitado';

  // Áreas
  static const String areas = '/areas';
  static String areaById(String areaId) => '/areas/$areaId';

  // Activos
  static const String assets = '/activos';
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
}
