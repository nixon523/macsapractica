class DashboardStats {
  const DashboardStats({
    required this.totalAssets,
    required this.pendingWorkOrders,
    required this.inProgressWorkOrders,
    required this.completedWorkOrders,
    required this.activeSchedules,
    required this.totalKardexLogs,
  });

  final int totalAssets;
  final int pendingWorkOrders;
  final int inProgressWorkOrders;
  final int completedWorkOrders;
  final int activeSchedules;
  final int totalKardexLogs;
}
