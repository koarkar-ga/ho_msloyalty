import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HOAccountingService extends ChangeNotifier {
  // Singleton pattern
  static final HOAccountingService _instance = HOAccountingService._internal();
  factory HOAccountingService() => _instance;
  
  final _supabase = Supabase.instance.client;

  HOAccountingService._internal() {
    fetchInitialData();
  }

  // ─── Chart of Accounts State ──────────────────────────────────────────────
  List<Map<String, dynamic>> _chartOfAccounts = [];
  List<Map<String, dynamic>> get chartOfAccounts => _chartOfAccounts;

  // ─── Posted Journal Entries ───────────────────────────────────────────────
  List<Map<String, dynamic>> _journalEntries = [];
  List<Map<String, dynamic>> get journalEntries => _journalEntries;

  // ─── Inventory Catalog State ──────────────────────────────────────────────
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> get inventoryItems => _inventoryItems;

  // Stock Transfer Logs
  List<Map<String, dynamic>> _stockTransfers = [];
  List<Map<String, dynamic>> get stockTransfers => _stockTransfers;

  // ─── Approvals System State ───────────────────────────────────────────────
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;

  List<Map<String, dynamic>> _historyLogs = [];
  List<Map<String, dynamic>> get historyLogs => _historyLogs;

  int approvedCount = 0;
  int rejectedCount = 0;

  // ─── Fetch All Data from Supabase ─────────────────────────────────────────
  Future<void> fetchInitialData() async {
    try {
      // 1. Fetch GL Accounts
      final accountsData = await _supabase
          .from('gl_accounts')
          .select()
          .order('code', ascending: true);

      final Map<String, List<Map<String, dynamic>>> grouped = {
        'Assets': [],
        'Liabilities': [],
        'Equity': [],
        'Revenue': [],
        'Expenses': [],
      };

      for (var row in accountsData) {
        final category = row['category'] as String;
        if (grouped.containsKey(category)) {
          grouped[category]!.add({
            'code': row['code'],
            'name': row['name'],
            'type': row['type'] ?? 'Active',
            'balance': (row['balance'] as num).toDouble(),
          });
        }
      }

      _chartOfAccounts = grouped.entries.map((e) => {
        'category': e.key,
        'accounts': e.value,
      }).toList();

      // 2. Fetch Journal Entries & Lines
      final entriesData = await _supabase
          .from('journal_entries')
          .select('*, journal_lines(*)')
          .order('created_at', ascending: false);

      _journalEntries = [];
      for (var entry in entriesData) {
        final List linesRaw = entry['journal_lines'] as List;
        final List<Map<String, dynamic>> lines = [];
        for (var line in linesRaw) {
          final code = line['account_code'] as String;
          String accountStr = code;
          for (var row in accountsData) {
            if (row['code'] == code) {
              accountStr = '$code - ${row['name']}';
              break;
            }
          }
          lines.add({
            'account': accountStr,
            'debit': (line['debit'] as num).toDouble(),
            'credit': (line['credit'] as num).toDouble(),
          });
        }

        _journalEntries.add({
          'refNo': entry['ref_no'],
          'memo': entry['memo'] ?? '',
          'postingDate': DateTime.parse(entry['posting_date'] as String),
          'amount': (entry['amount'] as num).toDouble(),
          'lines': lines,
        });
      }

      // 3. Fetch Inventory Items
      final itemsData = await _supabase
          .from('inventory_items')
          .select()
          .order('code', ascending: true);

      _inventoryItems = itemsData.map((e) => {
        'code': e['code'],
        'name': e['name'],
        'group': e['group'],
        'inStock': (e['in_stock'] as num).toDouble(),
        'committed': (e['committed'] as num).toDouble(),
        'ordered': (e['ordered'] as num).toDouble(),
        'minStock': (e['min_stock'] as num).toDouble(),
        'cost': (e['cost'] as num).toDouble(),
      }).toList();

      // 4. Fetch Stock Transfers
      final transfersData = await _supabase
          .from('stock_transfers')
          .select()
          .order('created_at', ascending: false);

      _stockTransfers = [];
      for (var tf in transfersData) {
        final itemCode = tf['item_code'] as String;
        String itemName = itemCode;
        for (var item in itemsData) {
          if (item['code'] == itemCode) {
            itemName = item['name'] as String;
            break;
          }
        }

        _stockTransfers.add({
          'id': tf['id'],
          'date': tf['date'],
          'from': tf['from_wh'],
          'to': tf['to_wh'],
          'item': itemName,
          'qty': '${(tf['qty'] as num).toStringAsFixed(0)} ${itemCode == 'ITM-003' ? 'Bottles' : 'L'}',
          'status': tf['status'] ?? 'Completed',
        });
      }

      // 5. Fetch Pending Approvals
      final requestsData = await _supabase
          .from('approval_requests')
          .select()
          .order('created_at', ascending: false);

      _pendingRequests = requestsData.map((e) => {
        'id': e['id'],
        'title': e['title'],
        'docType': e['doc_type'],
        'requestor': e['requestor'],
        'date': e['date'],
        'amount': e['amount'],
        'reason': e['reason'] ?? '',
      }).toList();

      // 6. Fetch Approval History
      final historyData = await _supabase
          .from('approval_history')
          .select()
          .order('created_at', ascending: false);

      _historyLogs = historyData.map((e) => {
        'id': e['request_id'],
        'title': e['title'],
        'approver': e['approver'],
        'date': e['date'],
        'action': e['action'],
        'remarks': e['remarks'] ?? 'No remarks',
      }).toList();

      // Calculate counters
      approvedCount = 0;
      rejectedCount = 0;
      for (var log in historyData) {
        if (log['action'] == 'Approved') {
          approvedCount++;
        } else if (log['action'] == 'Rejected') {
          rejectedCount++;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading accounting data from Supabase: $e');
    }
  }

  // ─── Functions for Financials ──────────────────────────────────────────────
  Future<bool> postJournalEntry({
    required String refNo,
    required String memo,
    required DateTime postingDate,
    required List<Map<String, dynamic>> lines,
  }) async {
    try {
      double totalDebit = lines.fold(0.0, (sum, item) => sum + (item['debit'] as double));
      double totalCredit = lines.fold(0.0, (sum, item) => sum + (item['credit'] as double));

      if ((totalDebit - totalCredit).abs() > 0.01 || totalDebit <= 0) return false;

      // 1. Insert into journal_entries
      final entry = await _supabase.from('journal_entries').insert({
        'ref_no': refNo,
        'memo': memo,
        'posting_date': postingDate.toIso8601String().split('T')[0],
        'amount': totalDebit,
      }).select().single();

      final entryId = entry['id'] as String;

      // 2. Insert lines & adjust balances in database
      for (var line in lines) {
        final accStr = line['account'].toString();
        final accountCode = accStr.split(' - ').first;
        final double debit = line['debit'] as double;
        final double credit = line['credit'] as double;

        await _supabase.from('journal_lines').insert({
          'entry_id': entryId,
          'account_code': accountCode,
          'debit': debit,
          'credit': credit,
        });

        final accountRes = await _supabase
            .from('gl_accounts')
            .select('category, balance')
            .eq('code', accountCode)
            .single();

        final category = accountRes['category'].toString().toLowerCase();
        double currentBal = (accountRes['balance'] as num).toDouble();
        double change = debit - credit;

        double newBal;
        if (category == 'assets' || category == 'expenses') {
          newBal = currentBal + change;
        } else {
          newBal = currentBal - change;
        }

        await _supabase
            .from('gl_accounts')
            .update({'balance': newBal})
            .eq('code', accountCode);
      }

      await fetchInitialData();
      return true;
    } catch (e) {
      debugPrint('Error posting journal entry: $e');
      return false;
    }
  }

  // ─── Functions for Sales & Purchases ───────────────────────────────────────
  Future<void> postSalesDoc({
    required String docType,
    required String customer,
    required String memo,
    required DateTime date,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      if (docType == 'Delivery' || docType == 'A/R Invoice') {
        for (var item in items) {
          final code = item['itemCode'].toString();
          final double qty = (item['qty'] as num).toDouble();
          
          final itemRes = await _supabase
              .from('inventory_items')
              .select('in_stock')
              .eq('code', code)
              .single();

          final double currentQty = (itemRes['in_stock'] as num).toDouble();
          await _supabase
              .from('inventory_items')
              .update({'in_stock': currentQty - qty})
              .eq('code', code);
        }
      }

      double totalAmount = items.fold(0.0, (sum, item) {
        final double qty = (item['qty'] as num).toDouble();
        final double price = (item['price'] as num).toDouble();
        final double tax = (item['tax'] as num).toDouble();
        return sum + (qty * price * (1 + tax / 100));
      });

      if (totalAmount > 15000000.0 && docType == 'Sales Order') {
        final int reqNo = DateTime.now().millisecondsSinceEpoch % 10000;
        await _supabase.from('approval_requests').insert({
          'id': 'REQ-2026-$reqNo',
          'title': 'Sales Order Above Limit',
          'doc_type': 'Sales Order (SO)',
          'requestor': 'Khin Hnin (Sales Lead)',
          'date': 'Just Now',
          'amount': '${_formatKs(totalAmount)} Ks',
          'reason': 'Sales Order for "$customer" exceeds standard single invoice threshold of 15M Ks.',
        });
      }

      await fetchInitialData();
    } catch (e) {
      debugPrint('Error posting sales document: $e');
    }
  }

  Future<void> postPurchaseDoc({
    required String docType,
    required String vendor,
    required String memo,
    required DateTime date,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      if (docType == 'Goods Receipt PO' || docType == 'A/P Invoice') {
        for (var item in items) {
          final code = item['itemCode'].toString();
          final double qty = (item['qty'] as num).toDouble();
          final double cost = (item['price'] as num).toDouble();

          final itemRes = await _supabase
              .from('inventory_items')
              .select('in_stock, cost')
              .eq('code', code)
              .single();

          final double currentQty = (itemRes['in_stock'] as num).toDouble();
          final double currentMAC = (itemRes['cost'] as num).toDouble();

          final double totalQty = currentQty + qty;
          double newMAC = currentMAC;
          if (totalQty > 0) {
            newMAC = ((currentQty * currentMAC) + (qty * cost)) / totalQty;
          }

          await _supabase
              .from('inventory_items')
              .update({
                'in_stock': totalQty,
                'cost': newMAC,
              })
              .eq('code', code);
        }
      }

      double totalAmount = items.fold(0.0, (sum, item) {
        final double qty = (item['qty'] as num).toDouble();
        final double price = (item['price'] as num).toDouble();
        final double tax = (item['tax'] as num).toDouble();
        return sum + (qty * price * (1 + tax / 100));
      });

      if (totalAmount > 50000000.0 && docType == 'Purchase Order') {
        final int reqNo = DateTime.now().millisecondsSinceEpoch % 10000;
        await _supabase.from('approval_requests').insert({
          'id': 'REQ-2026-$reqNo',
          'title': 'PO Above Standard Budget',
          'doc_type': 'Purchase Order (PO)',
          'requestor': 'Thura Min (Purchasing Manager)',
          'date': 'Just Now',
          'amount': '${_formatKs(totalAmount)} Ks',
          'reason': 'Purchase Order to "$vendor" exceeds 50M Ks budget threshold.',
        });
      }

      await fetchInitialData();
    } catch (e) {
      debugPrint('Error posting purchase document: $e');
    }
  }

  // ─── Stock Transfer Simulator ─────────────────────────────────────────────
  Future<void> createStockTransfer({
    required String from,
    required String to,
    required String itemCode,
    required double qty,
  }) async {
    try {
      final itemRes = await _supabase
          .from('inventory_items')
          .select('in_stock')
          .eq('code', itemCode)
          .single();

      double currentQty = (itemRes['in_stock'] as num).toDouble();
      
      if (from.toLowerCase().contains('depot') && !to.toLowerCase().contains('depot')) {
        currentQty += qty;
      } else if (!from.toLowerCase().contains('depot') && to.toLowerCase().contains('depot')) {
        currentQty -= qty;
      }

      await _supabase
          .from('inventory_items')
          .update({'in_stock': currentQty})
          .eq('code', itemCode);

      final int tfNo = DateTime.now().millisecondsSinceEpoch % 1000;
      await _supabase.from('stock_transfers').insert({
        'id': 'TR-2026-0$tfNo',
        'date': 'Just Now',
        'from_wh': from,
        'to_wh': to,
        'item_code': itemCode,
        'qty': qty,
        'status': 'Completed',
      });

      await fetchInitialData();
    } catch (e) {
      debugPrint('Error creating stock transfer: $e');
    }
  }

  // ─── Approvals Actions ────────────────────────────────────────────────────
  Future<void> handleApprovalDecision(int index, String action, String remarks) async {
    try {
      if (index >= _pendingRequests.length || index < 0) return;

      final req = _pendingRequests[index];
      final reqId = req['id'] as String;

      await _supabase.from('approval_requests').delete().eq('id', reqId);

      await _supabase.from('approval_history').insert({
        'request_id': reqId,
        'title': req['title'],
        'approver': 'Systems Admin',
        'date': 'Just Now',
        'action': action == 'Approve' ? 'Approved' : 'Rejected',
        'remarks': remarks.isEmpty ? 'No remarks' : remarks,
      });

      await fetchInitialData();
    } catch (e) {
      debugPrint('Error handling approval decision: $e');
    }
  }

  String _formatKs(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
