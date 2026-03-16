import 'package:flutter/material.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:ho_msloyalty/services/data_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;

  final TextEditingController _regionController = TextEditingController();
  List<String> _regions = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final regions = await _dataService.getRegions();
      setState(() {
        _regions = regions;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HOColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                    'Manage application-wide configurations and region data',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 32),
                  
                  // Region Management Card
                  Container(
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
                        const Row(
                          children: [
                            Icon(Icons.map, color: HOColors.accent),
                            SizedBox(width: 12),
                            Text(
                              'Region Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add or remove regions available for Station assignment.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _regionController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter new Region (e.g. Yangon)',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (_) => _addRegion(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _addRegion,
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
                          children: _regions.map((r) {
                            return Chip(
                              label: Text(r, style: const TextStyle(color: Colors.white)),
                              backgroundColor: Colors.white10,
                              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white54),
                              onDeleted: () => _removeRegion(r),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
