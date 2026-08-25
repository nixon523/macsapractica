/// Identificadores de permisos usados por el RBAC de la aplicación.
///
/// Convención: `modulo.accion`. El rol `admin` (Gestor del Sistema) tiene
/// acceso total por el propio rol; los demás roles reciben los permisos por
/// defecto de su rol y pueden ampliarse/limitarse por usuario.
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
  static const kardexView = 'kardex.view';
  static const breakdownReport = 'breakdown.report';
  static const breakdownView = 'breakdown.view';
  static const breakdownManage = 'breakdown.manage';
  static const userManage = 'user.manage';
}

enum UserRole {
  admin('admin', 'Administrador'),
  jefe('jefe', 'Jefe'),
  reportador('reportador', 'Reportador de Averías'),
  lector('lector', 'Solo Lectura');

  const UserRole(this.code, this.label);

  /// Código persistido en Firestore (`/users/{id}.role`).
  final String code;

  /// Etiqueta legible para la interfaz.
  final String label;

  static UserRole fromCode(String? code) {
    return UserRole.values.firstWhere(
      (e) => e.code == code,
      orElse: () => UserRole.lector,
    );
  }

  /// Permisos por defecto del rol. El `admin` accede a todo por el propio rol
  /// (ver `AppUser.hasPermission`), así que su lista solo se usa para
  /// mostrarla en la interfaz de administración.
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
            AppPermissions.kardexView,
            AppPermissions.breakdownReport,
            AppPermissions.breakdownView,
            AppPermissions.breakdownManage,
            AppPermissions.userManage,
          },
        UserRole.jefe => {
            AppPermissions.dashboardView,
            AppPermissions.assetView,
            AppPermissions.workOrderView,
            AppPermissions.workOrderCreate,
            AppPermissions.workOrderPrint,
            AppPermissions.preventiveView,
            AppPermissions.kardexView,
            AppPermissions.breakdownView,
            AppPermissions.breakdownManage,
          },
        UserRole.reportador => {
            AppPermissions.breakdownReport,
            AppPermissions.breakdownView,
          },
        UserRole.lector => {
            AppPermissions.dashboardView,
            AppPermissions.assetView,
            AppPermissions.workOrderView,
            AppPermissions.preventiveView,
            AppPermissions.kardexView,
            AppPermissions.breakdownView,
          },
      };
}
