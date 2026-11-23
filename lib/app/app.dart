import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/session_manager.dart';
import 'config/app_constants.dart';
import 'di/providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MacsaApp extends StatelessWidget {
  const MacsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: appProviders,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: SessionManager.instance.isAuthenticated
            ? AppRouter.main
            : AppRouter.login,
      ),
    );
  }
}
