import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_router.dart';
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
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
        builder: (context, authVm, child) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Recuperar Acceso'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por políticas de seguridad de Grupo Macsa, las contraseñas son confidenciales y están cifradas. '
                    'Para restablecer tu acceso, ingresa tu usuario y el Administrador te generará una contraseña temporal segura.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: resetUsernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario *',
                      hintText: 'Ej: admin',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Ingresa tu usuario'
                            : null,
                  ),
                  if (authVm.errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      authVm.errorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
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
        ),
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
      body: Center(
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
                      Icon(
                        Icons.factory_outlined,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
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
    );
  }
}
