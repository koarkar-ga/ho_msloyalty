import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ms_dashboard/services/accounting_service.dart';

class SalesPurchasesPage extends StatefulWidget {
  const SalesPurchasesPage({super.key});

  @override
  State<SalesPurchasesPage> createState() => _SalesPurchasesPageState();
}

class _SalesPurchasesPageState extends State<SalesPurchasesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _salesFormKey = GlobalKey<FormState>();
  final _purchaseFormKey = GlobalKey<FormState>();

  // State for Sales AR
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _salesMemoController = TextEditingController();
  String _salesDocType = 'Quotation'; // Quotation, Sales Order, Delivery, A/R Invoice
  DateTime _salesDate = DateTime.now();
  List<Map<String, dynamic>> _salesItems = [
    {'itemCode': 'ITM-001', 'desc': 'Octane 92 Premium Fuel', 'qty': 1000.0, 'price': 2250.0, 'tax': 5.0},
    {'itemCode': 'ITM-002', 'desc': 'Diesel High-Speed', 'qty': 500.0, 'price': 2400.0, 'tax': 5.0},
  ];

  // State for Purchasing AP
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _purchaseMemoController = TextEditingController();
  String _purchaseDocType = 'Purchase Order'; // Purchase Order, Goods Receipt PO, A/P Invoice
  DateTime _purchaseDate = DateTime.now();
  List<Map<String, dynamic>> _purchaseItems = [
    {'itemCode': 'ITM-003', 'desc': 'Engine Oil Super 1L', 'qty': 50.0, 'price': 12000.0, 'tax': 5.0},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerController.dispose();
    _salesMemoController.dispose();
    _vendorController.dispose();
    _purchaseMemoController.dispose();
    super.dispose();
  }

  // Calculations for Sales
  double get _salesSubtotal => _salesItems.fold(0.0, (sum, item) {
    final double qty = (item['qty'] as num).toDouble();
    final double price = (item['price'] as num).toDouble();
    return sum + (qty * price);
  });

  double get _salesTaxTotal => _salesItems.fold(0.0, (sum, item) {
    final double qty = (item['qty'] as num).toDouble();
    final double price = (item['price'] as num).toDouble();
    final double taxPct = (item['tax'] as num).toDouble();
    return sum + (qty * price * (taxPct / 100));
  });

  double get _salesTotal => _salesSubtotal + _salesTaxTotal;

  // Calculations for Purchasing
  double get _purchaseSubtotal => _purchaseItems.fold(0.0, (sum, item) {
    final double qty = (item['qty'] as num).toDouble();
    final double price = (item['price'] as num).toDouble();
    return sum + (qty * price);
  });

  double get _purchaseTaxTotal => _purchaseItems.fold(0.0, (sum, item) {
    final double qty = (item['qty'] as num).toDouble();
    final double price = (item['price'] as num).toDouble();
    final double taxPct = (item['tax'] as num).toDouble();
    return sum + (qty * price * (taxPct / 100));
  });

  double get _purchaseTotal => _purchaseSubtotal + _purchaseTaxTotal;

  void _addSalesItem() {
    setState(() {
      _salesItems.add({'itemCode': '', 'desc': '', 'qty': 0.0, 'price': 0.0, 'tax': 5.0});
    });
  }

  void _removeSalesItem(int index) {
    if (_salesItems.length > 1) {
      setState(() {
        _salesItems.removeAt(index);
      });
    }
  }

  void _addPurchaseItem() {
    setState(() {
      _purchaseItems.add({'itemCode': '', 'desc': '', 'qty': 0.0, 'price': 0.0, 'tax': 5.0});
    });
  }

  void _removePurchaseItem(int index) {
    if (_purchaseItems.length > 1) {
      setState(() {
        _purchaseItems.removeAt(index);
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
                'Sales & Purchasing',
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
                  'Sales A/R & Purchasing A/P',
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
                    Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Sales (A/R)'),
                    Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Purchasing (A/P)'),
                    Tab(icon: Icon(Icons.alt_route_outlined), text: 'Workflow Diagram'),
                  ],
                ),
                SizedBox(
                  height: 650,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSalesTab(isMobile),
                      _buildPurchasingTab(isMobile),
                      _buildWorkflowTab(),
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

  // ─── Tab 1: Sales A/R ──────────────────────────────────────────────────────
  Widget _buildSalesTab(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _salesFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: DropdownButtonFormField<String>(
                    dropdownColor: HOColors.surface,
                    value: _salesDocType,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Document Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Quotation', child: Text('Quotation')),
                      DropdownMenuItem(value: 'Sales Order', child: Text('Sales Order')),
                      DropdownMenuItem(value: 'Delivery', child: Text('Delivery (GD)')),
                      DropdownMenuItem(value: 'A/R Invoice', child: Text('A/R Invoice')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _salesDocType = val);
                    },
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: TextFormField(
                    controller: _customerController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Customer (BP Name)',
                      prefixIcon: Icon(Icons.person_outline, color: Colors.white54),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Customer required' : null,
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: TextFormField(
                    controller: _salesMemoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Reference',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _salesDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _salesDate = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range_rounded, color: Colors.white70),
                  label: Text(
                    'Doc Date: ${DateFormat('dd MMM yyyy').format(_salesDate)}',
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

            // Item Lines Grid
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    columnSpacing: 12,
                    columns: const [
                      DataColumn(label: Text('Item Code / Description')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Price (Ks)')),
                      DataColumn(label: Text('Tax %')),
                      DataColumn(label: Text('Line Total (Ks)')),
                      DataColumn(label: Text('')),
                    ],
                    rows: _salesItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final line = entry.value;
                      final double qty = (line['qty'] as num).toDouble();
                      final double price = (line['price'] as num).toDouble();
                      final double tax = (line['tax'] as num).toDouble();
                      final double lineTotal = qty * price * (1 + tax / 100);

                      return DataRow(
                        cells: [
                          DataCell(
                            DropdownButton<String>(
                              dropdownColor: HOColors.surface,
                              value: line['itemCode'].toString().isEmpty ? null : line['itemCode'].toString(),
                              hint: const Text('Select Item', style: TextStyle(color: Colors.white30)),
                              items: const [
                                DropdownMenuItem(value: 'ITM-001', child: Text('ITM-001 | Octane 92')),
                                DropdownMenuItem(value: 'ITM-002', child: Text('ITM-002 | Diesel HSD')),
                                DropdownMenuItem(value: 'ITM-003', child: Text('ITM-003 | Engine Oil')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  String desc = '';
                                  double price = 0.0;
                                  if (val == 'ITM-001') {
                                    desc = 'Octane 92 Premium Fuel';
                                    price = 2250.0;
                                  } else if (val == 'ITM-002') {
                                    desc = 'Diesel High-Speed';
                                    price = 2400.0;
                                  } else if (val == 'ITM-003') {
                                    desc = 'Engine Oil Super 1L';
                                    price = 12000.0;
                                  }
                                  setState(() {
                                    _salesItems[idx]['itemCode'] = val;
                                    _salesItems[idx]['desc'] = desc;
                                    _salesItems[idx]['price'] = price;
                                  });
                                }
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              initialValue: qty > 0.0 ? qty.toString() : '',
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '0.0'),
                              onChanged: (val) {
                                setState(() {
                                  _salesItems[idx]['qty'] = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              controller: TextEditingController(text: price > 0.0 ? price.toString() : '')..selection = TextSelection.fromPosition(TextPosition(offset: (price > 0.0 ? price.toString() : '').length)),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '0.00'),
                              onChanged: (val) {
                                setState(() {
                                  _salesItems[idx]['price'] = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              initialValue: tax.toString(),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '5%'),
                              onChanged: (val) {
                                setState(() {
                                  _salesItems[idx]['tax'] = double.tryParse(val) ?? 5.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberFormat('#,##0.00').format(lineTotal),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _removeSalesItem(idx),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Footer
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _addSalesItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item Line'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Subtotal: ${NumberFormat('#,##0.00').format(_salesSubtotal)} Ks', style: const TextStyle(color: Colors.white60)),
                    Text('Tax (Commercial): ${NumberFormat('#,##0.00').format(_salesTaxTotal)} Ks', style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 4),
                    Text('Total: ${NumberFormat('#,##0.00').format(_salesTotal)} Ks', style: const TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_salesFormKey.currentState!.validate()) {
                      await Provider.of<HOAccountingService>(context, listen: false).postSalesDoc(
                        docType: _salesDocType,
                        customer: _customerController.text,
                        memo: _salesMemoController.text,
                        date: _salesDate,
                        items: _salesItems,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$_salesDocType posted successfully!'), backgroundColor: Colors.green),
                      );
                      setState(() {
                        _customerController.clear();
                        _salesMemoController.clear();
                        _salesItems = [
                          {'itemCode': 'ITM-001', 'desc': 'Octane 92 Premium Fuel', 'qty': 1000.0, 'price': 2250.0, 'tax': 5.0},
                          {'itemCode': 'ITM-002', 'desc': 'Diesel High-Speed', 'qty': 500.0, 'price': 2400.0, 'tax': 5.0},
                        ];
                      });
                    }
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text('Post $_salesDocType', style: const TextStyle(color: Colors.white)),
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

  // ─── Tab 2: Purchasing A/P ─────────────────────────────────────────────────
  Widget _buildPurchasingTab(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _purchaseFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: DropdownButtonFormField<String>(
                    dropdownColor: HOColors.surface,
                    value: _purchaseDocType,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Document Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Purchase Order', child: Text('Purchase Order (PO)')),
                      DropdownMenuItem(value: 'Goods Receipt PO', child: Text('Goods Receipt (GRPO)')),
                      DropdownMenuItem(value: 'A/P Invoice', child: Text('A/P Invoice')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _purchaseDocType = val);
                    },
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: TextFormField(
                    controller: _vendorController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Vendor (Supplier BP)',
                      prefixIcon: Icon(Icons.storefront_outlined, color: Colors.white54),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Vendor required' : null,
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: TextFormField(
                    controller: _purchaseMemoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Reference',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _purchaseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _purchaseDate = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range_rounded, color: Colors.white70),
                  label: Text(
                    'Doc Date: ${DateFormat('dd MMM yyyy').format(_purchaseDate)}',
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

            // Item Lines Grid
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    columnSpacing: 12,
                    columns: const [
                      DataColumn(label: Text('Item Code / Description')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Price (Ks)')),
                      DataColumn(label: Text('Tax %')),
                      DataColumn(label: Text('Line Total (Ks)')),
                      DataColumn(label: Text('')),
                    ],
                    rows: _purchaseItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final line = entry.value;
                      final double qty = (line['qty'] as num).toDouble();
                      final double price = (line['price'] as num).toDouble();
                      final double tax = (line['tax'] as num).toDouble();
                      final double lineTotal = qty * price * (1 + tax / 100);

                      return DataRow(
                        cells: [
                          DataCell(
                            DropdownButton<String>(
                              dropdownColor: HOColors.surface,
                              value: line['itemCode'].toString().isEmpty ? null : line['itemCode'].toString(),
                              hint: const Text('Select Item', style: TextStyle(color: Colors.white30)),
                              items: const [
                                DropdownMenuItem(value: 'ITM-001', child: Text('ITM-001 | Octane 92')),
                                DropdownMenuItem(value: 'ITM-002', child: Text('ITM-002 | Diesel HSD')),
                                DropdownMenuItem(value: 'ITM-003', child: Text('ITM-003 | Engine Oil')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  String desc = '';
                                  double price = 0.0;
                                  if (val == 'ITM-001') {
                                    desc = 'Octane 92 Premium Fuel';
                                    price = 2200.0;
                                  } else if (val == 'ITM-002') {
                                    desc = 'Diesel High-Speed';
                                    price = 2350.0;
                                  } else if (val == 'ITM-003') {
                                    desc = 'Engine Oil Super 1L';
                                    price = 11000.0;
                                  }
                                  setState(() {
                                    _purchaseItems[idx]['itemCode'] = val;
                                    _purchaseItems[idx]['desc'] = desc;
                                    _purchaseItems[idx]['price'] = price;
                                  });
                                }
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              initialValue: qty > 0.0 ? qty.toString() : '',
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '0.0'),
                              onChanged: (val) {
                                setState(() {
                                  _purchaseItems[idx]['qty'] = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              controller: TextEditingController(text: price > 0.0 ? price.toString() : '')..selection = TextSelection.fromPosition(TextPosition(offset: (price > 0.0 ? price.toString() : '').length)),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '0.00'),
                              onChanged: (val) {
                                setState(() {
                                  _purchaseItems[idx]['price'] = double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            TextFormField(
                              initialValue: tax.toString(),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: '5%'),
                              onChanged: (val) {
                                setState(() {
                                  _purchaseItems[idx]['tax'] = double.tryParse(val) ?? 5.0;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberFormat('#,##0.00').format(lineTotal),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _removePurchaseItem(idx),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Footer
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _addPurchaseItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item Line'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Subtotal: ${NumberFormat('#,##0.00').format(_purchaseSubtotal)} Ks', style: const TextStyle(color: Colors.white60)),
                    Text('Tax (Commercial): ${NumberFormat('#,##0.00').format(_purchaseTaxTotal)} Ks', style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 4),
                    Text('Total: ${NumberFormat('#,##0.00').format(_purchaseTotal)} Ks', style: const TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_purchaseFormKey.currentState!.validate()) {
                      await Provider.of<HOAccountingService>(context, listen: false).postPurchaseDoc(
                        docType: _purchaseDocType,
                        vendor: _vendorController.text,
                        memo: _purchaseMemoController.text,
                        date: _purchaseDate,
                        items: _purchaseItems,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$_purchaseDocType posted successfully!'), backgroundColor: Colors.green),
                      );
                      setState(() {
                        _vendorController.clear();
                        _purchaseMemoController.clear();
                        _purchaseItems = [
                          {'itemCode': 'ITM-003', 'desc': 'Engine Oil Super 1L', 'qty': 50.0, 'price': 12000.0, 'tax': 5.0},
                        ];
                      });
                    }
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text('Post $_purchaseDocType', style: const TextStyle(color: Colors.white)),
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

  // ─── Tab 3: Workflow Diagram ────────────────────────────────────────────────
  Widget _buildWorkflowTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SAP B1 Document Relationship Flow (Sales / Purchase)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _workflowStepCard(
                    title: '1. Quotation / Request',
                    subtitle: 'Sales Quotation (SQ)\nPurchase Request (PR)',
                    icon: Icons.description_outlined,
                    color: Colors.blueAccent,
                  ),
                  _workflowArrow(),
                  _workflowStepCard(
                    title: '2. Order Confirmation',
                    subtitle: 'Sales Order (SO)\nPurchase Order (PO)',
                    icon: Icons.confirmation_number_outlined,
                    color: Colors.orangeAccent,
                  ),
                  _workflowArrow(),
                  _workflowStepCard(
                    title: '3. Inventory Delivery',
                    subtitle: 'Delivery Document (GD)\nGoods Receipt PO (GRPO)',
                    icon: Icons.local_shipping_outlined,
                    color: Colors.purpleAccent,
                  ),
                  _workflowArrow(),
                  _workflowStepCard(
                    title: '4. Invoice Posting',
                    subtitle: 'A/R Invoice (Sales Billing)\nA/P Invoice (Vendor Invoice)',
                    icon: Icons.receipt_long_outlined,
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workflowStepCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HOColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _workflowArrow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(
        children: [
          Icon(Icons.arrow_forward, color: Colors.white24, size: 24),
        ],
      ),
    );
  }
}
