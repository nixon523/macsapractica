import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/get_it.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();

  runApp(const MacsaApp());
}
