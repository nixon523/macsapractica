import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/get_it.dart';
import 'core/config/app_version.dart';
import 'core/network/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppVersion.initialize();
  await SessionManager.instance.init();
  await configureDependencies();

  runApp(const MacsaApp());
}

