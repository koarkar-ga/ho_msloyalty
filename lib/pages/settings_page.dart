import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  List<String> _regions = [];
  List<String> _departments = [];
  List<String> _companies = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _regionController.dispose();
    _departmentController.dispose();
    _companyController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final regions = await _dataService.getRegions();
      final departments = await _dataService.getITDepartments();
      final companies = await _dataService.getITCompanies();
      final categories = await _dataService.getITAssetCategories();
      setState(() {
        _regions = regions;
        _departments = departments;
        _companies = companies;
        _categories = categories;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addRegion() async {
    final val = _regionController.text.trim();
    if (val.isNotEmpty && !_regions.contains(val)) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _dataService.addRegion(val);
        _regionController.clear();
        await _loadSettings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding region: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _removeRegion(String r) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _dataService.deleteRegion(r);
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing region: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addDepartment() async {
    final val = _departmentController.text.trim();
    if (val.isNotEmpty && !_departments.contains(val)) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _dataService.addITDepartment(val);
        _departmentController.clear();
        await _loadSettings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding department: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _removeDepartment(String d) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _dataService.deleteITDepartment(d);
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing department: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addCompany() async {
    final val = _companyController.text.trim();
    if (val.isNotEmpty && !_companies.contains(val)) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _dataService.addITCompany(val);
        _companyController.clear();
        await _loadSettings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding company: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _removeCompany(String c) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _dataService.deleteITCompany(c);
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing company: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addCategory() async {
    final val = _categoryController.text.trim();
    if (val.isNotEmpty && !_categories.contains(val)) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _dataService.addITAssetCategory(val);
        _categoryController.clear();
        await _loadSettings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding category: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _removeCategory(String c) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _dataService.deleteITAssetCategory(c);
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing category: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HOColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Settings',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage application-wide configurations, regions, departments, and companies',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 32),

                    // Region Management Card
                    _buildCard(
                      icon: Icons.map,
                      title: 'Region Management',
                      description: 'Add or remove regions available for Station assignment.',
                      controller: _regionController,
                      hintText: 'Enter new Region (e.g. Yangon)',
                      onAdd: _addRegion,
                      items: _regions,
                      onDelete: _removeRegion,
                    ),
                    const SizedBox(height: 24),

                    // Department Management Card
                    _buildCard(
                      icon: Icons.corporate_fare,
                      title: 'IT Department Management',
                      description: 'Add or remove departments available for IT Asset assignment.',
                      controller: _departmentController,
                      hintText: 'Enter new Department (e.g. Audit)',
                      onAdd: _addDepartment,
                      items: _departments,
                      onDelete: _removeDepartment,
                    ),
                    const SizedBox(height: 24),

                    // Company Management Card
                    _buildCard(
                      icon: Icons.domain,
                      title: 'Company / Division Management',
                      description: 'Add or remove company types (e.g., Trading, Construction) for Head Office assignment.',
                      controller: _companyController,
                      hintText: 'Enter new Company Type (e.g. Energy)',
                      onAdd: _addCompany,
                      items: _companies,
                      onDelete: _removeCompany,
                    ),
                    const SizedBox(height: 24),

                    // Category Management Card
                    _buildCard(
                      icon: Icons.category,
                      title: 'IT Asset Category Management',
                      description: 'Add or remove categories available for IT Asset assignment.',
                      controller: _categoryController,
                      hintText: 'Enter new Category (e.g. Mobile Phone)',
                      onAdd: _addCategory,
                      items: _categories,
                      onDelete: _removeCategory,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onAdd,
    required List<String> items,
    required Function(String) onDelete,
  }) {
    return Container(
      width: 600,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: HOColors.accent),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((item) {
              return Chip(
                label: Text(item, style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.white10,
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white54),
                onDeleted: () => onDelete(item),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
