import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/get_it.dart';
import 'core/config/app_version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppVersion.initialize();
  await configureDependencies();

  runApp(const MacsaApp());
}

