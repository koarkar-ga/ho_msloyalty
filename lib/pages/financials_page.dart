import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ms_dashboard/services/accounting_service.dart';

class FinancialsPage extends StatefulWidget {
  const FinancialsPage({super.key});

  @override
  State<FinancialsPage> createState() => _FinancialsPageState();
}

class _FinancialsPageState extends State<FinancialsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _jeFormKey = GlobalKey<FormState>();

  // Journal Entry Form State
  final TextEditingController _refNoController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  DateTime _postingDate = DateTime.now();
  
  List<Map<String, dynamic>> _jeLines = [
    {'account': '10100 - Cash on Hand', 'debit': 0.0, 'credit': 0.0},
    {'account': '40100 - Sales Revenue', 'debit': 0.0, 'credit': 0.0},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refNoController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  double get _totalDebit => _jeLines.fold(0.0, (sum, item) => sum + (item['debit'] as double));
  double get _totalCredit => _jeLines.fold(0.0, (sum, item) => sum + (item['credit'] as double));

  void _addJeLine() {
    setState(() {
      _jeLines.add({'account': '', 'debit': 0.0, 'credit': 0.0});
    });
  }

  void _removeJeLine(int index) {
    if (_jeLines.length > 2) {
      setState(() {
        _jeLines.removeAt(index);
      });
    }
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
                'Financials & Accounting',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: HOColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: HOColors.accent.withOpacity(0.3)),
                ),
                child: const Text(
                  'Double-Entry System',
                  style: TextStyle(color: HOColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tab Bar
          Card(
            color: HOColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: HOColors.accent,
                  labelColor: HOColors.accent,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(icon: Icon(Icons.account_tree_outlined), text: 'Chart of Accounts'),
                    Tab(icon: Icon(Icons.menu_book_outlined), text: 'Journal Entry'),
                    Tab(icon: Icon(Icons.analytics_outlined), text: 'Financial Reports'),
                  ],
                ),
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChartOfAccountsTab(),
                      _buildJournalEntryTab(isMobile),
                      _buildFinancialReportsTab(isMobile),
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

  // ─── Tab 1: Chart of Accounts ──────────────────────────────────────────────
  Widget _buildChartOfAccountsTab() {
    final accounting = Provider.of<HOAccountingService>(context);
    final coaList = accounting.chartOfAccounts;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView.builder(
        itemCount: coaList.length,
        itemBuilder: (context, index) {
          final cat = coaList[index];
          return ExpansionTile(
            title: Text(
              cat['category'],
              style: const TextStyle(fontWeight: FontWeight.bold, color: HOColors.accent),
            ),
            initiallyExpanded: true,
            children: (cat['accounts'] as List).map<Widget>((acc) {
              final double bal = acc['balance'] as double;
              return ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.white38),
                title: Text(
                  '${acc['code']} - ${acc['name']}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                trailing: Text(
                  '${NumberFormat('#,##0.00').format(bal)} Ks',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ─── Tab 2: Journal Entry Form ─────────────────────────────────────────────
  Widget _buildJournalEntryTab(bool isMobile) {
    final accounting = Provider.of<HOAccountingService>(context);
    
    // Flat list of dropdown items from all categories
    final List<DropdownMenuItem<String>> dropdownItems = [];
    for (var cat in accounting.chartOfAccounts) {
      final accounts = cat['accounts'] as List;
      for (var acc in accounts) {
        final codeName = '${acc['code']} - ${acc['name']}';
        dropdownItems.add(
          DropdownMenuItem(
            value: codeName,
            child: Text(codeName, style: const TextStyle(fontSize: 12)),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _jeFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header inputs
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: TextFormField(
                    controller: _refNoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Reference Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 300,
                  child: TextFormField(
                    controller: _memoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Memo/Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _postingDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _postingDate = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range_rounded, color: Colors.white70),
                  label: Text(
                    'Posting Date: ${DateFormat('dd MMM yyyy').format(_postingDate)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HOColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Lines Data Table Grid
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('Account Code & Name')),
                      DataColumn(label: Text('Debit (Ks)')),
                      DataColumn(label: Text('Credit (Ks)')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _jeLines.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final line = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(
                            DropdownButton<String>(
                              dropdownColor: HOColors.surface,
                              value: line['account'].toString().isEmpty ? null : line['account'].toString(),
                              hint: const Text('Select Account', style: TextStyle(color: Colors.white30)),
                              items: dropdownItems,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _jeLines[idx]['account'] = val);
                                }
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              initialValue: line['debit'] > 0.0 ? line['debit'].toString() : '',
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '0.00'),
                              onChanged: (val) {
                                setState(() {
                                  _jeLines[idx]['debit'] = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              initialValue: line['credit'] > 0.0 ? line['credit'].toString() : '',
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '0.00'),
                              onChanged: (val) {
                                setState(() {
                                  _jeLines[idx]['credit'] = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _removeJeLine(idx),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Footer / Total
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addJeLine,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Row'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Total Debit: ${NumberFormat('#,##0.00').format(_totalDebit)} Ks', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 24),
                    Text('Total Credit: ${NumberFormat('#,##0.00').format(_totalCredit)} Ks', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: (_totalDebit - _totalCredit).abs() < 0.01 && _totalDebit > 0 
                      ? () async {
                          final posted = await Provider.of<HOAccountingService>(context, listen: false).postJournalEntry(
                            refNo: _refNoController.text,
                            memo: _memoController.text,
                            postingDate: _postingDate,
                            lines: _jeLines,
                          );
                          if (posted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Journal Entry posted successfully!'), backgroundColor: Colors.green),
                            );
                            setState(() {
                              _refNoController.clear();
                              _memoController.clear();
                              _jeLines = [
                                {'account': '10100 - Cash on Hand', 'debit': 0.0, 'credit': 0.0},
                                {'account': '40100 - Sales Revenue', 'debit': 0.0, 'credit': 0.0},
                              ];
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to post Journal Entry. Verify balanced figures.'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Post Journal Entry', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HOColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 3: Financial Reports ──────────────────────────────────────────────
  Widget _buildFinancialReportsTab(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Statements',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _reportTypeCard(
                title: 'Profit & Loss Statement (P&L)',
                description: 'Summarizes revenues, costs, and expenses incurred during a specific period.',
                icon: Icons.account_balance_rounded,
                color: Colors.blueAccent,
              ),
              _reportTypeCard(
                title: 'Balance Sheet',
                description: 'Displays company assets, liabilities, and shareholders equity at a specific point in time.',
                icon: Icons.pie_chart_outline_rounded,
                color: Colors.tealAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HOColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Generating $title...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.2),
              foregroundColor: color,
              elevation: 0,
            ),
            child: const Text('Generate PDF/Excel'),
          ),
        ],
      ),
    );
  }
}
