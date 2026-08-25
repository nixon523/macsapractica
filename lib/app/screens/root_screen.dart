import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth_permissions/presentation/views/auth_view.dart';
import 'main_shell_screen.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, viewModel, child) {
        return viewModel.isLoggedIn ? const MainShellScreen() : const AuthView();
      },
    );
  }
}
