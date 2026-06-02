import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/accounting_service.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Pending requests and audit trail state are powered by HOAccountingService via Provider.

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleDecision(int index, Map<String, dynamic> req, String action) {
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HOColors.surface,
          title: Text(
            '$action Approval Request',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Document: ${req['id']} - ${req['title']}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: remarksController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Remarks / Comments',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<HOAccountingService>(
                  context,
                  listen: false,
                ).handleApprovalDecision(index, action, remarksController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Request ${req['id']} has been ${action}d.'),
                    backgroundColor: action == 'Approve'
                        ? Colors.green
                        : Colors.redAccent,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'Approve'
                    ? Colors.green
                    : Colors.redAccent,
              ),
              child: Text(action, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 950;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Approvals & Workflows',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: HOColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: HOColors.accent.withOpacity(0.3)),
                ),
                child: const Text(
                  'Authorization Desk',
                  style: TextStyle(
                    color: HOColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tab Bar
          Card(
            color: HOColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: HOColors.accent,
                  labelColor: HOColors.accent,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.pending_actions_outlined),
                      text: 'Pending Requests',
                    ),
                    Tab(
                      icon: Icon(Icons.dashboard_customize_outlined),
                      text: 'Approval Metrics',
                    ),
                    Tab(
                      icon: Icon(Icons.history_outlined),
                      text: 'Audit Trail',
                    ),
                  ],
                ),
                SizedBox(
                  height: 650,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingTab(isMobile),
                      _buildMetricsTab(isMobile),
                      _buildAuditTrailTab(isMobile),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 1: Pending Approvals ──────────────────────────────────────────────
  Widget _buildPendingTab(bool isMobile) {
    final accounting = Provider.of<HOAccountingService>(context);
    final pending = accounting.pendingRequests;

    if (pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'All Caught Up!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'There are no pending documents waiting for your approval.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView.builder(
        itemCount: pending.length,
        itemBuilder: (context, index) {
          final req = pending[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HOColors.background.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req['id'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HOColors.accent,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          req['title'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      req['amount'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Requestor: ${req['requestor']}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Date: ${req['date']}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reason: ${req['reason']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Divider(height: 24, color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _handleDecision(index, req, 'Reject'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _handleDecision(index, req, 'Approve'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Tab 2: Approval Metrics ───────────────────────────────────────────────
  Widget _buildMetricsTab(bool isMobile) {
    final accounting = Provider.of<HOAccountingService>(context);
    final double cardWidth = isMobile ? double.infinity : 220;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Month Statistics (SAP Approvals)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _metricCard(
                title: 'Pending Decisions',
                value: accounting.pendingRequests.length.toString(),
                icon: Icons.pending_actions_outlined,
                color: Colors.orangeAccent,
                width: cardWidth,
              ),
              _metricCard(
                title: 'Approved Docs',
                value: accounting.approvedCount.toString(),
                icon: Icons.check_circle_outline,
                color: Colors.green,
                width: cardWidth,
              ),
              _metricCard(
                title: 'Rejected Docs',
                value: accounting.rejectedCount.toString(),
                icon: Icons.cancel_outlined,
                color: Colors.redAccent,
                width: cardWidth,
              ),
              _metricCard(
                title: 'Avg. Decision Time',
                value: '4.2 Hours',
                icon: Icons.speed_outlined,
                color: Colors.tealAccent,
                width: cardWidth,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Top Approval Decision Thresholds',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _thresholdRow(
                  'Purchase Orders Above 50M Ks',
                  'Level 2 Authorization (Systems Admin)',
                  true,
                ),
                _thresholdRow(
                  'A/R Invoice Credit Exception',
                  'Level 1 Authorization (Finance Director)',
                  true,
                ),
                _thresholdRow(
                  'Direct Journal Entries',
                  'Level 2 Authorization (Systems Admin)',
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HOColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thresholdRow(String name, String route, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                route,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? Colors.green.withOpacity(0.1) : Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              active ? 'Active Rule' : 'Inactive',
              style: TextStyle(
                color: active ? Colors.green : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Audit Trail ────────────────────────────────────────────────────
  Widget _buildAuditTrailTab(bool isMobile) {
    final accounting = Provider.of<HOAccountingService>(context);
    final history = accounting.historyLogs;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Authorization Audit Log Feed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final log = history[index];
                final isApprove = log['action'] == 'Approved';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isApprove
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: isApprove ? Colors.green : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${log['id']} - ${log['title']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  log['date'],
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Action: ${log['action']} by ${log['approver']}',
                              style: TextStyle(
                                color: isApprove
                                    ? Colors.green
                                    : Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Remarks: ${log['remarks']}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
