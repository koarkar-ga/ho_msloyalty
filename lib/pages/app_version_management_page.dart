import 'package:flutter/material.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:ho_msloyalty/theme.dart';
import 'dart:ui';

class AppVersionManagementPage extends StatefulWidget {
  const AppVersionManagementPage({super.key});

  @override
  State<AppVersionManagementPage> createState() => _AppVersionManagementPageState();
}

class _AppVersionManagementPageState extends State<AppVersionManagementPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _versions = [];

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      final versions = await _dataService.getAppVersions();
      setState(() {
        _versions = versions;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading versions: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog([Map<String, dynamic>? version]) {
    showDialog(
      context: context,
      builder: (context) => _VersionEditDialog(
        version: version,
        onSave: () => _loadVersions(),
      ),
    );
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mobile App Update Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(),
                  icon: const Icon(Icons.add_to_home_screen_rounded),
                  label: const Text('Release New Version'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HOColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildVersionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionList() {
    if (_versions.isEmpty) {
      return const Center(
        child: Text(
          'No version records found',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: _versions.length,
        separatorBuilder: (context, index) =>
            Divider(color: Colors.white.withOpacity(0.05)),
        itemBuilder: (context, index) {
          final v = _versions[index];
          final bool isMandatory = v['is_mandatory'] ?? false;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isMandatory ? Colors.red : HOColors.accent).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMandatory ? Icons.warning_rounded : Icons.system_update_rounded,
                color: isMandatory ? Colors.red : HOColors.accent,
              ),
            ),
            title: Text(
              'v${v['version_code']} (${v['build_number']})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  v['release_notes'] ?? 'No release notes',
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (v['android_url'] != null)
                      _buildPlatformChip(Icons.android, 'Android'),
                    if (v['ios_url'] != null)
                      _buildPlatformChip(Icons.apple, 'iOS'),
                    if (v['windows_url'] != null)
                      _buildPlatformChip(Icons.window, 'Windows'),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMandatory)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MANDATORY',
                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70),
                  onPressed: () => _showEditDialog(v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteVersion(v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlatformChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white38),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _deleteVersion(Map<String, dynamic> version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete version ${version['version_code']}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.deleteAppVersion(version['id']);
        _loadVersions();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _VersionEditDialog extends StatefulWidget {
  final Map<String, dynamic>? version;
  final VoidCallback onSave;

  const _VersionEditDialog({this.version, required this.onSave});

  @override
  State<_VersionEditDialog> createState() => _VersionEditDialogState();
}

class _VersionEditDialogState extends State<_VersionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _buildController;
  late TextEditingController _notesController;
  late TextEditingController _androidController;
  late TextEditingController _iosController;
  late TextEditingController _windowsController;
  bool _isMandatory = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.version?['version_code'] ?? '');
    _buildController = TextEditingController(text: widget.version?['build_number']?.toString() ?? '');
    _notesController = TextEditingController(text: widget.version?['release_notes'] ?? '');
    _androidController = TextEditingController(text: widget.version?['android_url'] ?? '');
    _iosController = TextEditingController(text: widget.version?['ios_url'] ?? '');
    _windowsController = TextEditingController(text: widget.version?['windows_url'] ?? '');
    _isMandatory = widget.version?['is_mandatory'] ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'version_code': _codeController.text,
        'build_number': int.tryParse(_buildController.text) ?? 0,
        'release_notes': _notesController.text,
        'android_url': _androidController.text.isNotEmpty ? _androidController.text : null,
        'ios_url': _iosController.text.isNotEmpty ? _iosController.text : null,
        'windows_url': _windowsController.text.isNotEmpty ? _windowsController.text : null,
        'is_mandatory': _isMandatory,
      };

      if (widget.version == null) {
        await HODataService().createAppVersion(data);
      } else {
        await HODataService().updateAppVersion(widget.version!['id'], data);
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
          width: 600,
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
                    widget.version == null ? 'Release Update' : 'Edit Update Info',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: _buildField('Version Code (e.g. 1.0.2)', _codeController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildField('Build Number (e.g. 3)', _buildController, isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildField('Release Notes', _notesController, maxLines: 3),
                  const SizedBox(height: 16),
                  _buildField('Android Download URL', _androidController),
                  const SizedBox(height: 16),
                  _buildField('iOS Download URL', _iosController),
                  const SizedBox(height: 16),
                  _buildField('Windows Download URL', _windowsController),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Is Mandatory Update?', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Forces users to update before using the app', style: TextStyle(color: Colors.white54)),
                    secondary: Icon(Icons.warning_amber_rounded, color: _isMandatory ? Colors.red : Colors.white24),
                    value: _isMandatory,
                    onChanged: (val) => setState(() => _isMandatory = val),
                    activeColor: Colors.redAccent,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent, foregroundColor: Colors.white),
                        child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Publish Release'),
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

  Widget _buildField(String label, TextEditingController controller, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v!.isEmpty && !label.contains('URL') && !label.contains('iOS') && !label.contains('Windows') ? 'Required' : null,
    );
  }
}
