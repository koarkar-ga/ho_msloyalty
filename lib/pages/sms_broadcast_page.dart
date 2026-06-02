import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:ms_dashboard/services/sms_service.dart';

class SMSBroadcastPage extends StatefulWidget {
  const SMSBroadcastPage({super.key});

  @override
  State<SMSBroadcastPage> createState() => _SMSBroadcastPageState();
}

class _SMSBroadcastPageState extends State<SMSBroadcastPage> {
  final HODataService _dataService = HODataService();
  final SMSService _smsService = SMSService();
  final TextEditingController _msgController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isSending = false;
  double _sendProgress = 0.0;
  String _sendLogs = "";

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _dataService.getUsers();
      setState(() {
        _users = users
            .where(
              (u) =>
                  u['phone_number'] != null &&
                  u['phone_number'].toString().isNotEmpty,
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  Future<void> _startBroadcast() async {
    if (_msgController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    setState(() {
      _isSending = true;
      _sendProgress = 0.0;
      _sendLogs = "Starting broadcast to ${_users.length} users...\n";
    });

    int sentCount = 0;
    for (int i = 0; i < _users.length; i++) {
      final user = _users[i];
      final phone = user['phone_number']
          .toString()
          .replaceAll('+', '')
          .replaceAll(' ', '');

      final res = await _smsService.sendSMS(
        to: phone,
        message: _msgController.text,
      );

      sentCount++;
      setState(() {
        _sendProgress = (i + 1) / _users.length;
        _sendLogs +=
            "[${i + 1}/${_users.length}] ${user['full_name']} ($phone): ${res['status'].toUpperCase()}\n";
      });

      // Small delay to avoid hitting rate limits too fast
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _dataService.logActivity(
      actionType: 'SMS_BROADCAST',
      description: 'Broadcasted SMS to $sentCount users.',
      metadata: {'message': _msgController.text, 'user_count': sentCount},
    );

    setState(() {
      _isSending = false;
      _sendLogs += "\nBroadcast finished. Total sent: $sentCount";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildComposerCard()),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildStatsCard()),
              ],
            ),
          ),
          if (_isSending || _sendLogs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildProgressCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SMS BROADCAST',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            gradient: HOColors.premiumGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildComposerCard() {
    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPOSE MESSAGE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _msgController,
            maxLines: 8,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type your broadcast message here...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: HOColors.accent,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (_isSending || _isLoading) ? null : _startBroadcast,
              icon: const Icon(Icons.send_rounded, color: Colors.black),
              label: Text(
                _isSending ? 'SENDING...' : 'START BROADCAST',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECIPIENTS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          _statItem(
            'Total Members',
            _users.length.toString(),
            Icons.people_outline,
          ),
          const SizedBox(height: 16),
          _statItem(
            'Valid Phone #',
            _users.length.toString(),
            Icons.phone_android_outlined,
          ),
          const Divider(height: 32, color: Colors.white12),
          Text(
            'The message will be sent to all active members with a valid phone number registered in the system.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRANSMISSION LOGS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isSending)
                Text(
                  '${(_sendProgress * 100).toInt()}%',
                  style: const TextStyle(
                    color: HOColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isSending) ...[
            LinearProgressIndicator(
              value: _sendProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(HOColors.accent),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _sendLogs,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: HOColors.accent, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _glassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
