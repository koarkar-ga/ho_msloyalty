import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:intl/intl.dart';
import 'package:ho_msloyalty/services/sms_service.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final HODataService _dataService = HODataService();
  final SMSService _smsService = SMSService();
  List<Map<String, dynamic>> _users = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSendingMulti = false;
  double _sendProgress = 0.0;

  // Filtering & Sorting State
  String _searchQuery = "";
  String _selectedTier = "All Tiers";
  String _selectedStatus = "All Status";
  String _pointsSortOrder = "None"; // "None", "Asc", "Desc"

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
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> filtered = _users.where((user) {
      // Search Filter
      final name = user['full_name']?.toString().toLowerCase() ?? "";
      final phone = user['phone_number']?.toString().toLowerCase() ?? "";
      final memberId = user['member_id']?.toString().toLowerCase() ?? "";
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || 
                            phone.contains(_searchQuery.toLowerCase()) ||
                            memberId.contains(_searchQuery.toLowerCase());

      // Tier Filter
      final tier = user['member_types']?['name']?.toString() ?? "GOLD";
      final matchesTier = _selectedTier == "All Tiers" || tier.toUpperCase() == _selectedTier.toUpperCase();

      // Status Filter
      final isActive = user['is_active'] ?? true;
      final statusStr = isActive ? "Active" : "Inactive";
      final matchesStatus = _selectedStatus == "All Status" || statusStr == _selectedStatus;

      return matchesSearch && matchesTier && matchesStatus;
    }).toList();

    // Sorting
    if (_pointsSortOrder != "None") {
      filtered.sort((a, b) {
        final pointsA = a['total_points'] ?? 0;
        final pointsB = b['total_points'] ?? 0;
        return _pointsSortOrder == "Asc" 
            ? pointsA.compareTo(pointsB) 
            : pointsB.compareTo(pointsA);
      });
    }

    return filtered;
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
          _buildFilters(),
          if (_isSendingMulti) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _sendProgress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(HOColors.accent),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(child: _buildGlassyTable()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEMBER MANAGEMENT',
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

  Widget _buildFilters() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Phone or Member ID...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              _buildModernDropdown(_selectedTier, ['All Tiers', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND'], (v) {
                setState(() => _selectedTier = v!);
              }),
              const SizedBox(width: 12),
              _buildModernDropdown(_selectedStatus, ['All Status', 'Active', 'Inactive'], (v) {
                setState(() => _selectedStatus = v!);
              }),
              if (_selectedUserIds.isNotEmpty) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSendingMulti ? null : () => _showMultiSMSDialog(),
                  icon: const Icon(Icons.send, size: 16),
                  label: Text('SEND TO ${_selectedUserIds.length} SELECTED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HOColors.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: HOColors.surface,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: const Icon(Icons.keyboard_arrow_down, color: HOColors.accent),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showSMSDialog(Map<String, dynamic> user) {
    final TextEditingController controller = TextEditingController();
    final String phone = user['phone_number'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: Text('SEND SMS TO ${user['full_name']?.toString().toUpperCase()}', 
          style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recipient: $phone', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your message...',
                hintStyle: TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent),
            onPressed: () async {
              if (controller.text.isEmpty) return;
              
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User has no phone number'))
                );
                return;
              }

              Navigator.pop(context);
              
              final res = await _smsService.sendSMS(
                to: phone.replaceAll('+', '').replaceAll(' ', ''), 
                message: controller.text
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['status'] == 'success' 
                      ? 'SMS sent successfully!' 
                      : 'Failed to send SMS: ${res['message']}'),
                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                  )
                );
                
                if (res['status'] == 'success') {
                  _dataService.logActivity(
                    actionType: 'SEND_SMS',
                    description: 'Sent SMS to ${user['full_name']} ($phone)',
                    metadata: {'message': controller.text, 'phone': phone}
                  );
                }
              }
            },
            child: const Text('SEND MESSAGE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMultiSMSDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: Text('SEND SMS TO ${_selectedUserIds.length} SELECTED USERS', 
          style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will broadcast the message to all selected members.', 
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your broadcast message...',
                hintStyle: TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent),
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(context);
              _startMultiBroadcast(controller.text);
            },
            child: const Text('START SENDING', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _startMultiBroadcast(String message) async {
    setState(() {
      _isSendingMulti = true;
      _sendProgress = 0.0;
    });

    final selectedUsers = _users.where((u) => _selectedUserIds.contains(u['id'].toString())).toList();
    int sentCount = 0;

    for (int i = 0; i < selectedUsers.length; i++) {
      final user = selectedUsers[i];
      final String phone = user['phone_number'] ?? '';
      
      if (phone.isNotEmpty) {
        await _smsService.sendSMS(
          to: phone.replaceAll('+', '').replaceAll(' ', ''), 
          message: message
        );
        sentCount++;
      }

      setState(() {
        _sendProgress = (i + 1) / selectedUsers.length;
      });
      
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Multi-SMS finished. Sent to $sentCount users.'))
      );
      
      _dataService.logActivity(
        actionType: 'MULTI_SMS',
        description: 'Sent SMS to $sentCount selected users.',
        metadata: {'message': message, 'user_count': sentCount}
      );
    }

    setState(() {
      _isSendingMulti = false;
      _selectedUserIds.clear();
    });
  }

  int _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) return 0;
    try {
      final dob = DateTime.parse(dobString);
      final today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  void _showUserInfoDialog(Map<String, dynamic> user) {
    final tier = user['member_types']?['name']?.toString().toUpperCase() ?? 'GOLD';
    final balance = user['total_points'] ?? 0;
    final joinDate = user['created_at'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(user['created_at'])) 
        : 'N/A';
    
    final lastLogin = user['last_login_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(user['last_login_at']).toLocal())
        : 'Never';
    
    final dob = user['dob'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(user['dob']))
        : 'N/A';
    final age = _calculateAge(user['dob']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          width: 700,
          height: 480,
          child: Stack(
            children: [
              // Main Card Body
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Decorative Background Elements
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: HOColors.accent.withOpacity(0.1),
                            ),
                          ),
                        ),
                        // Content Layout
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Brand & Card Label
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: HOColors.accent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.flash_on, color: Colors.black, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('MOON SUN', style: TextStyle(
                                        color: Colors.white, 
                                        fontWeight: FontWeight.w900, 
                                        letterSpacing: 2.0,
                                        fontSize: 20
                                      )),
                                    ],
                                  ),
                                  Text('DIGITAL PREMIUM MEMBER', style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0
                                  )),
                                ],
                              ),
                              const Spacer(),
                              // Middle Section: Profile & Primary Info
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Avatar with Glowing Border
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: HOColors.accent.withOpacity(0.5), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: HOColors.accent.withOpacity(0.2),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                        )
                                      ],
                                    ),
                                    child: _buildAvatar(user['avatar_url'], user['full_name']?[0] ?? 'G', size: 100),
                                  ),
                                  const SizedBox(width: 32),
                                  // Name & Primary Contact
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user['full_name'] ?? 'Guest User', 
                                          style: const TextStyle(
                                            color: Colors.white, 
                                            fontSize: 32, 
                                            fontWeight: FontWeight.w900,
                                            height: 1.1,
                                            letterSpacing: 0.5
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(user['member_id'] ?? 'MEMBER-ID-NONE', 
                                          style: const TextStyle(color: HOColors.accent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                        const SizedBox(height: 12),
                                        // Phone & Email Row
                                        Row(
                                          children: [
                                            Icon(Icons.phone, color: Colors.white38, size: 14),
                                            const SizedBox(width: 6),
                                            Text(user['phone_number'] ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                            const SizedBox(width: 20),
                                            Icon(Icons.email, color: Colors.white38, size: 14),
                                            const SizedBox(width: 6),
                                            Text(user['email'] ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Stats Grid
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: _buildCardStat('TIER LEVEL', tier, Icons.verified_user)),
                                        Expanded(child: _buildCardStat('CURRENT POINTS', NumberFormat('#,###').format(balance), Icons.stars)),
                                        Expanded(child: _buildCardStat('AGE / DOB', '$age Years ($dob)', Icons.celebration)),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: _buildCardStat('LAST DEVICE MODEL', user['device_model'] ?? 'N/A', Icons.phone_android)),
                                        Expanded(child: _buildCardStat('LAST LOGGED IN', lastLogin, Icons.access_time)),
                                        Expanded(child: _buildCardStat('JOINED DATE', joinDate, Icons.calendar_today)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Close Button
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: HOColors.accent.withOpacity(0.7), size: 12),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildAvatar(String? url, String initial, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HOColors.accent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: HOColors.accent.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: HOColors.surface,
        backgroundImage: url != null ? NetworkImage(url) : null,
        child: url == null 
          ? Text(initial, style: TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: size * 0.4)) 
          : null,
      ),
    );
  }

  Widget _buildGlassyTable() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: Scrollbar(
                  child: ListView.separated(
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                    itemBuilder: (context, index) => _buildUserRow(_filteredUsers[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Checkbox(
              value: _filteredUsers.isNotEmpty && _selectedUserIds.length >= _filteredUsers.length,
              activeColor: HOColors.accent,
              checkColor: Colors.black,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedUserIds.addAll(_filteredUsers.map((u) => u['id'].toString()));
                  } else {
                    _selectedUserIds.clear();
                  }
                });
              },
            ),
          ),
          const Expanded(flex: 3, child: Text('MEMBER', style: _headerStyle)),
          const Expanded(flex: 2, child: Text('MEMBER ID / UID', style: _headerStyle)),
          const Expanded(flex: 1, child: Text('TIER', style: _headerStyle)),
          Expanded(
            flex: 1, 
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_pointsSortOrder == "None") _pointsSortOrder = "Desc";
                  else if (_pointsSortOrder == "Desc") _pointsSortOrder = "Asc";
                  else _pointsSortOrder = "None";
                });
              },
              child: Row(
                children: [
                  const Text('POINTS', style: _headerStyle),
                  const SizedBox(width: 4),
                  Icon(
                    _pointsSortOrder == "Asc" ? Icons.arrow_upward : 
                    _pointsSortOrder == "Desc" ? Icons.arrow_downward : 
                    Icons.sort, 
                    size: 14, 
                    color: _pointsSortOrder == "None" ? Colors.white24 : HOColors.accent
                  ),
                ],
              ),
            ),
          ),
          const Expanded(flex: 2, child: Text('LAST DEVICE', style: _headerStyle)),
          const Expanded(flex: 1, child: Text('STATUS', style: _headerStyle)),
          const SizedBox(width: 100, child: Text('ACTION', style: _headerStyle)),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final balance = user['total_points'] ?? 0;
    final isActive = user['is_active'] ?? true;
    final tier = user['member_types']?['name']?.toString().toUpperCase() ?? 'GOLD';

    return InkWell(
      onTap: () => _showUserInfoDialog(user),
      hoverColor: Colors.white.withOpacity(0.03),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Checkbox(
                value: _selectedUserIds.contains(user['id'].toString()),
                activeColor: HOColors.accent,
                checkColor: Colors.black,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedUserIds.add(user['id'].toString());
                    } else {
                      _selectedUserIds.remove(user['id'].toString());
                    }
                  });
                },
              ),
            ),
            // Member Column
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _buildAvatar(user['avatar_url'], user['full_name']?[0] ?? 'G'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['full_name'] ?? 'Guest', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(user['phone_number'] ?? '-', 
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Member ID / UID Column
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['member_id'] ?? 'N/A', 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: HOColors.accent)),
                  Text(user['id']?.toString() ?? '-', 
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            // Tier Column
            Expanded(
              flex: 1,
              child: _buildTierBadge(tier),
            ),
            // Points Column
            Expanded(
              flex: 1,
              child: Text(
                NumberFormat('#,###').format(balance),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            // Last Device Column
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['device_model'] ?? 'Unknown Device', 
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(user['device_type']?.toString().toUpperCase() ?? '-', 
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            // Status Column
            Expanded(
              flex: 1,
              child: Switch(
                value: isActive,
                activeColor: Colors.greenAccent,
                onChanged: (val) async {
                  await _dataService.updateUserStatus(user['id'].toString(), val);
                  _loadUsers();
                },
              ),
            ),
            // Action Column
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined, size: 18, color: HOColors.accent),
                    onPressed: () => _showSMSDialog(user),
                    tooltip: 'Send SMS',
                  ),
                  TextButton(
                    onPressed: () => _showUserInfoDialog(user),
                    child: const Text('VIEW', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTierBadge(String tier) {
    Color color = Colors.amber;
    if (tier == 'SILVER') color = Colors.blueGrey.shade100;
    if (tier == 'PLATINUM') color = Colors.cyanAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, color: color, size: 12),
          const SizedBox(width: 6),
          Text(tier, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    color: Colors.white60,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );
}
