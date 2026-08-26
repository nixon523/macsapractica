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
import '../../core/audio/notification_sound.dart';
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

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;
    if (user.isAdmin || user.role == UserRole.jefe) {
      getIt<BreakdownAlertsViewModel>().start();
    }
    if (user.isAdmin) {
      getIt<PasswordResetAlertsViewModel>().start();
    }
    if (user.role == UserRole.reportador) {
      getIt<MyReportsNotificationsViewModel>().start(user.userId);
    }
  }

  @override
  void dispose() {
    getIt<BreakdownAlertsViewModel>().stop();
    getIt<PasswordResetAlertsViewModel>().stop();
    getIt<MyReportsNotificationsViewModel>().stop();
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

  /// Secciones del menú según el rol:
  ///   - admin (Gestor del Sistema): todo, sin restricción.
  ///   - lector (Solo Lectura): solo información, sin acciones.
  ///   - reportador: únicamente reportar averías y ver sus propios reportes.
  static List<_ShellSection> _sectionsFor(AppUser user) {
    return switch (user.role) {
      UserRole.admin => const [
          _ShellSection.dashboard,
          _ShellSection.assets,
          _ShellSection.workOrders,
          _ShellSection.preventive,
          _ShellSection.kardex,
          _ShellSection.reportBreakdown,
          _ShellSection.breakdownReports,
          _ShellSection.deletionRequests,
          _ShellSection.users,
        ],
      UserRole.jefe => const [
          _ShellSection.dashboard,
          _ShellSection.assets,
          _ShellSection.workOrders,
          _ShellSection.preventive,
          _ShellSection.kardex,
          _ShellSection.breakdownReports,
        ],
      UserRole.reportador => const [
          _ShellSection.reportBreakdown,
          _ShellSection.myReports,
        ],
      UserRole.lector => const [
          _ShellSection.dashboard,
          _ShellSection.assets,
          _ShellSection.workOrders,
          _ShellSection.preventive,
          _ShellSection.kardex,
          _ShellSection.breakdownReports,
        ],
    };
  }

  String _getTitle(int index, AppUser user, List<_ShellSection> sections) {
    if (index >= sections.length) return 'Grupo Macsa';
    final section = sections[index];
    if (section == _ShellSection.dashboard) {
      return 'Hola, ${user.displayName ?? user.username}';
    }
    return _sectionToItem[section]?.label ?? 'Grupo Macsa';
  }

  Widget _buildContent(_ShellSection section) {
    return switch (section) {
      _ShellSection.dashboard => const DashboardView(),
      _ShellSection.assets => const AreaSelectionView(),
      _ShellSection.workOrders => const WorkOrderListView(),
      _ShellSection.preventive => const PreventiveScheduleListView(),
      _ShellSection.kardex => const KardexListView(),
      _ShellSection.reportBreakdown => const ReportBreakdownView(),
      _ShellSection.myReports => const MyReportsView(),
      _ShellSection.breakdownReports => const BreakdownReportsView(),
      _ShellSection.deletionRequests => const DeletionRequestsView(),
      _ShellSection.users => const UserListView(),
    };
  }

  /// Muestra el aviso cuando llega una avería nueva (una vez por reporte).
  void _showNewReportAlert(BreakdownAlertsViewModel alertsVm, AppUser user) {
    if (alertsVm.latestNewReport == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final report = alertsVm.consumeLatestReport();
      if (report == null) return;

      getIt<NotificationSound>().play();

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            dismissDirection: DismissDirection.horizontal,
            content: Text(
              'Nueva avería reportada por ${report.reportedByUserName}: '
              '${report.assetId} — ${report.assetName} '
              '(Área ${report.areaId}).',
            ),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () {
                final sections = _sectionsFor(user);
                final index = sections.indexOf(_ShellSection.breakdownReports);
                if (index >= 0) {
                  setState(() => _selectedIndex = index);
                }
              },
            ),
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
      final message = switch (outcome.kind) {
        ReportOutcomeKind.workOrderGenerated =>
          'Tu reporte de ${report.assetId} fue atendido: se generó la OT '
          '${report.workOrderId ?? ''}.',
        ReportOutcomeKind.rejected =>
          'Tu reporte de ${report.assetId} fue rechazado. '
          'Motivo: ${report.rejectionReason ?? '—'}',
      };

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            dismissDirection: DismissDirection.horizontal,
            content: Text(message),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () {
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

      getIt<NotificationSound>().play();

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 7),
            dismissDirection: DismissDirection.horizontal,
            content: Row(
              children: [
                const Icon(Icons.key, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solicitud de clave: ${requestUser.displayName ?? requestUser.username} (@${requestUser.username}) solicitó una clave temporal.',
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Atender',
              textColor: Colors.amberAccent,
              onPressed: () {
                final sections = _sectionsFor(user);
                final index = sections.indexOf(_ShellSection.users);
                if (index >= 0) {
                  setState(() => _selectedIndex = index);
                }
              },
            ),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final alertsVm = context.watch<BreakdownAlertsViewModel>();
    _showNewReportAlert(alertsVm, user);

    final reportsVm = context.watch<MyReportsNotificationsViewModel>();
    _showReportOutcomeAlert(reportsVm, user);

    final resetAlertsVm = context.watch<PasswordResetAlertsViewModel>();
    if (user.isAdmin) {
      _showPasswordResetAlert(resetAlertsVm, user);
    }

    final preventiveVm = context.watch<PreventiveScheduleViewModel>();

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
                          : 0,
        ),
    ];

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
      selectedIndex: safeIndex,
      onTap: (index) {
        onSectionTap(index);
        // Cierra el drawer al elegir opción en móvil.
        if (isMobile) Navigator.of(context).maybePop();
      },
      isExpanded: isMobile ? true : _sidebarExpanded,
      onToggle: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
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
          width: 240,
          backgroundColor: AppTheme.sidebarBackground,
          shape: const RoundedRectangleBorder(),
          child: sidebar,
        ),
        body: SafeArea(
          top: false,
          child: _buildContent(sections[safeIndex]),
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
            child: _buildContent(sections[safeIndex]),
          ),
        ],
      ),
    );
  }
}
