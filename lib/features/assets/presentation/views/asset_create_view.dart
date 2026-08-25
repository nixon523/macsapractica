import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:macsapractica/app/di/get_it.dart';
import '../../domain/entities/asset.dart';
import '../viewmodels/asset_create_edit_viewmodel.dart';
import 'asset_form_view.dart';

class AssetCreateView extends StatelessWidget {
  const AssetCreateView({
    super.key,
    required this.areaId,
    this.parentAsset,
  });

  final String areaId;
  final Asset? parentAsset;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AssetCreateEditViewModel>(
      create: (_) => getIt<AssetCreateEditViewModel>(),
      child: AssetFormView(
        areaId: areaId,
        parentAsset: parentAsset,
      ),
    );
  }
}
