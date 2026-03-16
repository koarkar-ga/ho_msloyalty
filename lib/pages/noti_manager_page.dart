import 'package:flutter/material.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:intl/intl.dart';
import 'package:bot_toast/bot_toast.dart';

class NotiManagerPage extends StatefulWidget {
  const NotiManagerPage({super.key});

  @override
  State<NotiManagerPage> createState() => _NotiManagerPageState();
}

class _NotiManagerPageState extends State<NotiManagerPage> {
  final HODataService _dataService = HODataService();
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedTarget = 'ALL';
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _dataService.getMobileNotificationLogs();
      setState(() => _logs = logs);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await _dataService.sendMobileNotification(
        title: _titleController.text,
        body: _bodyController.text,
        targetType: _selectedTarget,
      );
      
      _titleController.clear();
      _bodyController.clear();
      BotToast.showText(text: "Notification sent successfully!");
      _loadLogs();
    } catch (e) {
      BotToast.showText(text: "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this notification from history?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _dataService.deleteMobileNotification(id);
        BotToast.showText(text: "Notification deleted");
        _loadLogs();
      } catch (e) {
        BotToast.showText(text: "Error: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearAll() async {
    if (_logs.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text('Confirm Clear All', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to clear ALL notification history? This cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _dataService.clearMobileNotificationHistory();
        BotToast.showText(text: "History cleared");
        _loadLogs();
      } catch (e) {
        BotToast.showText(text: "Error: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HOColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mobile Notification Manager',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Composer
                  SizedBox(
                    width: 400,
                    child: SingleChildScrollView(child: _buildComposer()),
                  ),
                  const SizedBox(width: 24),
                  // History
                  Expanded(
                    child: _buildHistory(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compose Notification',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildField('Title', _titleController, 'Enter notification title'),
            const SizedBox(height: 16),
            _buildField('Message Body', _bodyController, 'Enter notification message', maxLines: 4),
            const SizedBox(height: 16),
            const Text('Target Audience', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            _buildTargetSelector(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _send,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Send Broadcast'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildTargetSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTarget,
          isExpanded: true,
          dropdownColor: HOColors.surface,
          items: ['ALL', 'GOLD', 'SILVER', 'BRONZE'].map((t) {
            return DropdownMenuItem(
              value: t,
              child: Text(t, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedTarget = v!),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                const Text(
                  'Notification History',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (_logs.isNotEmpty)
                      TextButton.icon(
                        onPressed: _isLoading ? null : _clearAll,
                        icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white38, size: 18),
                        label: const Text('Clear History', style: TextStyle(color: Colors.white38, fontSize: 13)),
                      ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: _loadLogs, icon: const Icon(Icons.refresh, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading && _logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text('No history found.', style: TextStyle(color: Colors.white24)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05)),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              child: Icon(Icons.notifications_active, color: Colors.white, size: 20),
                            ),
                            title: Text(log['title'] ?? 'No Title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log['body'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 3, overflow: TextOverflow.visible),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 12, color: HOColors.accent),
                                    const SizedBox(width: 4),
                                    Text(log['sender_name'] ?? 'System', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                    const SizedBox(width: 12),
                                    Icon(Icons.group, size: 12, color: HOColors.accent),
                                    const SizedBox(width: 4),
                                    Text('Target: ${log['target_type']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                    const Spacer(),
                                    Text(
                                      DateFormat('MMM dd, HH:mm').format(DateTime.parse(log['created_at'])),
                                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _delete(log['id']),
                              tooltip: 'Delete from history',
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
