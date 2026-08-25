import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth_permissions/presentation/viewmodels/auth_viewmodel.dart';
import '../../domain/entities/breakdown_report.dart';
import '../viewmodels/my_reports_viewmodel.dart';

class MyReportsView extends StatefulWidget {
  const MyReportsView({super.key});

  @override
  State<MyReportsView> createState() => _MyReportsViewState();
}

class _MyReportsViewState extends State<MyReportsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) context.read<MyReportsViewModel>().load(user.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _MyReportsContent();
  }
}

class _MyReportsContent extends StatelessWidget {
  const _MyReportsContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MyReportsViewModel>();

    return switch (vm.viewState) {
      MyReportsViewState.initial ||
      MyReportsViewState.loading =>
        const Center(child: CircularProgressIndicator()),
      MyReportsViewState.error => Center(
          child: Text('Error: ${vm.errorMessage}'),
        ),
      MyReportsViewState.success => RefreshIndicator(
          onRefresh: () async {
            final user = context.read<AuthViewModel>().currentUser;
            if (user != null) vm.load(user.userId);
          },
          child: vm.reports.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.fact_check_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Aún no has reportado averías.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: vm.reports.length,
                  itemBuilder: (context, index) =>
                      _ReportTile(report: vm.reports[index]),
                ),
        ),
    };
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final BreakdownReport report;

  @override
  Widget build(BuildContext context) {
    final (sevColor, sevBg, sevLabel) = switch (report.severity) {
      BreakdownSeverity.low => (const Color(0xFF15803D), const Color(0xFFDCFCE7), 'Baja'),
      BreakdownSeverity.medium => (const Color(0xFFB45309), const Color(0xFFFEF3C7), 'Media'),
      BreakdownSeverity.high => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), 'Alta'),
    };

    final (statusColor, statusBg, statusLabel, statusIcon) = switch (report.status) {
      BreakdownReportStatus.reported => (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          'En Revisión',
          Icons.error_outline,
        ),
      BreakdownReportStatus.inWorkOrder => (
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          'OT Asignada ${report.workOrderId ?? ""}'.trim(),
          Icons.engineering_outlined,
        ),
      BreakdownReportStatus.resolved => (
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
          'Resuelta',
          Icons.check_circle_outline,
        ),
      BreakdownReportStatus.rejected => (
          const Color(0xFF64748B),
          const Color(0xFFF1F5F9),
          'Rechazada',
          Icons.block_outlined,
        ),
    };

    final dateStr = report.reportedAt != null
        ? '${report.reportedAt!.day}/${report.reportedAt!.month}/${report.reportedAt!.year} '
            '${report.reportedAt!.hour.toString().padLeft(2, '0')}:'
            '${report.reportedAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: sevBg,
                  child: Icon(
                    Icons.precision_manufacturing_outlined,
                    color: sevColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              report.assetId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              report.assetName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Área ${report.areaId}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                report.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
            if (report.status == BreakdownReportStatus.rejected) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  'Motivo de rechazo: ${report.rejectionReason ?? "—"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                if (report.workOrderId != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      'OT: ${report.workOrderId}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
