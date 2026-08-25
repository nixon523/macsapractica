import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macsapractica/app/screens/sidebar_widget.dart';

Widget _host({required bool expanded, required List<SidebarItem> items, int selected = 0}) {
  return MaterialApp(
    home: Scaffold(
      body: Row(
        children: [
          SidebarWidget(
            items: items,
            selectedIndex: selected,
            onTap: (_) {},
            isExpanded: expanded,
            onToggle: () {},
            userName: 'admin',
            userDisplayName: 'Administrador General',
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    ),
  );
}

void main() {
  final items = [
    const SidebarItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard'),
    const SidebarItem(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'Órdenes de Trabajo',
        badgeCount: 3),
    const SidebarItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'Kardex / Historial'),
  ];

  testWidgets('sidebar colapsado sin insignias no desborda', (tester) async {
    await tester.pumpWidget(_host(expanded: false, items: items, selected: 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar colapsado con insignia y seleccionado no desborda',
      (tester) async {
    await tester.pumpWidget(_host(expanded: false, items: items, selected: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar expandido no desborda', (tester) async {
    await tester.pumpWidget(_host(expanded: true, items: items, selected: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('diagnostico: colapsado sin items', (tester) async {
    await tester.pumpWidget(_host(expanded: false, items: const [], selected: 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('diagnostico: expandido sin items', (tester) async {
    await tester.pumpWidget(_host(expanded: true, items: const [], selected: 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
