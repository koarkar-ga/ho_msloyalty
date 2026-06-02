import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/accounting_service.dart';

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  State<InventoryManagementPage> createState() => _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Inventory state and transfers are powered by HOAccountingService via Provider.

  // State for Serial/Batch Tracking Simulator
  final TextEditingController _barcodeController = TextEditingController();
  final List<Map<String, dynamic>> _trackingLogs = [
    {
      'timestamp': '31 May 2026 14:20',
      'barcode': 'BCH-OCT92-05A',
      'item': 'ITM-001 - Octane 92',
      'details': 'Batch created. Mfg: 10 May 2026 | Exp: 10 May 2028',
      'status': 'Passed Inspection',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _simulateTransfer() {
    showDialog(
      context: context,
      builder: (context) {
        String fromWh = 'HO Central WH';
        String toWh = 'Bayintnaung Station WH';
        String selectedItem = 'ITM-001';
        final qtyController = TextEditingController();

        return AlertDialog(
          backgroundColor: HOColors.surface,
          title: const Text('Simulate Warehouse Transfer', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  dropdownColor: HOColors.surface,
                  value: fromWh,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'From Warehouse'),
                  items: const [
                    DropdownMenuItem(value: 'HO Central WH', child: Text('HO Central WH')),
                    DropdownMenuItem(value: 'Bayintnaung Station WH', child: Text('Bayintnaung Station WH')),
                  ],
                  onChanged: (val) => fromWh = val!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: HOColors.surface,
                  value: toWh,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'To Warehouse'),
                  items: const [
                    DropdownMenuItem(value: 'HO Central WH', child: Text('HO Central WH')),
                    DropdownMenuItem(value: 'Bayintnaung Station WH', child: Text('Bayintnaung Station WH')),
                    DropdownMenuItem(value: 'Hlaing Tharyar Station WH', child: Text('Hlaing Tharyar Station WH')),
                  ],
                  onChanged: (val) => toWh = val!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: HOColors.surface,
                  value: selectedItem,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Item to Transfer'),
                  items: const [
                    DropdownMenuItem(value: 'ITM-001', child: Text('ITM-001 - Octane 92 Premium Fuel')),
                    DropdownMenuItem(value: 'ITM-002', child: Text('ITM-002 - Diesel High-Speed')),
                    DropdownMenuItem(value: 'ITM-003', child: Text('ITM-003 - Engine Oil Super 1L')),
                  ],
                  onChanged: (val) => selectedItem = val!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final double qty = double.tryParse(qtyController.text) ?? 0.0;
                if (qty > 0) {
                  Provider.of<HOAccountingService>(context, listen: false).createStockTransfer(
                    from: fromWh,
                    to: toWh,
                    itemCode: selectedItem,
                    qty: qty,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock Transfer posted successfully!'), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent),
              child: const Text('Transfer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _simulateScan() {
    if (_barcodeController.text.isEmpty) return;
    String code = _barcodeController.text;
    String matchedItem = 'Unknown Item';
    String details = '';

    if (code.toUpperCase().contains('OCT92')) {
      matchedItem = 'ITM-001 - Octane 92';
      details = 'Batch verified. Grade A Premium Octane. Expiry: 12 Months';
    } else if (code.toUpperCase().contains('DSL')) {
      matchedItem = 'ITM-002 - Diesel High-Speed';
      details = 'Batch verified. High sulfur compliance. Expiry: 24 Months';
    } else if (code.toUpperCase().contains('OIL')) {
      matchedItem = 'ITM-003 - Engine Oil Super';
      details = 'Serial verified. QR match. Original Shell batch.';
    } else {
      matchedItem = 'Generic Warehouse Asset';
      details = 'Asset code registered. Location: Rack-C4';
    }

    setState(() {
      _trackingLogs.insert(0, {
        'timestamp': 'Just Now',
        'barcode': code,
        'item': matchedItem,
        'details': details,
        'status': 'Verified',
      });
      _barcodeController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scanned code: $code (Matched: $matchedItem)'), backgroundColor: HOColors.accent),
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
                'Inventory & Warehouse',
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
                  'Item & Warehouse Management',
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
                    Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Item Master Data'),
                    Tab(icon: Icon(Icons.swap_horiz_outlined), text: 'Stock Transfers'),
                    Tab(icon: Icon(Icons.qr_code_scanner_outlined), text: 'Serial / Batch Tracking'),
                  ],
                ),
                SizedBox(
                  height: 650,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildItemMasterTab(isMobile),
                      _buildStockTransfersTab(isMobile),
                      _buildSerialTrackingTab(isMobile),
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

  // ─── Tab 1: Item Master Data ───────────────────────────────────────────────
  Widget _buildItemMasterTab(bool isMobile) {
    final accounting = Provider.of<HOAccountingService>(context);
    final catalog = accounting.inventoryItems;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SAP B1 Inventory Catalogue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Syncing items from SAP B1...')),
                  );
                },
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync SAP B1'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              itemCount: catalog.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final item = catalog[index];
                final double available = item['inStock'] - item['committed'] + item['ordered'];
                final bool lowStock = item['inStock'] <= item['minStock'];
                final String uom = (item['code'] == 'ITM-003' || item['code'] == 'ITM-004') ? 'Bottles' : 'Liters';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HOColors.background.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: lowStock ? Colors.redAccent.withOpacity(0.3) : Colors.white10,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['code'],
                                style: const TextStyle(fontWeight: FontWeight.bold, color: HOColors.accent, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['name'],
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['group'],
                              style: const TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _stockMetric('In Stock', '${item['inStock']} $uom', lowStock ? Colors.redAccent : Colors.white),
                          _stockMetric('Committed', '${item['committed']} $uom', Colors.white70),
                          _stockMetric('Ordered', '${item['ordered']} $uom', Colors.white70),
                          _stockMetric('Available', '$available $uom', Colors.greenAccent),
                        ],
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

  Widget _stockMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  // ─── Tab 2: Stock Transfers ────────────────────────────────────────────────
  Widget _buildStockTransfersTab(bool isMobile) {
    final accounting = Provider.of<HOAccountingService>(context);
    final transfers = accounting.stockTransfers;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Warehouse Stock Transfers (GD/Inventory Transfer)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: _simulateTransfer,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Transfer'),
                style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: transfers.length,
              itemBuilder: (context, index) {
                final tf = transfers[index];
                final isTransit = tf['status'] == 'In Transit';
                final docNum = tf['id'] ?? tf['docNum'] ?? '';
                final fromWh = tf['from'] ?? tf['fromWh'] ?? '';
                final toWh = tf['to'] ?? tf['toWh'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HOColors.background.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isTransit ? Colors.orangeAccent.withOpacity(0.15) : Colors.greenAccent.withOpacity(0.15),
                        child: Icon(
                          isTransit ? Icons.local_shipping_outlined : Icons.done_all_outlined,
                          color: isTransit ? Colors.orangeAccent : Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$docNum | ${tf['date']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'From: $fromWh  ➔  To: $toWh',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Item: ${tf['item']} | Quantity: ${tf['qty']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTransit ? Colors.orangeAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isTransit ? Colors.orangeAccent.withOpacity(0.3) : Colors.greenAccent.withOpacity(0.3)),
                        ),
                        child: Text(
                          tf['status'],
                          style: TextStyle(
                            color: isTransit ? Colors.orangeAccent : Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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

  // ─── Tab 3: Serial / Batch Tracking ────────────────────────────────────────
  Widget _buildSerialTrackingTab(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batch & Serial Tracking (Quality Control)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _barcodeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Scan Barcode or Enter Batch Code',
                    hintText: 'e.g. BCH-OCT92-05A, BCH-DSL-12C, BCH-OIL-09',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: Colors.white54),
                  ),
                  onFieldSubmitted: (_) => _simulateScan(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _simulateScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
                ),
                child: const Text('Verify Batch', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Verification Logs & Audit Feed',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _trackingLogs.length,
              itemBuilder: (context, index) {
                final log = _trackingLogs[index];
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
                      const Icon(Icons.assignment_turned_in_outlined, color: Colors.tealAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Barcode: ${log['barcode']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  log['timestamp'],
                                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Item: ${log['item']}',
                              style: const TextStyle(color: HOColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log['details'],
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
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
