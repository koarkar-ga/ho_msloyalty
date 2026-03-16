import 'package:flutter/material.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class StationListPage extends StatefulWidget {
  const StationListPage({super.key});

  @override
  State<StationListPage> createState() => _StationListPageState();
}

class _StationListPageState extends State<StationListPage> {
  final HODataService _dataService = HODataService();
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _filteredStations = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _selectedRegion = "All Regions";
  List<String> _regions = ["All Regions"];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final stations = await _dataService.getStationsWithMetrics();
      final fetchedRegions = await _dataService.getRegions();
      
      setState(() {
        _stations = stations;
        
        // If DB has no regions yet, fallback to deducing from existing stations
        if (fetchedRegions.isNotEmpty) {
          _regions = ["All Regions", ...fetchedRegions];
        } else {
          final uniqueRegions = stations
              .map((s) => s['region']?.toString() ?? 'Other')
              .toSet()
              .toList()
            ..sort();
          _regions = ["All Regions", ...uniqueRegions];
        }

        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStations = _stations.where((station) {
        final String name = (station['name'] ?? '').toString().toLowerCase();
        final String id = (station['station_id'] ?? '').toString().toLowerCase();
        final bool matchesSearch = name.contains(query) || id.contains(query);

        final String region = (station['region'] ?? '').toString();
        final bool matchesRegion = _selectedRegion == "All Regions" || region == _selectedRegion;

        return matchesSearch && matchesRegion;
      }).toList();
    });
  }

  void _showEditSheet([Map<String, dynamic>? station]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StationEditDialog(
        station: station,
        onSave: () {
          _loadStations();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stations Management',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your fuel stations across all regions',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showEditSheet(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Station'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.accent.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // ── Search and Filter Bar ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: HOColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _applyFilters(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by station name or ID...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: HOColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRegion,
                    dropdownColor: HOColors.surface,
                    icon: const Icon(Icons.filter_list, color: HOColors.accent),
                    items: _regions.map((region) {
                      return DropdownMenuItem(
                        value: region,
                        child: Text(region, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRegion = val);
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredStations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text("No stations found", style: TextStyle(color: Colors.white.withOpacity(0.3))),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      mainAxisExtent: 260, // Increased to accommodate Phone/Address
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                    ),
                    itemCount: _filteredStations.length,
                    itemBuilder: (context, index) {
                      final station = _filteredStations[index];
                      return _buildStationCard(station);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    return Container(
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 130,
            child: station['image_url'] != null && station['image_url'].toString().isNotEmpty
              ? Image.network(
                  station['image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: Colors.white10, child: const Icon(Icons.ev_station, color: HOColors.accent, size: 40)),
                )
              : Container(color: Colors.white10, child: const Icon(Icons.ev_station, color: HOColors.accent, size: 40)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          station['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _statusBadge(station['status'] ?? 'Online'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${station['station_id'] ?? '-'}',
                    style: TextStyle(color: HOColors.accent.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildIconTextRow(Icons.phone_outlined, station['phone'] ?? 'No phone provided'),
                  const SizedBox(height: 6),
                  _buildIconTextRow(Icons.map_outlined, station['region'] ?? 'Unknown Region'),
                  const SizedBox(height: 6),
                  _buildIconTextRow(Icons.location_on_outlined, station['address'] ?? 'No address provided', maxLines: 2),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ISSUED POINTS',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white.withOpacity(0.4))),
                            Text('${station['totalPoints'] ?? 0}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showEditSheet(station),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HOColors.accent,
                          foregroundColor: HOColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconTextRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final isOnline = status == 'Online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isOnline ? Colors.green : Colors.red).withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isOnline ? Colors.green : Colors.red,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StationEditDialog extends StatefulWidget {
  final Map<String, dynamic>? station;
  final VoidCallback onSave;

  const _StationEditDialog({this.station, required this.onSave});

  @override
  State<_StationEditDialog> createState() => _StationEditDialogState();
}

class _StationEditDialogState extends State<_StationEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _idController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _mapUrlController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  
  String? _selectedRegion;
  List<String> _availableRegions = [];
  String? _imageUrl;
  bool _isSaving = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _nameController = TextEditingController(text: s?['name'] ?? '');
    _idController = TextEditingController(text: s?['station_id'] ?? '');
    _addressController = TextEditingController(text: s?['address'] ?? '');
    _phoneController = TextEditingController(text: s?['phone'] ?? '');
    _mapUrlController = TextEditingController(text: s?['map_url'] ?? '');
    _latController = TextEditingController(text: s?['lat']?.toString() ?? '');
    _lngController = TextEditingController(text: s?['lng']?.toString() ?? '');
    _selectedRegion = s?['region'];
    _imageUrl = s?['image_url'];
    
    _fetchRegions();
  }

  Future<void> _fetchRegions() async {
    try {
      final regions = await HODataService().getRegions();
      
      if (mounted) {
        setState(() {
          _availableRegions = regions.isNotEmpty ? regions : ["Yangon", "Mandalay", "Naypyidaw", "Bago", "Sagaing"];
          
          if (_selectedRegion != null && !_availableRegions.contains(_selectedRegion!)) {
            _availableRegions.add(_selectedRegion!);
          }
          if (_selectedRegion == null && _availableRegions.isNotEmpty) {
            _selectedRegion = _availableRegions.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final extension = file.extension;
        
        if (bytes != null) {
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageExt = extension;
          });
        }
      }
    } catch (e) {
      print("File Selection Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? finalImageUrl = _imageUrl;
      
      if (_selectedImageBytes != null && _selectedImageExt != null) {
        finalImageUrl = await HODataService().uploadStationImage(
          _idController.text, 
          _selectedImageBytes!, 
          _selectedImageExt!
        );
      }

      final Map<String, dynamic> data = {
        'name': _nameController.text,
        'station_id': _idController.text,
        'region': _selectedRegion,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'map_url': _mapUrlController.text,
        'image_url': finalImageUrl,
      };

      // Add double precision lat/lng explicitly
      if (_latController.text.isNotEmpty) {
        data['lat'] = double.tryParse(_latController.text);
      } else {
        data['lat'] = null; // Map payload needs null if cleared
      }

      if (_lngController.text.isNotEmpty) {
        data['lng'] = double.tryParse(_lngController.text);
      } else {
        data['lng'] = null;
      }

      if (widget.station == null) {
        await HODataService().createStation(data);
      } else {
        await HODataService().updateStation(widget.station!['id'], data);
      }

      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 650,
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: HOColors.background,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit Station Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 32),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                            image: _selectedImageBytes != null 
                              ? DecorationImage(image: MemoryImage(_selectedImageBytes!), fit: BoxFit.cover)
                              : (_imageUrl != null && _imageUrl!.isNotEmpty 
                                  ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
                                  : null),
                          ),
                          child: (_selectedImageBytes == null && (_imageUrl == null || _imageUrl!.isEmpty))
                            ? const Icon(Icons.ev_station, size: 60, color: Colors.white24)
                            : null,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                          label: const Text('Change Photo'),
                          style: TextButton.styleFrom(foregroundColor: HOColors.accent),
                        ),
                      ],
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        children: [
                          _buildField(_nameController, "Station Name", Icons.store_outlined),
                          const SizedBox(height: 16),
                          _buildField(_idController, "Station ID / Code", Icons.badge_outlined),
                          const SizedBox(height: 16),
                          _buildRegionDropdown(),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                _buildField(_addressController, "Exact Address", Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField(_phoneController, "Contact Phone", Icons.phone_outlined)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(_mapUrlController, "Google Maps Link", Icons.link_outlined)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(_latController, "Latitude (e.g. 16.8409)", Icons.gps_fixed, isNumber: true)
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField(_lngController, "Longitude (e.g. 96.1735)", Icons.gps_fixed, isNumber: true)
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Discard Changes', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HOColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 10,
                      ),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update Station Data', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : null,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: HOColors.primary.withOpacity(0.5), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: HOColors.primary, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (isNumber && double.tryParse(v) == null) {
          return 'Must be a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildRegionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRegion,
      dropdownColor: HOColors.surface,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: "Region",
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(Icons.map_outlined, color: HOColors.primary.withOpacity(0.5), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: HOColors.primary, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: _availableRegions.map((region) {
        return DropdownMenuItem(
          value: region,
          child: Text(region),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedRegion = val;
        });
      },
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}
