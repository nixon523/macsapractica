import 'package:flutter/material.dart';

import '../screens/main_shell_screen.dart';
import '../../features/auth_permissions/presentation/views/auth_view.dart';
import '../../features/auth_permissions/presentation/views/change_temporary_password_view.dart';
import '../../features/assets/domain/entities/asset.dart';
import '../../features/assets/presentation/views/area_create_view.dart';
import '../../features/assets/presentation/views/asset_create_view.dart';
import '../../features/assets/presentation/views/asset_detail_view.dart';
import '../../features/assets/presentation/views/asset_list_view.dart';
import '../../features/assets/presentation/views/asset_transfer_view.dart';
import '../../features/work_orders/presentation/views/work_order_list_view.dart';
import '../../features/kardex/presentation/views/kardex_list_view.dart';

/// Argumentos estructurados para la ruta de creación de activos.
class AssetCreateArgs {
  const AssetCreateArgs({
    required this.areaId,
    this.parentAsset,
  });

  final String areaId;
  final Asset? parentAsset;
}

/// Argumentos para la ruta de detalle de un activo.
class AssetDetailArgs {
  const AssetDetailArgs({required this.areaId, required this.asset});

  final String areaId;
  final Asset asset;
}

/// Argumentos para la ruta de transferencia de un equipo.
class AssetTransferArgs {
  const AssetTransferArgs({required this.asset});

  final Asset asset;
}

class AppRouter {
  const AppRouter._();

  static const String login = '/';
  static const String main = '/main';
  static const String assets = '/assets';
  static const String assetDetail = '/assets/detail';
  static const String assetTransfer = '/assets/transfer';
  static const String assetCreate = '/assets/create';
  static const String areaCreate = '/areas/create';
  static const String workOrders = '/work-orders';
  static const String kardex = '/kardex';
  static const String changeTemporaryPassword = '/change-temporary-password';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _page(const AuthView(), settings);
      case changeTemporaryPassword:
        return _page(const ChangeTemporaryPasswordView(), settings);
      case main:
        return _page(const MainShellScreen(), settings);
      case assets:
        final areaId = settings.arguments as String? ?? '';
        return _page(AssetListView(areaId: areaId), settings);
      case assetDetail:
        final args = settings.arguments as AssetDetailArgs?;
        return _page(
          AssetDetailView(areaId: args!.areaId, asset: args.asset),
          settings,
        );
      case assetTransfer:
        final args = settings.arguments as AssetTransferArgs?;
        return _page(
          AssetTransferView(asset: args!.asset),
          settings,
        );
      case assetCreate:
        final args = settings.arguments as AssetCreateArgs?;
        final areaId = args?.areaId ?? '';
        return _page(
          AssetCreateView(areaId: areaId, parentAsset: args?.parentAsset),
          settings,
        );
      case areaCreate:
        return _page(const AreaCreateView(), settings);
      case workOrders:
        return _page(const WorkOrderListView(), settings);
      case kardex:
        final entityId = settings.arguments as String? ?? '';
        return _page(KardexListView(entityId: entityId), settings);
      default:
        return _page(const AuthView(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(
    Widget child,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(builder: (_) => child, settings: settings);
  }
}
