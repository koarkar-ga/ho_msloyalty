import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:ui';

class GiftCardManagementPage extends StatefulWidget {
  const GiftCardManagementPage({super.key});

  @override
  State<GiftCardManagementPage> createState() => _GiftCardManagementPageState();
}

class _GiftCardManagementPageState extends State<GiftCardManagementPage> {
  final HODataService _dataService = HODataService();
  List<Map<String, dynamic>> _giftCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGiftCards();
  }

  Future<void> _loadGiftCards() async {
    setState(() => _isLoading = true);
    try {
      final cards = await _dataService.getGiftCards();
      setState(() {
        _giftCards = cards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading gift cards: $e')),
      );
    }
  }

  void _showEditSheet([Map<String, dynamic>? card]) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => _GiftCardEditDialog(
        card: card,
        onSaved: _loadGiftCards,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HOColors.background,
      appBar: AppBar(
        title: Text('Gift Card Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showEditSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add New Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HOColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGiftCards,
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 220,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: _giftCards.length,
                itemBuilder: (context, index) => _buildGiftCard(_giftCards[index]),
              ),
            ),
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> card) {
    return Container(
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HOColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Row(
              children: [
                // Image Section
                Container(
                  width: 140,
                  height: double.infinity,
                  color: HOColors.divider.withOpacity(0.1),
                  child: card['image_url'] != null
                      ? Image.network(card['image_url'], fit: BoxFit.cover, 
                          errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.card_giftcard, size: 40, color: HOColors.textSecondary))
                      : const Icon(Icons.card_giftcard, size: 40, color: HOColors.textSecondary),
                ),
                // Info Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card['title'] ?? 'Unnamed Card',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: HOColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${card['points_required']} Points',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HOColors.accent,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: card['is_available'] == true ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              card['is_available'] == true ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                fontSize: 12,
                                color: card['is_available'] == true ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _showEditSheet(card),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HOColors.accent.withOpacity(0.1),
                            foregroundColor: HOColors.accent,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Edit Details'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCardEditDialog extends StatefulWidget {
  final Map<String, dynamic>? card;
  final VoidCallback onSaved;

  const _GiftCardEditDialog({this.card, required this.onSaved});

  @override
  State<_GiftCardEditDialog> createState() => _GiftCardEditDialogState();
}

class _GiftCardEditDialogState extends State<_GiftCardEditDialog> {
  final HODataService _dataService = HODataService();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _pointsController;
  late TextEditingController _imageUrlController;
  late TextEditingController _agreementController;
  bool _isAvailable = true;
  bool _isSaving = false;
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card?['title'] ?? '');
    _descController = TextEditingController(text: widget.card?['description'] ?? '');
    _pointsController = TextEditingController(text: widget.card?['points_required']?.toString() ?? '0');
    _imageUrlController = TextEditingController(text: widget.card?['image_url'] ?? '');
    _agreementController = TextEditingController(text: widget.card?['agreement'] ?? '');
    _isAvailable = widget.card?['is_available'] ?? true;
  }

  Uint8List? _previewBytes;

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _previewBytes = file.bytes;
          _selectedFile = file;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File Selection Error: $e')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      String? imageUrl = _imageUrlController.text;

      if (_previewBytes != null) {
        final ext = _selectedFile?.extension ?? 'png';
        imageUrl = await _dataService.uploadGiftCardImage(_previewBytes!, ext);
      }

      final data = {
        'title': _titleController.text,
        'description': _descController.text,
        'points_required': int.tryParse(_pointsController.text) ?? 0,
        'image_url': imageUrl,
        'agreement': _agreementController.text,
        'is_available': _isAvailable,
      };

      if (widget.card != null) {
        await _dataService.updateGiftCard(widget.card!['id'], data);
      } else {
        await _dataService.createGiftCard(data);
      }

      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gift Card saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: HOColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.card == null ? 'CREATE NEW' : 'EDIT',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: HOColors.accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gift Card Details',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Image Container ---
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                                image: _previewBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_previewBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_imageUrlController.text.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(_imageUrlController.text),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                              ),
                              child: _previewBytes == null && _imageUrlController.text.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.white.withOpacity(0.3)),
                                          const SizedBox(height: 12),
                                          Text('Upload Image', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.3))),
                                        ],
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Recommended: 1:1 Aspect Ratio',
                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      
                      // --- Form Fields ---
                      Expanded(
                        child: Column(
                          children: [
                            _buildModernField(
                              controller: _titleController,
                              label: 'TITLE',
                              icon: Icons.title,
                              hint: 'e.g. Moon Sun Premium Tee',
                            ),
                            const SizedBox(height: 24),
                            _buildModernField(
                              controller: _pointsController,
                              label: 'POINTS REQUIRED',
                              icon: Icons.bolt,
                              hint: '1000',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'AVAILABLE FOR REDEMPTION',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: Colors.white60,
                                  ),
                                ),
                                value: _isAvailable,
                                activeColor: HOColors.accent,
                                onChanged: (v) => setState(() => _isAvailable = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildModernField(
                    controller: _descController,
                    label: 'DESCRIPTION',
                    icon: Icons.description_outlined,
                    hint: 'Details about the item...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  _buildModernField(
                    controller: _agreementController,
                    label: 'TERMS & CONDITIONS',
                    icon: Icons.gavel_rounded,
                    hint: 'e.g. Valid at all stations...',
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // --- Buttons ---
                  Row(
                    children: [
                      if (widget.card != null) 
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: IconButton(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Delete Card',
                          ),
                        ),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [HOColors.accent, Color(0xFFB8962D)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: HOColors.accent.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _isSaving 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  widget.card == null ? 'CREATE GIFT CARD' : 'SAVE CHANGES',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                          ),
                        ),
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

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.white54,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
            prefixIcon: Icon(icon, size: 20, color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: HOColors.accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: Text('Delete Gift Card?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('This action cannot be undone and will remove this card from the rewards list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dataService.deleteGiftCard(widget.card!['id']);
      widget.onSaved();
      Navigator.pop(context);
    }
  }
}

// End of file
