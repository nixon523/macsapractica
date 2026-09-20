import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/widgets/app_dialog.dart';
import '../../../../core/utils/upper_case_formatter.dart';
import '../../../app_update/presentation/viewmodels/app_update_viewmodel.dart';
import '../../../app_update/presentation/views/widgets/app_update_dialog.dart';
import '../viewmodels/auth_viewmodel.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndroidUpdate();
    });
  }

  Future<void> _checkAndroidUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final updateVm = context.read<AppUpdateViewModel>();
    await updateVm.checkForUpdates();
    if (!mounted) return;
    if (updateVm.shouldShowDialog && updateVm.versionInfo != null) {
      showDialog(
        context: context,
        barrierDismissible: !updateVm.isMandatory,
        builder: (_) => AppUpdateDialog(
          versionInfo: updateVm.versionInfo!,
          currentVersion: updateVm.currentVersion,
          viewModel: updateVm,
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final updateVm = context.read<AppUpdateViewModel>();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && updateVm.hasUpdate && updateVm.isMandatory) {
      _checkAndroidUpdate();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final authVm = context.read<AuthViewModel>();
    final success = await authVm.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      _passwordController.clear();
      if (authVm.mustChangePassword) {
        Navigator.pushReplacementNamed(
          context,
          AppRouter.changeTemporaryPassword,
        );
      } else {
        Navigator.pushReplacementNamed(context, AppRouter.main);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetUsernameController = TextEditingController(
      text: _usernameController.text.trim(),
    );
    final resetFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => Consumer<AuthViewModel>(
        builder: (context, authVm, child) {
          final theme = Theme.of(context);
          return AppDialog(
            maxWidth: 460,
            icon: Icon(Icons.lock_reset, color: theme.colorScheme.primary),
            title: const Text('Recuperar Acceso'),
            content: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por políticas de seguridad de Grupo Macsa, las contraseñas son confidenciales y están cifradas. '
                    'Para restablecer tu acceso, ingresa tu usuario y el Administrador te generará una contraseña temporal segura.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: resetUsernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario *',
                      hintText: 'Ej: ADMIN',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Ingresa tu usuario'
                            : null,
                  ),
                  if (authVm.errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      authVm.errorMessage,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: authVm.isProcessing
                    ? null
                    : () {
                        authVm.clearMessages();
                        Navigator.pop(ctx);
                      },
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: authVm.isProcessing
                    ? null
                    : () async {
                        if (!resetFormKey.currentState!.validate()) return;
                        final ok = await authVm.requestPasswordReset(
                          username: resetUsernameController.text.trim(),
                        );
                        if (ok && ctx.mounted) {
                          Navigator.pop(ctx);
                          _showResetSuccessDialog(
                            resetUsernameController.text.trim(),
                          );
                        }
                      },
                icon: authVm.isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: const Text('Solicitar Clave'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetSuccessDialog(String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Solicitud Enviada'),
          ],
        ),
        content: Text(
          'Se ha registrado la solicitud de restablecimiento para el usuario "$username".\n\n'
          'El Administrador recibirá la alerta para generarte una contraseña temporal segura.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/macsa_logo.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Grupo Macsa',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Sistema de Gestión de Mantenimiento Preventivo - PM',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Ingresa tu usuario'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Ingresa tu contraseña'
                            : null,
                      ),
                      if (viewModel.errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          viewModel.errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: viewModel.isLoggingIn ? null : _submit,
                        child: viewModel.isLoggingIn
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: viewModel.isLoggingIn
                            ? null
                            : _showForgotPasswordDialog,
                        icon: const Icon(Icons.help_outline, size: 16),
                        label: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
