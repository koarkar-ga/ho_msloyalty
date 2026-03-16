import 'package:flutter/material.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:ho_msloyalty/theme.dart';
import 'dart:ui';

class SystemUserPage extends StatefulWidget {
  const SystemUserPage({super.key});

  @override
  State<SystemUserPage> createState() => _SystemUserPageState();
}

class _SystemUserPageState extends State<SystemUserPage> with SingleTickerProviderStateMixin {
  final HODataService _dataService = HODataService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _stationUsers = [];
  List<Map<String, dynamic>> _hoUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final stations = await _dataService.getStationUsers();
      final ho = await _dataService.getHOUsers();
      setState(() {
        _stationUsers = stations;
        _hoUsers = ho;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog([Map<String, dynamic>? user, bool isHO = false]) {
    showDialog(
      context: context,
      builder: (context) => _UserEditDialog(
        user: user,
        isHO: isHO,
        onSave: () => _loadUsers(),
      ),
    );
  }

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HOColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'System User Management',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditDialog(null, false),
                      icon: const Icon(Icons.dock),
                      label: const Text('Add Station User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showEditDialog(null, true),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Add HO User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HOColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Station App Users'),
                      Tab(text: 'HO Dashboard Users'),
                    ],
                    labelColor: HOColors.accent,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: HOColors.accent,
                    isScrollable: true,
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by username or station...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  controller: _tabController,
                  children: [
                    _UserList(
                      users: _filterUsers(_stationUsers), 
                      isHO: false, 
                      onEdit: (u) => _showEditDialog(u, false), 
                      onRefresh: _loadUsers
                    ),
                    _UserList(
                      users: _filterUsers(_hoUsers), 
                      isHO: true, 
                      onEdit: (u) => _showEditDialog(u, true), 
                      onRefresh: _loadUsers
                    ),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    return users.where((u) {
      final username = u['username'].toString().toLowerCase();
      final fullname = (u['fullname'] ?? '').toString().toLowerCase();
      final stationName = (u['station_name'] ?? '').toString().toLowerCase();
      final stationCode = (u['station_code'] ?? '').toString().toLowerCase();
      
      return username.contains(_searchQuery.toLowerCase()) || 
             fullname.contains(_searchQuery.toLowerCase()) || 
             stationName.contains(_searchQuery.toLowerCase()) || 
             stationCode.contains(_searchQuery.toLowerCase());
    }).toList();
  }
}

class _UserList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isHO;
  final Function(Map<String, dynamic>) onEdit;
  final VoidCallback onRefresh;

  const _UserList({required this.users, required this.isHO, required this.onEdit, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found', style: TextStyle(color: Colors.white38)));
    }

    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05)),
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user['fullname'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Username: ${user['username']} | ${isHO ? "HO Admin" : "Station: ${user["station_name"] ?? user["station_code"] ?? "N/A"}"}', style: const TextStyle(color: Colors.white54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HOColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Level ${user['userlevel']}', style: TextStyle(color: HOColors.accent, fontSize: 12)),
                ),
                IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () => onEdit(user)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteUser(context, user)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteUser(BuildContext context, Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete user "${user['username']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (isHO) {
          await HODataService().deleteHOUser(user['id']);
        } else {
          await HODataService().deleteStationUser(user['id']);
        }
        onRefresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _UserEditDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final bool isHO;
  final VoidCallback onSave;

  const _UserEditDialog({this.user, required this.isHO, required this.onSave});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _fullnameController;
  late TextEditingController _stationCodeController;
  int _userLevel = 11;
  bool _isSaving = false;

  List<Map<String, dynamic>> _allStations = [];
  List<Map<String, dynamic>> _filteredStations = [];
  bool _isLoadingStations = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user?['username'] ?? '');
    _passwordController = TextEditingController(text: widget.user?['password'] ?? '');
    _fullnameController = TextEditingController(text: widget.user?['fullname'] ?? '');
    _stationCodeController = TextEditingController(text: widget.isHO ? 'ALL' : (widget.user?['station_code'] ?? ''));
    _userLevel = widget.user?['userlevel'] ?? (widget.isHO ? 1 : 11);
    
    if (!widget.isHO) {
      _fetchStations();
    }
  }

  Future<void> _fetchStations() async {
    setState(() => _isLoadingStations = true);
    try {
      final stations = await HODataService().getStationsForDropdown();
      setState(() {
        _allStations = [
          {'station_id': 'ALL', 'name': 'ALL STATIONS'},
          ...stations,
        ];
        _filteredStations = _allStations;
      });
    } catch (e) {
      debugPrint('Error fetching stations: $e');
    } finally {
      setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'username': _usernameController.text,
        'password': _passwordController.text,
        'fullname': _fullnameController.text,
        'userlevel': _userLevel,
      };

      if (!widget.isHO) {
        data['station_code'] = _stationCodeController.text;
      }

      if (widget.user == null) {
        if (widget.isHO) {
          await HODataService().createHOUser(data);
        } else {
          await HODataService().createStationUser(data);
        }
      } else {
        if (widget.isHO) {
          await HODataService().updateHOUser(widget.user!['id'], data);
        } else {
          await HODataService().updateStationUser(widget.user!['id'], data);
        }
      }

      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: HOColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.user == null ? 'Add System User' : 'Edit System User',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  _buildField('Username', _usernameController),
                  const SizedBox(height: 16),
                  _buildField('Password', _passwordController),
                  const SizedBox(height: 16),
                  _buildField('Full Name', _fullnameController),
                  const SizedBox(height: 16),
                  if (!widget.isHO) ...[
                    _buildStationSelector(),
                    const SizedBox(height: 16),
                  ],
                  _buildLevelDropdown(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent, foregroundColor: Colors.white),
                        child: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildStationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _stationCodeController,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Assigned Station',
            labelStyle: const TextStyle(color: Colors.white54),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: HOColors.accent),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onTap: _showStationPicker,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  void _showStationPicker() {
    _searchController.clear();
    _filteredStations = _allStations;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: HOColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            height: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Select Station', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search station name or code...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) {
                    setDialogState(() {
                      _filteredStations = _allStations
                          .where((s) => s['name'].toString().toLowerCase().contains(v.toLowerCase()) || 
                                       s['station_id'].toString().toLowerCase().contains(v.toLowerCase()))
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingStations 
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _filteredStations.length,
                        itemBuilder: (context, index) {
                          final s = _filteredStations[index];
                          final isAll = s['station_id'] == 'ALL';
                          return ListTile(
                            onTap: () {
                              setState(() {
                                _stationCodeController.text = s['station_id'].toString();
                              });
                              Navigator.pop(context);
                            },
                            title: Text(s['name'], style: TextStyle(color: isAll ? HOColors.accent : Colors.white)),
                            subtitle: Text('Code: ${s['station_id']}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            leading: Icon(isAll ? Icons.all_out : Icons.ev_station, color: isAll ? HOColors.accent : Colors.white38),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelDropdown() {
    return DropdownButtonFormField<int>(
      value: _userLevel,
      dropdownColor: HOColors.surface,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'User Level',
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Admin (Level 1)')),
        DropdownMenuItem(value: 11, child: Text('Staff (Level 11)')),
      ],
      onChanged: (val) => setState(() => _userLevel = val!),
    );
  }
}
