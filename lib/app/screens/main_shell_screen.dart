import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth_permissions/domain/entities/app_user.dart';
import '../../features/auth_permissions/domain/entities/user_role.dart';
import '../../features/auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/assets/presentation/views/area_selection_view.dart';
import '../../features/work_orders/presentation/views/work_order_list_view.dart';
import '../../features/preventive_schedules/presentation/views/preventive_schedule_list_view.dart';
import '../../features/kardex/presentation/views/kardex_list_view.dart';
import '../../features/auth_permissions/presentation/views/user_list_view.dart';
import '../../features/asset_deletion/presentation/views/deletion_requests_view.dart';
import '../../features/breakdown_reports/presentation/views/report_breakdown_view.dart';
import '../../features/breakdown_reports/presentation/views/my_reports_view.dart';
import '../../features/breakdown_reports/presentation/views/breakdown_reports_view.dart';
import '../../features/breakdown_reports/presentation/viewmodels/breakdown_alerts_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/my_reports_notifications_viewmodel.dart';
import '../../features/auth_permissions/presentation/viewmodels/password_reset_alerts_viewmodel.dart';
import '../../features/preventive_schedules/presentation/viewmodels/preventive_schedule_viewmodel.dart';
import '../../features/work_orders/presentation/viewmodels/work_order_alerts_viewmodel.dart';
import '../../features/operation_reports/presentation/views/operation_report_list_view.dart';
import '../../features/operation_reports/presentation/viewmodels/operation_report_viewmodel.dart';
import '../../features/app_update/presentation/viewmodels/app_update_viewmodel.dart';
import '../../features/app_update/presentation/views/widgets/app_update_dialog.dart';
import '../../core/audio/notification_sound.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../core/notifications/notification_queue.dart';
import '../di/get_it.dart';
import '../router/app_router.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_theme.dart';
import 'sidebar_widget.dart';

enum _ShellSection {
  dashboard,
  assets,
  workOrders,
  preventive,
  operationReports,
  kardex,
  reportBreakdown,
  myReports,
  breakdownReports,
  deletionRequests,
  users,
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;
  final Set<String> _collapsedGroupIds = {};
  bool _groupsInitialized = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    // Inicializar servicio de notificaciones locales de Android / sistema
    final localNotifications = getIt<LocalNotificationService>();
    localNotifications.initialize(
      onSelectNotification: (response) {
        _handleNotificationPayload(response.payload);
      },
    );
    localNotifications.requestPermissions();

    if (user.isAdmin || user.role == UserRole.jefe || user.hasPermission(AppPermissions.breakdownManage)) {
      getIt<BreakdownAlertsViewModel>().start();
    }
    if (user.isAdmin || user.hasPermission(AppPermissions.userManage)) {
      getIt<PasswordResetAlertsViewModel>().start();
    }
    if (user.role == UserRole.reportador || user.hasPermission(AppPermissions.breakdownReport)) {
      getIt<MyReportsNotificationsViewModel>().start(user.userId);
    }
    // Alerta de OTs pendientes/vencidas para roles que gestionan OTs
    if (user.isAdmin || user.role == UserRole.jefe ||
        user.hasPermission(AppPermissions.workOrderView) ||
        user.hasPermission(AppPermissions.workOrderCreate)) {
      getIt<WorkOrderAlertsViewModel>().start();
    }

    // Monitoreo continuo de actualizaciones en Android para todos los roles
    getIt<AppUpdateViewModel>().start();
  }

  @override
  void dispose() {
    getIt<AppUpdateViewModel>().stop();
    getIt<BreakdownAlertsViewModel>().stop();
    getIt<PasswordResetAlertsViewModel>().stop();
    getIt<MyReportsNotificationsViewModel>().stop();
    getIt<WorkOrderAlertsViewModel>().stop();
    getIt<NotificationQueue>().clear();
    super.dispose();
  }

  static const Map<_ShellSection, SidebarItem> _sectionToItem = {
    _ShellSection.dashboard: SidebarItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    _ShellSection.assets: SidebarItem(
      icon: Icons.precision_manufacturing_outlined,
      activeIcon: Icons.precision_manufacturing,
      label: 'Activos',
    ),
    _ShellSection.workOrders: SidebarItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      label: 'Órdenes de Trabajo',
    ),
    _ShellSection.preventive: SidebarItem(
      icon: Icons.event_repeat_outlined,
      activeIcon: Icons.event_repeat,
      label: 'Mantenimiento Preventivo',
    ),
    _ShellSection.operationReports: SidebarItem(
      icon: Icons.speed_outlined,
      activeIcon: Icons.speed,
      label: 'Disponibilidad Operativa',
    ),
    _ShellSection.kardex: SidebarItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Kardex / Historial',
    ),
    _ShellSection.reportBreakdown: SidebarItem(
      icon: Icons.report_problem_outlined,
      activeIcon: Icons.report_problem,
      label: 'Reportar Avería',
    ),
    _ShellSection.myReports: SidebarItem(
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check,
      label: 'Mis Reportes',
    ),
    _ShellSection.breakdownReports: SidebarItem(
      icon: Icons.bug_report_outlined,
      activeIcon: Icons.bug_report,
      label: 'Reportes de Averías',
    ),
    _ShellSection.deletionRequests: SidebarItem(
      icon: Icons.pending_actions_outlined,
      activeIcon: Icons.pending_actions,
      label: 'Solicitudes',
    ),
    _ShellSection.users: SidebarItem(
      icon: Icons.people_outlined,
      activeIcon: Icons.people,
      label: 'Usuarios',
    ),
  };

  static List<_ShellSection> _sectionsFor(AppUser user) {
    if (user.isAdmin) {
      return const [
        _ShellSection.dashboard,
        _ShellSection.operationReports,
        _ShellSection.kardex,
        _ShellSection.assets,
        _ShellSection.workOrders,
        _ShellSection.preventive,
        _ShellSection.reportBreakdown,
        _ShellSection.myReports,
        _ShellSection.breakdownReports,
        _ShellSection.deletionRequests,
        _ShellSection.users,
      ];
    }

    final sections = <_ShellSection>[];

    // Operaciones y Control
    if (user.hasPermission(AppPermissions.dashboardView)) {
      sections.add(_ShellSection.dashboard);
    }
    if (user.hasPermission('operation_report.view') ||
        user.hasPermission(AppPermissions.dashboardView) ||
        user.role == UserRole.jefe) {
      sections.add(_ShellSection.operationReports);
    }
    if (user.hasPermission(AppPermissions.kardexView)) {
      sections.add(_ShellSection.kardex);
    }

    // Gestión de Mantenimiento
    if (user.hasPermission(AppPermissions.assetView) ||
        user.hasPermission(AppPermissions.assetCreate) ||
        user.hasPermission(AppPermissions.assetEdit) ||
        user.hasPermission(AppPermissions.assetTransfer)) {
      sections.add(_ShellSection.assets);
    }
    if (user.hasPermission(AppPermissions.workOrderView) ||
        user.hasPermission(AppPermissions.workOrderCreate) ||
        user.hasPermission(AppPermissions.workOrderPrint)) {
      sections.add(_ShellSection.workOrders);
    }
    if (user.hasPermission(AppPermissions.preventiveView)) {
      sections.add(_ShellSection.preventive);
    }

    // Incidencias y Averías
    if (user.hasPermission(AppPermissions.breakdownReport)) {
      sections.add(_ShellSection.reportBreakdown);
    }
    if (user.hasPermission(AppPermissions.breakdownReport) ||
        user.hasPermission(AppPermissions.breakdownView) ||
        user.role == UserRole.reportador) {
      sections.add(_ShellSection.myReports);
    }
    if (user.hasPermission(AppPermissions.breakdownView) ||
        user.hasPermission(AppPermissions.breakdownManage)) {
      sections.add(_ShellSection.breakdownReports);
    }

    // Administración del Sistema
    if (user.hasPermission(AppPermissions.assetDeleteApprove) ||
        user.hasPermission(AppPermissions.assetDeleteRequest)) {
      sections.add(_ShellSection.deletionRequests);
    }
    if (user.hasPermission(AppPermissions.userManage)) {
      sections.add(_ShellSection.users);
    }

    // Salvaguarda: si no tiene ninguna sección visible, agregar al menos 'Mis Reportes'
    if (sections.isEmpty) {
      sections.add(_ShellSection.myReports);
    }

    return sections;
  }

  String _getTitle(int index, AppUser user, List<_ShellSection> sections) {
    if (index >= sections.length) return 'Grupo Macsa';
    final section = sections[index];
    if (section == _ShellSection.dashboard) {
      return 'Hola, ${user.displayName ?? user.username}';
    }
    return _sectionToItem[section]?.label ?? 'Grupo Macsa';
  }

  Widget _buildContent(_ShellSection section, List<_ShellSection> sections) {
    return switch (section) {
      _ShellSection.dashboard => DashboardView(
          onNavigateToSection: (sectionKey) {
            final target = switch (sectionKey) {
              'assets' => _ShellSection.assets,
              'workOrders' => _ShellSection.workOrders,
              'preventive' => _ShellSection.preventive,
              'breakdownReports' => _ShellSection.breakdownReports,
              'kardex' => _ShellSection.kardex,
              'operationReports' => _ShellSection.operationReports,
              _ => null,
            };
            if (target != null) {
              final idx = sections.indexOf(target);
              if (idx >= 0) setState(() => _selectedIndex = idx);
            }
          },
        ),
      _ShellSection.assets => const AreaSelectionView(),
      _ShellSection.workOrders => const WorkOrderListView(),
      _ShellSection.preventive => const PreventiveScheduleListView(),
      _ShellSection.operationReports => ChangeNotifierProvider.value(
          value: getIt<OperationReportViewModel>(),
          child: const OperationReportListView(),
        ),
      _ShellSection.kardex => const KardexListView(),
      _ShellSection.reportBreakdown => const ReportBreakdownView(),
      _ShellSection.myReports => const MyReportsView(),
      _ShellSection.breakdownReports => const BreakdownReportsView(),
      _ShellSection.deletionRequests => const DeletionRequestsView(),
      _ShellSection.users => const UserListView(),
    };
  }

  /// Maneja los taps en notificaciones nativas de Android / sistema.
  void _handleNotificationPayload(String? payload) {
    if (payload == null || !mounted) return;
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;
    final sections = _sectionsFor(user);

    _ShellSection? targetSection;
    if (payload.startsWith('breakdown:')) {
      targetSection = _ShellSection.breakdownReports;
    } else if (payload.startsWith('work_order:')) {
      targetSection = _ShellSection.workOrders;
    } else if (payload.startsWith('my_report:')) {
      targetSection = _ShellSection.myReports;
    } else if (payload.startsWith('password_reset:')) {
      targetSection = _ShellSection.users;
    }

    if (targetSection != null) {
      final index = sections.indexOf(targetSection);
      if (index >= 0) {
        setState(() => _selectedIndex = index);
        if (targetSection == _ShellSection.myReports) {
          getIt<MyReportsNotificationsViewModel>().markSectionSeen();
        }
      }
    }
  }

  /// Muestra el aviso cuando llega una avería nueva (una vez por reporte).
  void _showNewReportAlert(BreakdownAlertsViewModel alertsVm, AppUser user) {
    if (alertsVm.latestNewReport == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final report = alertsVm.consumeLatestReport();
      if (report == null) return;

      // 1. Notificación local en la barra del sistema Android
      getIt<LocalNotificationService>().showBreakdownNotification(
        reportId: report.id,
        assetId: report.assetId,
        assetName: report.assetName,
        reportedBy: report.reportedByUserName,
        areaId: report.areaId,
      );

      // 2. Alerta flotante in-app (SnackBar en cola)
      final queue = getIt<NotificationQueue>();
      queue.enqueue(
        context,
        NotificationItem(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.amberAccent,
          message: 'Nueva avería reportada por ${report.reportedByUserName}: '
              '${report.assetId} — ${report.assetName} '
              '(Área ${report.areaId}).',
          actionLabel: 'Ver',
          onAction: () {
            final sections = _sectionsFor(user);
            final index = sections.indexOf(_ShellSection.breakdownReports);
            if (index >= 0) setState(() => _selectedIndex = index);
          },
          soundCallback: () => getIt<NotificationSound>().play(),
        ),
      );
    });
  }

  /// Muestra el aviso al reportador cuando su reporte fue atendido o rechazado.
  void _showReportOutcomeAlert(
    MyReportsNotificationsViewModel reportsVm,
    AppUser user,
  ) {
    if (reportsVm.latestOutcome == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final outcome = reportsVm.consumeLatestOutcome();
      if (outcome == null) return;

      final report = outcome.report;
      final isAccepted = outcome.kind == ReportOutcomeKind.workOrderGenerated;

      // 1. Notificación local en la barra del sistema Android
      getIt<LocalNotificationService>().showReportOutcomeNotification(
        reportId: report.id,
        assetId: report.assetId,
        isAccepted: isAccepted,
        workOrderId: report.workOrderId,
        rejectionReason: report.rejectionReason,
      );

      final message = switch (outcome.kind) {
        ReportOutcomeKind.workOrderGenerated =>
          'Tu reporte de ${report.assetId} fue atendido: se generó la OT '
          '${report.workOrderId ?? ''}.',
        ReportOutcomeKind.rejected =>
          'Tu reporte de ${report.assetId} fue rechazado. '
          'Motivo: ${report.rejectionReason ?? '—'}',
      };

      // 2. Alerta flotante in-app (SnackBar en cola)
      final queue = getIt<NotificationQueue>();
      queue.enqueue(
        context,
        NotificationItem(
          icon: isAccepted ? Icons.check_circle_outline : Icons.cancel_outlined,
          iconColor: isAccepted ? Colors.greenAccent : Colors.redAccent,
          message: message,
          actionLabel: 'Ver',
          onAction: () {
            final sections = _sectionsFor(user);
            final index = sections.indexOf(_ShellSection.myReports);
            if (index >= 0) {
              setState(() {
                _selectedIndex = index;
                getIt<MyReportsNotificationsViewModel>().markSectionSeen();
              });
            }
          },
        ),
      );
    });
  }

  /// Muestra el aviso al administrador cuando un usuario solicita restablecer su clave.
  void _showPasswordResetAlert(
    PasswordResetAlertsViewModel resetVm,
    AppUser user,
  ) {
    if (resetVm.latestRequest == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final requestUser = resetVm.consumeLatestRequest();
      if (requestUser == null) return;

      // 1. Notificación local en la barra del sistema Android
      getIt<LocalNotificationService>().showPasswordResetNotification(
        username: requestUser.username,
        displayName: requestUser.displayName,
      );

      // 2. Alerta flotante in-app (SnackBar en cola)
      final queue = getIt<NotificationQueue>();
      queue.enqueue(
        context,
        NotificationItem(
          icon: Icons.key,
          iconColor: Colors.amberAccent,
          message: 'Solicitud de clave: '
              '${requestUser.displayName ?? requestUser.username} '
              '(@${requestUser.username}) solicitó una clave temporal.',
          actionLabel: 'Atender',
          onAction: () {
            final sections = _sectionsFor(user);
            final index = sections.indexOf(_ShellSection.users);
            if (index >= 0) setState(() => _selectedIndex = index);
          },
          soundCallback: () => getIt<NotificationSound>().play(),
        ),
      );
    });
  }

  /// Muestra el aviso cuando se detecta una OT nueva de alta prioridad.
  void _showWorkOrderAlert(
    WorkOrderAlertsViewModel woAlertsVm,
    AppUser user,
  ) {
    if (woAlertsVm.latestAlert == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final order = woAlertsVm.consumeLatestAlert();
      if (order == null) return;

      // 1. Notificación local en la barra del sistema Android
      getIt<LocalNotificationService>().showWorkOrderNotification(
        orderId: order.id,
        correlative: order.displayCorrelative,
        assetName: order.assetName,
        description: order.description,
      );

      // 2. Alerta flotante in-app (SnackBar en cola)
      final queue = getIt<NotificationQueue>();
      queue.enqueue(
        context,
        NotificationItem(
          icon: Icons.priority_high,
          iconColor: const Color(0xFFE11D48),
          message: 'OT de alta prioridad: '
              '${order.displayCorrelative} — ${order.assetName} '
              '(${order.description}).',
          actionLabel: 'Ver',
          onAction: () {
            final sections = _sectionsFor(user);
            final index = sections.indexOf(_ShellSection.workOrders);
            if (index >= 0) setState(() => _selectedIndex = index);
          },
          soundCallback: () => getIt<NotificationSound>().play(),
        ),
      );
    });
  }

  bool _isUpdateDialogShowing = false;

  /// Muestra el diálogo de actualización cuando se detecta una nueva versión en Android.
  void _checkAppUpdateAlert(AppUpdateViewModel updateVm) {
    if (!updateVm.shouldShowDialog || _isUpdateDialogShowing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !updateVm.shouldShowDialog || _isUpdateDialogShowing) return;

      _isUpdateDialogShowing = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !updateVm.isMandatory,
        builder: (_) => AppUpdateDialog(
          versionInfo: updateVm.versionInfo!,
          currentVersion: updateVm.currentVersion,
          viewModel: updateVm,
        ),
      );
      _isUpdateDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final updateVm = context.watch<AppUpdateViewModel>();
    _checkAppUpdateAlert(updateVm);

    final alertsVm = context.watch<BreakdownAlertsViewModel>();
    _showNewReportAlert(alertsVm, user);

    final reportsVm = context.watch<MyReportsNotificationsViewModel>();
    _showReportOutcomeAlert(reportsVm, user);

    final resetAlertsVm = context.watch<PasswordResetAlertsViewModel>();
    if (user.isAdmin) {
      _showPasswordResetAlert(resetAlertsVm, user);
    }

    final preventiveVm = context.watch<PreventiveScheduleViewModel>();

    final woAlertsVm = context.watch<WorkOrderAlertsViewModel>();
    if (user.isAdmin ||
        user.role == UserRole.jefe ||
        user.hasPermission(AppPermissions.workOrderView) ||
        user.hasPermission(AppPermissions.workOrderCreate)) {
      _showWorkOrderAlert(woAlertsVm, user);
    }

    final sections = _sectionsFor(user);
    final safeIndex =
        _selectedIndex >= sections.length ? 0 : _selectedIndex;
    final items = [
      for (final section in sections)
        SidebarItem(
          icon: _sectionToItem[section]!.icon,
          activeIcon: _sectionToItem[section]!.activeIcon,
          label: _sectionToItem[section]!.label,
          badgeCount: section == _ShellSection.breakdownReports
              ? alertsVm.pendingCount
              : section == _ShellSection.myReports
                  ? reportsVm.pendingUnreadCount
                  : section == _ShellSection.users
                      ? resetAlertsVm.pendingCount
                      : section == _ShellSection.preventive
                          ? preventiveVm.urgentAndOverdueCount
                          : section == _ShellSection.workOrders
                              ? woAlertsVm.badgeCount
                              : 0,
        ),
    ];

    final groupDefinitions = [
      (
        id: 'operaciones',
        title: 'OPERACIONES Y CONTROL',
        icon: Icons.analytics_outlined,
        sections: const [
          _ShellSection.dashboard,
          _ShellSection.operationReports,
          _ShellSection.kardex,
        ],
      ),
      (
        id: 'mantenimiento',
        title: 'GESTIÓN DE MANTENIMIENTO',
        icon: Icons.build_circle_outlined,
        sections: const [
          _ShellSection.assets,
          _ShellSection.workOrders,
          _ShellSection.preventive,
        ],
      ),
      (
        id: 'incidencias',
        title: 'INCIDENCIAS Y AVERÍAS',
        icon: Icons.warning_amber_rounded,
        sections: const [
          _ShellSection.reportBreakdown,
          _ShellSection.myReports,
          _ShellSection.breakdownReports,
        ],
      ),
      (
        id: 'administracion',
        title: 'ADMINISTRACIÓN DEL SISTEMA',
        icon: Icons.admin_panel_settings_outlined,
        sections: const [
          _ShellSection.deletionRequests,
          _ShellSection.users,
        ],
      ),
    ];

    final groups = <SidebarGroup>[];
    for (final def in groupDefinitions) {
      final entries = <SidebarItemEntry>[];
      for (final section in def.sections) {
        final index = sections.indexOf(section);
        if (index >= 0) {
          entries.add(SidebarItemEntry(item: items[index], index: index));
        }
      }
      if (entries.isNotEmpty) {
        groups.add(
          SidebarGroup(
            id: def.id,
            title: def.title,
            icon: def.icon,
            items: entries,
          ),
        );
      }
    }

    if (!_groupsInitialized && groups.isNotEmpty) {
      for (final g in groups) {
        _collapsedGroupIds.add(g.id);
      }
      _groupsInitialized = true;
    }

    final isMobile = AppBreakpoints.isMobile(context);

    void onSectionTap(int index) {
      setState(() {
        _selectedIndex = index;
        if (sections[index] == _ShellSection.myReports) {
          getIt<MyReportsNotificationsViewModel>().markSectionSeen();
        }
      });
    }

    void onLogout() {
      context.read<AuthViewModel>().logout();
      Navigator.pushReplacementNamed(context, AppRouter.login);
    }

    final sidebar = SidebarWidget(
      items: items,
      groups: groups,
      selectedIndex: safeIndex,
      onTap: (index) {
        onSectionTap(index);
        // Cierra el drawer al elegir opción en móvil.
        if (isMobile) Navigator.of(context).maybePop();
      },
      isExpanded: isMobile ? true : _sidebarExpanded,
      onToggle: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
      collapsedGroupIds: _collapsedGroupIds,
      onToggleGroup: (groupId) {
        setState(() {
          if (_collapsedGroupIds.contains(groupId)) {
            _collapsedGroupIds.remove(groupId);
          } else {
            _collapsedGroupIds.add(groupId);
          }
        });
      },
      userName: user.username,
      userDisplayName: user.displayName,
      onLogout: onLogout,
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_getTitle(safeIndex, user, sections)),
          // En móvil el AppBar muestra el ícono de menú automáticamente.
        ),
        drawer: Drawer(
          width: 285,
          backgroundColor: AppTheme.sidebarBackground,
          shape: const RoundedRectangleBorder(),
          child: sidebar,
        ),
        body: SafeArea(
          top: false,
          child: _buildContent(sections[safeIndex], sections),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(safeIndex, user, sections)),
        automaticallyImplyLeading: false,
      ),
      body: Row(
        children: [
          sidebar,
          Expanded(
            child: _buildContent(sections[safeIndex], sections),
          ),
        ],
      ),
    );
  }
}
