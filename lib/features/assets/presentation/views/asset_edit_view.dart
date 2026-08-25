import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/app/di/get_it.dart';
import '../../domain/entities/asset.dart';
import '../viewmodels/asset_create_edit_viewmodel.dart';
import 'asset_form_view.dart';

class AssetEditView extends StatelessWidget {
  const AssetEditView({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AssetCreateEditViewModel>(
      create: (_) => getIt<AssetCreateEditViewModel>(),
      child: AssetFormView(asset: asset, areaId: asset.areaId),
    );
  }
}
