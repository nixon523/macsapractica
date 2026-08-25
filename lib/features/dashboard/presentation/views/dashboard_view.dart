import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardViewModel>().loadStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final vm = context.watch<DashboardViewModel>();
    final stats = vm.stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido, ${user?.displayName ?? user?.username ?? 'Usuario'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Resumen del sistema de mantenimiento',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          if (vm.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (vm.errorMessage.isNotEmpty)
            Center(
              child: Column(
                children: [
                  Text('Error: ${vm.errorMessage}'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => vm.loadStats(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else ...[
            _SummaryCardsRow(
              cards: [
                _SummaryCard(
                  icon: Icons.precision_manufacturing_outlined,
                  label: 'Activos',
                  value: '${stats?.totalAssets ?? 0}',
                  color: Colors.teal,
                ),
                _SummaryCard(
                  icon: Icons.assignment_outlined,
                  label: 'OTs Pendientes',
                  value: '${stats?.pendingWorkOrders ?? 0}',
                  color: Colors.orange,
                ),
                _SummaryCard(
                  icon: Icons.event_repeat_outlined,
                  label: 'Preventivos',
                  value: '${stats?.activeSchedules ?? 0}',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SummaryCardsRow(
              cards: [
                _SummaryCard(
                  icon: Icons.pending_actions_outlined,
                  label: 'En Progreso',
                  value: '${stats?.inProgressWorkOrders ?? 0}',
                  color: Colors.amber,
                ),
                _SummaryCard(
                  icon: Icons.check_circle_outline,
                  label: 'Completados',
                  value: '${stats?.completedWorkOrders ?? 0}',
                  color: Colors.green,
                ),
                _SummaryCard(
                  icon: Icons.history_outlined,
                  label: 'Movimientos',
                  value: '${stats?.totalKardexLogs ?? 0}',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accesos Rápidos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_task),
                        label: const Text('Ver OTs'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {},
                        icon: const Icon(Icons.precision_manufacturing),
                        label: const Text('Ver Activos'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {},
                        icon: const Icon(Icons.history),
                        label: const Text('Ver Kardex'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardsRow extends StatelessWidget {
  const _SummaryCardsRow({required this.cards});

  final List<_SummaryCard> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cards.map((card) => Expanded(child: card)).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
