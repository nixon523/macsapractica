class DashboardStats {
  const DashboardStats({
    required this.totalAssets,
    required this.pendingWorkOrders,
    required this.inProgressWorkOrders,
    required this.completedWorkOrders,
    required this.activeSchedules,
    required this.totalKardexLogs,
    this.openBreakdowns = 0,
    this.urgentSchedules = 0,
    this.overdueSchedules = 0,
    this.pmComplianceRate = 100.0,
  });

  final int totalAssets;
  final int pendingWorkOrders;
  final int inProgressWorkOrders;
  final int completedWorkOrders;
  final int activeSchedules;
  final int totalKardexLogs;
  final int openBreakdowns;
  final int urgentSchedules;
  final int overdueSchedules;
  final double pmComplianceRate;
}

