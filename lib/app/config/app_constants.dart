class AppConstants {
  const AppConstants._();

  static const String appName = 'Grupo Macsa';
  static const String appTitle = 'Sistema de Gestión de Mantenimiento de Activos';

  static const List<String> firestoreCollections = [
    'areas',
    'counters',
    'assets',
    'work_orders',
    'kardex_logs',
    'users',
  ];
}
