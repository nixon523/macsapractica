import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth_permissions/presentation/viewmodels/auth_viewmodel.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  int _counter = 0;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Usuario: ${user?.displayName ?? user?.username ?? 'NULL'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() => _counter++),
                child: Text('Contador: $_counter'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Escribe aquí',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => setState(() => _controller.clear()),
                child: const Text('Limpiar texto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
