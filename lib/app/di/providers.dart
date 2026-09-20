import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/assets/presentation/viewmodels/asset_transfer_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/area_list_viewmodel.dart';
import '../../features/auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth_permissions/presentation/viewmodels/user_list_viewmodel.dart';
import '../../features/auth_permissions/presentation/viewmodels/password_reset_alerts_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/breakdown_alerts_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/breakdown_reports_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/my_reports_notifications_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/my_reports_viewmodel.dart';
import '../../features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import '../../features/kardex/presentation/viewmodels/kardex_list_viewmodel.dart';
import '../../features/preventive_schedules/presentation/viewmodels/preventive_schedule_viewmodel.dart';
import '../../features/work_orders/presentation/viewmodels/work_order_list_viewmodel.dart';
import '../../features/work_orders/presentation/viewmodels/work_order_alerts_viewmodel.dart';
import '../../features/app_update/presentation/viewmodels/app_update_viewmodel.dart';
import 'get_it.dart';

final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider<AppUpdateViewModel>(
    create: (_) => getIt<AppUpdateViewModel>(),
  ),
  ChangeNotifierProvider<AuthViewModel>(
    create: (_) => getIt<AuthViewModel>(),
  ),
  ChangeNotifierProvider<AssetTransferViewModel>(
    create: (_) => getIt<AssetTransferViewModel>(),
  ),
  ChangeNotifierProvider<AreaListViewModel>(
    create: (_) => getIt<AreaListViewModel>(),
  ),
  ChangeNotifierProvider<PreventiveScheduleViewModel>(
    create: (_) => getIt<PreventiveScheduleViewModel>(),
  ),
  ChangeNotifierProvider<WorkOrderListViewModel>(
    create: (_) => getIt<WorkOrderListViewModel>(),
  ),
  ChangeNotifierProvider<KardexListViewModel>(
    create: (_) => getIt<KardexListViewModel>(),
  ),
  ChangeNotifierProvider<UserListViewModel>(
    create: (_) => getIt<UserListViewModel>(),
  ),
  ChangeNotifierProvider<MyReportsViewModel>(
    create: (_) => getIt<MyReportsViewModel>(),
  ),
  ChangeNotifierProvider<BreakdownReportsViewModel>(
    create: (_) => getIt<BreakdownReportsViewModel>(),
  ),
  ChangeNotifierProvider<BreakdownAlertsViewModel>(
    create: (_) => getIt<BreakdownAlertsViewModel>(),
  ),
  ChangeNotifierProvider<MyReportsNotificationsViewModel>(
    create: (_) => getIt<MyReportsNotificationsViewModel>(),
  ),
  ChangeNotifierProvider<DashboardViewModel>(
    create: (_) => getIt<DashboardViewModel>(),
  ),
  ChangeNotifierProvider<PasswordResetAlertsViewModel>(
    create: (_) => getIt<PasswordResetAlertsViewModel>(),
  ),
  ChangeNotifierProvider<WorkOrderAlertsViewModel>(
    create: (_) => getIt<WorkOrderAlertsViewModel>(),
  ),
];
