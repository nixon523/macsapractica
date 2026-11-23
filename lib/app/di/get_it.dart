import 'package:get_it/get_it.dart';

import '../../core/audio/notification_sound.dart';
import '../../core/network/api_client.dart';
import '../../core/network/session_manager.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../core/notifications/notification_queue.dart';
import '../../features/app_update/data/datasources/app_update_remote_datasource.dart';
import '../../features/app_update/data/repositories/app_update_repository_impl.dart';
import '../../features/app_update/domain/repositories/app_update_repository.dart';
import '../../features/app_update/domain/usecases/check_android_update_usecase.dart';
import '../../features/app_update/presentation/viewmodels/app_update_viewmodel.dart';
import '../../features/assets/data/datasources/area_remote_datasource.dart';
import '../../features/assets/data/datasources/asset_local_datasource.dart';
import '../../features/assets/data/datasources/asset_remote_datasource.dart';
import '../../features/assets/data/datasources/asset_template_remote_datasource.dart';
import '../../features/assets/data/datasources/attribute_catalog_remote_datasource.dart';
import '../../features/assets/data/repositories/area_repository_impl.dart';
import '../../features/assets/data/repositories/asset_repository_impl.dart';
import '../../features/assets/data/repositories/asset_template_repository_impl.dart';
import '../../features/assets/data/repositories/attribute_catalog_repository_impl.dart';
import '../../features/assets/domain/repositories/area_repository.dart';
import '../../features/assets/domain/repositories/asset_repository.dart';
import '../../features/assets/domain/repositories/asset_template_repository.dart';
import '../../features/assets/domain/repositories/attribute_catalog_repository.dart';
import '../../features/assets/domain/usecases/asset_template_usecases.dart';
import '../../features/assets/domain/usecases/attribute_catalog_usecases.dart';
import '../../features/assets/domain/usecases/clone_asset_tree_usecase.dart';
import '../../features/assets/domain/usecases/create_area_usecase.dart';
import '../../features/assets/domain/usecases/create_asset_usecase.dart';
import '../../features/assets/domain/usecases/delete_area_usecase.dart';
import '../../features/assets/domain/usecases/find_asset_by_serial.dart';
import '../../features/assets/domain/usecases/get_areas_usecase.dart';
import '../../features/assets/domain/usecases/get_all_assets_by_area.dart';
import '../../features/assets/domain/usecases/get_assets_by_area.dart';
import '../../features/assets/domain/usecases/get_assets_by_parent.dart';
import '../../features/assets/domain/usecases/get_next_area_id_usecase.dart';
import '../../features/assets/domain/usecases/get_next_asset_id_usecase.dart';
import '../../features/assets/domain/usecases/reactivate_asset_usecase.dart';
import '../../features/assets/domain/usecases/search_assets.dart';
import '../../features/assets/domain/usecases/transfer_asset_usecase.dart';
import '../../features/assets/domain/usecases/update_area_usecase.dart';
import '../../features/assets/domain/usecases/update_asset_usecase.dart';
import '../../features/assets/presentation/viewmodels/area_create_edit_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/area_list_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/asset_create_edit_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/asset_detail_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/asset_list_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/asset_template_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/asset_transfer_viewmodel.dart';
import '../../features/assets/presentation/viewmodels/attribute_catalog_viewmodel.dart';
import '../../features/asset_deletion/data/datasources/asset_delete_remote_datasource.dart';
import '../../features/asset_deletion/data/repositories/asset_delete_repository_impl.dart';
import '../../features/asset_deletion/domain/repositories/asset_delete_repository.dart';
import '../../features/asset_deletion/domain/usecases/approve_asset_deletion.dart';
import '../../features/asset_deletion/domain/usecases/get_deletion_request_by_asset.dart';
import '../../features/asset_deletion/domain/usecases/get_deletion_requests.dart';
import '../../features/asset_deletion/domain/usecases/get_pending_deletion_requests.dart';
import '../../features/asset_deletion/domain/usecases/reject_asset_deletion.dart';
import '../../features/asset_deletion/domain/usecases/request_asset_deletion.dart';
import '../../features/asset_deletion/presentation/viewmodels/asset_deletion_request_viewmodel.dart';
import '../../features/asset_deletion/presentation/viewmodels/deletion_requests_viewmodel.dart';
import '../../features/auth_permissions/data/datasources/auth_remote_datasource.dart';
import '../../features/auth_permissions/data/repositories/auth_repository_impl.dart';
import '../../features/auth_permissions/domain/repositories/auth_repository.dart';
import '../../features/auth_permissions/domain/usecases/change_password_usecase.dart';
import '../../features/auth_permissions/domain/usecases/create_user_usecase.dart';
import '../../features/auth_permissions/domain/usecases/get_all_users.dart';
import '../../features/auth_permissions/domain/usecases/login.dart';
import '../../features/auth_permissions/domain/usecases/request_password_reset_usecase.dart';
import '../../features/auth_permissions/domain/usecases/reset_password_temporary_usecase.dart';
import '../../features/auth_permissions/domain/usecases/toggle_user_disabled_usecase.dart';
import '../../features/auth_permissions/domain/usecases/update_user_usecase.dart';
import '../../features/auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth_permissions/presentation/viewmodels/password_reset_alerts_viewmodel.dart';
import '../../features/auth_permissions/presentation/viewmodels/user_list_viewmodel.dart';
import '../../features/breakdown_reports/data/datasources/breakdown_report_remote_datasource.dart';
import '../../features/breakdown_reports/data/repositories/breakdown_report_repository_impl.dart';
import '../../features/breakdown_reports/domain/repositories/breakdown_report_repository.dart';
import '../../features/breakdown_reports/domain/usecases/create_breakdown_report.dart';
import '../../features/breakdown_reports/domain/usecases/get_all_breakdown_reports.dart';
import '../../features/breakdown_reports/domain/usecases/get_my_breakdown_reports.dart';
import '../../features/breakdown_reports/domain/usecases/get_open_breakdown_reports.dart';
import '../../features/breakdown_reports/domain/usecases/link_breakdown_to_work_order.dart';
import '../../features/breakdown_reports/domain/usecases/reject_breakdown_report.dart';
import '../../features/breakdown_reports/domain/usecases/resolve_breakdown_report.dart';
import '../../features/breakdown_reports/presentation/viewmodels/breakdown_alerts_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/breakdown_reports_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/my_reports_notifications_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/my_reports_viewmodel.dart';
import '../../features/breakdown_reports/presentation/viewmodels/report_breakdown_viewmodel.dart';
import '../../features/employees/data/datasources/employee_remote_datasource.dart';
import '../../features/employees/data/repositories/employee_repository_impl.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/domain/usecases/create_employee_usecase.dart';
import '../../features/employees/domain/usecases/get_employees_usecase.dart';
import '../../features/employees/domain/usecases/toggle_employee_status_usecase.dart';
import '../../features/employees/domain/usecases/update_employee_usecase.dart';
import '../../features/employees/presentation/viewmodels/employee_list_viewmodel.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import '../../features/kardex/data/datasources/kardex_remote_datasource.dart';
import '../../features/kardex/data/repositories/kardex_repository_impl.dart';
import '../../features/kardex/domain/repositories/kardex_repository.dart';
import '../../features/kardex/domain/usecases/get_all_kardex_logs.dart';
import '../../features/kardex/domain/usecases/get_kardex_logs.dart';
import '../../features/kardex/presentation/viewmodels/kardex_list_viewmodel.dart';
import '../../features/preventive_schedules/data/datasources/preventive_schedule_remote_datasource.dart';
import '../../features/preventive_schedules/data/repositories/preventive_schedule_repository_impl.dart';
import '../../features/preventive_schedules/domain/repositories/preventive_schedule_repository.dart';
import '../../features/preventive_schedules/domain/usecases/get_all_active_schedules.dart';
import '../../features/preventive_schedules/presentation/viewmodels/preventive_schedule_viewmodel.dart';
import '../../features/work_orders/data/datasources/work_order_remote_datasource.dart';
import '../../features/work_orders/data/repositories/work_order_repository_impl.dart';
import '../../features/work_orders/domain/repositories/work_order_repository.dart';
import '../../features/work_orders/domain/usecases/create_work_order.dart';
import '../../features/work_orders/domain/usecases/get_all_work_orders.dart';
import '../../features/work_orders/domain/usecases/get_work_orders.dart';
import '../../features/work_orders/domain/usecases/update_work_order_details.dart';
import '../../features/work_orders/domain/usecases/update_work_order_status.dart';
import '../../features/work_orders/presentation/viewmodels/work_order_alerts_viewmodel.dart';
import '../../features/work_orders/presentation/viewmodels/work_order_create_viewmodel.dart';
import '../../features/work_orders/presentation/viewmodels/work_order_detail_viewmodel.dart';
import '../../features/work_orders/presentation/viewmodels/work_order_list_viewmodel.dart';
import '../../features/operation_reports/data/datasources/operation_report_remote_datasource.dart';
import '../../features/operation_reports/data/repositories/operation_report_repository_impl.dart';
import '../../features/operation_reports/domain/repositories/operation_report_repository.dart';
import '../../features/operation_reports/domain/usecases/registrar_reporte_operacion.dart';
import '../../features/operation_reports/domain/usecases/obtener_reportes_por_activo.dart';
import '../../features/operation_reports/domain/usecases/obtener_reporte_semana.dart';
import '../../features/operation_reports/domain/usecases/obtener_metricas_operacion.dart';
import '../../features/operation_reports/domain/usecases/listar_equipos_proceso.dart';
import '../../features/operation_reports/domain/usecases/actualizar_es_equipo_proceso.dart';
import '../../features/operation_reports/domain/usecases/obtener_analitica_mantenimiento.dart';
import '../../features/operation_reports/presentation/viewmodels/maintenance_analytics_viewmodel.dart';
import '../../features/operation_reports/presentation/viewmodels/operation_report_viewmodel.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Reinicia GetIt para soportar Hot Restart (R) sin colisiones de registro
  await getIt.reset();

  // --- CAPA DE RED Y SESIÓN ---
  getIt.registerLazySingleton<SessionManager>(
    () => SessionManager.instance,
  );
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(sessionManager: getIt<SessionManager>()),
  );

  // --- CAPA DE DATOS (DataSources + Repositorios Impl) ---
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(
      apiClient: getIt<ApiClient>(),
      sessionManager: getIt<SessionManager>(),
    ),
  );
  getIt.registerLazySingleton<AssetRemoteDataSource>(
    () => AssetRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AssetLocalDataSource>(
    () => AssetLocalDataSource(),
  );
  getIt.registerLazySingleton<AreaRemoteDataSource>(
    () => AreaRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AreaRepository>(
    () => AreaRepositoryImpl(
      remoteDataSource: getIt<AreaRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<AssetRepository>(
    () => AssetRepositoryImpl(
      remoteDataSource: getIt<AssetRemoteDataSource>(),
      localDataSource: getIt<AssetLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<AttributeCatalogRemoteDataSource>(
    () => AttributeCatalogRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AttributeCatalogRepository>(
    () => AttributeCatalogRepositoryImpl(
      remoteDataSource: getIt<AttributeCatalogRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<AssetTemplateRemoteDataSource>(
    () => AssetTemplateRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AssetTemplateRepository>(
    () => AssetTemplateRepositoryImpl(
      remoteDataSource: getIt<AssetTemplateRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<AuthRemoteDataSource>()),
  );
  getIt.registerLazySingleton<PreventiveScheduleRemoteDataSource>(
    () => PreventiveScheduleRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PreventiveScheduleRepository>(
    () => PreventiveScheduleRepositoryImpl(
      getIt<PreventiveScheduleRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<WorkOrderRemoteDataSource>(
    () => WorkOrderRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<WorkOrderRepository>(
    () => WorkOrderRepositoryImpl(getIt<WorkOrderRemoteDataSource>()),
  );
  getIt.registerLazySingleton<KardexRemoteDataSource>(
    () => KardexRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<KardexRepository>(
    () => KardexRepositoryImpl(getIt<KardexRemoteDataSource>()),
  );
  getIt.registerLazySingleton<BreakdownReportRemoteDataSource>(
    () => BreakdownReportRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<BreakdownReportRepository>(
    () => BreakdownReportRepositoryImpl(
      remoteDataSource: getIt<BreakdownReportRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<AssetDeleteRemoteDataSource>(
    () => AssetDeleteRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AssetDeleteRepository>(
    () => AssetDeleteRepositoryImpl(
      remoteDataSource: getIt<AssetDeleteRemoteDataSource>(),
      assetRemoteDataSource: getIt<AssetRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton(
    () => DashboardRepository(getIt<DashboardRemoteDataSource>()),
  );

  // --- CAPA DE DOMINIO (Casos de Uso) ---
  getIt.registerLazySingleton(
    () => GetAssetsByAreaUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAllAssetsByAreaUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAssetsByParentUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetNextAssetIdUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => SearchAssetsUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAreasUseCase(getIt<AreaRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetNextAreaIdUseCase(getIt<AreaRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateAreaUseCase(getIt<AreaRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateAreaUseCase(getIt<AreaRepository>()),
  );
  getIt.registerLazySingleton(
    () => DeleteAreaUseCase(getIt<AreaRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAttributeCatalogUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => SaveAttributeDefinitionUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => DeleteAttributeDefinitionUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetUnitsOfMeasureUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => SaveUnitOfMeasureUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => DeleteUnitOfMeasureUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetBrandsUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => SaveBrandUseCase(getIt<AttributeCatalogRepository>()),
  );
  getIt.registerLazySingleton(
    () => DeleteBrandUseCase(getIt<AttributeCatalogRepository>()),
  );

  getIt.registerLazySingleton(
    () => CreateAssetUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => TransferAssetUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => ReactivateAssetUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateAssetUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => CloneAssetTreeUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAssetTemplatesUseCase(getIt<AssetTemplateRepository>()),
  );
  getIt.registerLazySingleton(
    () => SaveAssetTemplateUseCase(getIt<AssetTemplateRepository>()),
  );
  getIt.registerLazySingleton(
    () => InstantiateAssetTemplateUseCase(getIt<AssetTemplateRepository>()),
  );
  getIt.registerLazySingleton(
    () => DeleteAssetTemplateUseCase(getIt<AssetTemplateRepository>()),
  );
  getIt.registerLazySingleton(
    () => LoginUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAllUsersUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateUserUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateUserUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => ToggleUserDisabledUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => ChangePasswordUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => ResetPasswordTemporaryUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => RequestPasswordResetUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => FindAssetBySerialUseCase(getIt<AssetRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAllActiveSchedulesUseCase(getIt<PreventiveScheduleRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAllWorkOrdersUseCase(getIt<WorkOrderRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetWorkOrdersUseCase(getIt<WorkOrderRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateWorkOrderUseCase(getIt<WorkOrderRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAllKardexLogsUseCase(getIt<KardexRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetKardexLogsUseCase(getIt<KardexRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateBreakdownReportUseCase(getIt<BreakdownReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetAllBreakdownReportsUseCase(getIt<BreakdownReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetMyBreakdownReportsUseCase(getIt<BreakdownReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetOpenBreakdownReportsUseCase(getIt<BreakdownReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => LinkBreakdownToWorkOrderUseCase(getIt<BreakdownReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => ResolveBreakdownReportUseCase(getIt<BreakdownReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => RejectBreakdownReportUseCase(getIt<BreakdownReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateWorkOrderStatusUseCase(getIt<WorkOrderRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateWorkOrderDetailsUseCase(getIt<WorkOrderRepository>()),
  );
  getIt.registerLazySingleton(
    () => RequestAssetDeletionUseCase(getIt<AssetDeleteRepository>()),
  );
  getIt.registerLazySingleton(
    () => ApproveAssetDeletionUseCase(getIt<AssetDeleteRepository>()),
  );
  getIt.registerLazySingleton(
    () => RejectAssetDeletionUseCase(getIt<AssetDeleteRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetPendingDeletionRequestsUseCase(getIt<AssetDeleteRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetDeletionRequestsUseCase(getIt<AssetDeleteRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetDeletionRequestByAssetUseCase(getIt<AssetDeleteRepository>()),
  );

  // --- CAPA DE PRESENTACIÓN (ViewModels) ---
  getIt.registerLazySingleton<AuthViewModel>(
    () => AuthViewModel(
      loginUseCase: getIt<LoginUseCase>(),
      changePasswordUseCase: getIt<ChangePasswordUseCase>(),
      requestPasswordResetUseCase: getIt<RequestPasswordResetUseCase>(),
    ),
  );
  getIt.registerFactory<AssetListViewModel>(
    () => AssetListViewModel(
      getAssetsByAreaUseCase: getIt<GetAssetsByAreaUseCase>(),
      getAllAssetsByAreaUseCase: getIt<GetAllAssetsByAreaUseCase>(),
      getAssetsByParentUseCase: getIt<GetAssetsByParentUseCase>(),
      searchAssetsUseCase: getIt<SearchAssetsUseCase>(),
    ),
  );
  getIt.registerFactory<AssetDetailViewModel>(
    () => AssetDetailViewModel(
      getAssetsByParentUseCase: getIt<GetAssetsByParentUseCase>(),
      reactivateAssetUseCase: getIt<ReactivateAssetUseCase>(),
      assetRepository: getIt<AssetRepository>(),
      cloneAssetTreeUseCase: getIt<CloneAssetTreeUseCase>(),
    ),
  );
  getIt.registerFactory<AssetTemplateViewModel>(
    () => AssetTemplateViewModel(
      getTemplatesUseCase: getIt<GetAssetTemplatesUseCase>(),
      saveTemplateUseCase: getIt<SaveAssetTemplateUseCase>(),
      instantiateTemplateUseCase: getIt<InstantiateAssetTemplateUseCase>(),
      deleteTemplateUseCase: getIt<DeleteAssetTemplateUseCase>(),
    ),
  );
  getIt.registerLazySingleton<AssetTransferViewModel>(
    () => AssetTransferViewModel(
      transferAssetUseCase: getIt<TransferAssetUseCase>(),
    ),
  );
  getIt.registerFactory(
    () => AssetCreateEditViewModel(
      createAssetUseCase: getIt<CreateAssetUseCase>(),
      updateAssetUseCase: getIt<UpdateAssetUseCase>(),
      getNextAssetIdUseCase: getIt<GetNextAssetIdUseCase>(),
      findAssetBySerialUseCase: getIt<FindAssetBySerialUseCase>(),
    ),
  );
  getIt.registerLazySingleton<AreaListViewModel>(
    () => AreaListViewModel(
      getAreasUseCase: getIt<GetAreasUseCase>(),
      updateAreaUseCase: getIt<UpdateAreaUseCase>(),
      deleteAreaUseCase: getIt<DeleteAreaUseCase>(),
    ),
  );
  getIt.registerLazySingleton<AttributeCatalogViewModel>(
    () => AttributeCatalogViewModel(
      getAttributeCatalogUseCase: getIt<GetAttributeCatalogUseCase>(),
      saveAttributeDefinitionUseCase: getIt<SaveAttributeDefinitionUseCase>(),
      deleteAttributeDefinitionUseCase: getIt<DeleteAttributeDefinitionUseCase>(),
      getUnitsOfMeasureUseCase: getIt<GetUnitsOfMeasureUseCase>(),
      saveUnitOfMeasureUseCase: getIt<SaveUnitOfMeasureUseCase>(),
      deleteUnitOfMeasureUseCase: getIt<DeleteUnitOfMeasureUseCase>(),
      getBrandsUseCase: getIt<GetBrandsUseCase>(),
      saveBrandUseCase: getIt<SaveBrandUseCase>(),
      deleteBrandUseCase: getIt<DeleteBrandUseCase>(),
    ),
  );
  getIt.registerFactory(
    () => AreaCreateEditViewModel(
      createAreaUseCase: getIt<CreateAreaUseCase>(),
      getNextAreaIdUseCase: getIt<GetNextAreaIdUseCase>(),
    ),
  );
  getIt.registerLazySingleton<PreventiveScheduleViewModel>(
    () => PreventiveScheduleViewModel(
      repository: getIt<PreventiveScheduleRepository>(),
      workOrderRepository: getIt<WorkOrderRepository>(),
    ),
  );
  getIt.registerLazySingleton<WorkOrderListViewModel>(
    () => WorkOrderListViewModel(
      getAllWorkOrdersUseCase: getIt<GetAllWorkOrdersUseCase>(),
      getWorkOrdersUseCase: getIt<GetWorkOrdersUseCase>(),
    ),
  );
  getIt.registerFactory<WorkOrderCreateViewModel>(
    () => WorkOrderCreateViewModel(
      createWorkOrderUseCase: getIt<CreateWorkOrderUseCase>(),
      linkBreakdownToWorkOrderUseCase: getIt<LinkBreakdownToWorkOrderUseCase>(),
      getAreasUseCase: getIt<GetAreasUseCase>(),
      getAssetsByAreaUseCase: getIt<GetAssetsByAreaUseCase>(),
      workOrderRepository: getIt<WorkOrderRepository>(),
    ),
  );
  getIt.registerFactory<WorkOrderDetailViewModel>(
    () => WorkOrderDetailViewModel(
      updateStatusUseCase: getIt<UpdateWorkOrderStatusUseCase>(),
      updateDetailsUseCase: getIt<UpdateWorkOrderDetailsUseCase>(),
    ),
  );
  getIt.registerFactory<ReportBreakdownViewModel>(
    () => ReportBreakdownViewModel(
      getAreasUseCase: getIt<GetAreasUseCase>(),
      getAssetsByAreaUseCase: getIt<GetAssetsByAreaUseCase>(),
      createBreakdownReportUseCase: getIt<CreateBreakdownReportUseCase>(),
      getOpenBreakdownReportsUseCase: getIt<GetOpenBreakdownReportsUseCase>(),
    ),
  );
  getIt.registerLazySingleton<MyReportsViewModel>(
    () => MyReportsViewModel(
      getMyReportsUseCase: getIt<GetMyBreakdownReportsUseCase>(),
    ),
  );
  getIt.registerLazySingleton<BreakdownReportsViewModel>(
    () => BreakdownReportsViewModel(
      getAllReportsUseCase: getIt<GetAllBreakdownReportsUseCase>(),
      resolveReportUseCase: getIt<ResolveBreakdownReportUseCase>(),
      rejectReportUseCase: getIt<RejectBreakdownReportUseCase>(),
    ),
  );
  getIt.registerLazySingleton<BreakdownAlertsViewModel>(
    () => BreakdownAlertsViewModel(
      repository: getIt<BreakdownReportRepository>(),
    ),
  );
  getIt.registerLazySingleton<PasswordResetAlertsViewModel>(
    () => PasswordResetAlertsViewModel(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<MyReportsNotificationsViewModel>(
    () => MyReportsNotificationsViewModel(
      repository: getIt<BreakdownReportRepository>(),
    ),
  );
  getIt.registerLazySingleton<NotificationSound>(
    () => NotificationSound(),
  );
  getIt.registerLazySingleton<LocalNotificationService>(
    () => LocalNotificationService(),
  );
  getIt.registerLazySingleton<NotificationQueue>(
    () => NotificationQueue(),
  );
  getIt.registerLazySingleton<WorkOrderAlertsViewModel>(
    () => WorkOrderAlertsViewModel(
      repository: getIt<WorkOrderRepository>(),
    ),
  );
  getIt.registerLazySingleton<KardexListViewModel>(
    () => KardexListViewModel(
      getAllKardexLogsUseCase: getIt<GetAllKardexLogsUseCase>(),
      getKardexLogsUseCase: getIt<GetKardexLogsUseCase>(),
    ),
  );
  getIt.registerLazySingleton<UserListViewModel>(
    () => UserListViewModel(
      getAllUsersUseCase: getIt<GetAllUsersUseCase>(),
      createUserUseCase: getIt<CreateUserUseCase>(),
      updateUserUseCase: getIt<UpdateUserUseCase>(),
      toggleUserDisabledUseCase: getIt<ToggleUserDisabledUseCase>(),
      resetPasswordTemporaryUseCase: getIt<ResetPasswordTemporaryUseCase>(),
    ),
  );
  getIt.registerFactory<AssetDeletionRequestViewModel>(
    () => AssetDeletionRequestViewModel(
      getDeletionRequestByAssetUseCase:
          getIt<GetDeletionRequestByAssetUseCase>(),
      requestAssetDeletionUseCase: getIt<RequestAssetDeletionUseCase>(),
    ),
  );
  getIt.registerFactory<DeletionRequestsViewModel>(
    () => DeletionRequestsViewModel(
      getDeletionRequestsUseCase: getIt<GetDeletionRequestsUseCase>(),
      approveAssetDeletionUseCase: getIt<ApproveAssetDeletionUseCase>(),
      rejectAssetDeletionUseCase: getIt<RejectAssetDeletionUseCase>(),
    ),
  );
  getIt.registerLazySingleton<DashboardViewModel>(
    () => DashboardViewModel(
      dashboardRepository: getIt<DashboardRepository>(),
      getAllWorkOrdersUseCase: getIt<GetAllWorkOrdersUseCase>(),
      getAllBreakdownReportsUseCase: getIt<GetAllBreakdownReportsUseCase>(),
      preventiveScheduleRepository: getIt<PreventiveScheduleRepository>(),
    ),
  );

  // --- MÓDULO: Reportes de Operación / Disponibilidad ---
  getIt.registerLazySingleton<OperationReportRemoteDataSource>(
    () => OperationReportRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<OperationReportRepository>(
    () => OperationReportRepositoryImpl(getIt<OperationReportRemoteDataSource>()),
  );
  getIt.registerLazySingleton<RegistrarReporteOperacion>(
    () => RegistrarReporteOperacion(getIt<OperationReportRepository>()),
  );
  getIt.registerLazySingleton<ObtenerReportesPorActivo>(
    () => ObtenerReportesPorActivo(getIt<OperationReportRepository>()),
  );
  getIt.registerLazySingleton<ObtenerReporteSemana>(
    () => ObtenerReporteSemana(getIt<OperationReportRepository>()),
  );
  getIt.registerLazySingleton<ObtenerMetricasOperacion>(
    () => ObtenerMetricasOperacion(getIt<OperationReportRepository>()),
  );
  getIt.registerLazySingleton<ListarEquiposProceso>(
    () => ListarEquiposProceso(getIt<OperationReportRepository>()),
  );
  getIt.registerLazySingleton<ActualizarEsEquipoProceso>(
    () => ActualizarEsEquipoProceso(getIt<OperationReportRepository>()),
  );
  getIt.registerLazySingleton<ObtenerAnaliticaMantenimientoUseCase>(
    () => ObtenerAnaliticaMantenimientoUseCase(getIt<OperationReportRepository>()),
  );
  getIt.registerFactory<MaintenanceAnalyticsViewModel>(
    () => MaintenanceAnalyticsViewModel(
      analyticsUseCase: getIt<ObtenerAnaliticaMantenimientoUseCase>(),
    ),
  );
  getIt.registerLazySingleton<OperationReportViewModel>(
    () => OperationReportViewModel(
      registrar:       getIt<RegistrarReporteOperacion>(),
      obtenerSemana:   getIt<ObtenerReporteSemana>(),
      obtenerMetricas: getIt<ObtenerMetricasOperacion>(),
      listarEquipos:   getIt<ListarEquiposProceso>(),
      actualizarEquipo: getIt<ActualizarEsEquipoProceso>(),
    ),
  );

  // --- MÓDULO: Actualizaciones Android ---
  getIt.registerLazySingleton<AppUpdateRemoteDataSource>(
    () => AppUpdateRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AppUpdateRepository>(
    () => AppUpdateRepositoryImpl(getIt<AppUpdateRemoteDataSource>()),
  );
  getIt.registerLazySingleton<CheckAndroidUpdateUseCase>(
    () => CheckAndroidUpdateUseCase(getIt<AppUpdateRepository>()),
  );
  getIt.registerLazySingleton<AppUpdateViewModel>(
    () => AppUpdateViewModel(
      checkAndroidUpdateUseCase: getIt<CheckAndroidUpdateUseCase>(),
    ),
  );

  // --- MÓDULO: Empleados / Personal Técnico ---
  getIt.registerLazySingleton<EmployeeRemoteDataSource>(
    () => EmployeeRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(getIt<EmployeeRemoteDataSource>()),
  );
  getIt.registerLazySingleton<GetEmployeesUseCase>(
    () => GetEmployeesUseCase(getIt<EmployeeRepository>()),
  );
  getIt.registerLazySingleton<CreateEmployeeUseCase>(
    () => CreateEmployeeUseCase(getIt<EmployeeRepository>()),
  );
  getIt.registerLazySingleton<UpdateEmployeeUseCase>(
    () => UpdateEmployeeUseCase(getIt<EmployeeRepository>()),
  );
  getIt.registerLazySingleton<ToggleEmployeeStatusUseCase>(
    () => ToggleEmployeeStatusUseCase(getIt<EmployeeRepository>()),
  );
  getIt.registerLazySingleton<EmployeeListViewModel>(
    () => EmployeeListViewModel(
      getEmployeesUseCase: getIt<GetEmployeesUseCase>(),
      createEmployeeUseCase: getIt<CreateEmployeeUseCase>(),
      updateEmployeeUseCase: getIt<UpdateEmployeeUseCase>(),
      toggleEmployeeStatusUseCase: getIt<ToggleEmployeeStatusUseCase>(),
    ),
  );
}
