import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:ms_dashboard/theme.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';

class AdManagementPage extends StatefulWidget {
  const AdManagementPage({super.key});

  @override
  State<AdManagementPage> createState() => _AdManagementPageState();
}

class _AdManagementPageState extends State<AdManagementPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _introVideos = [];

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final adsData = await _dataService.getAdvertisements();
      final introData = await _dataService.getIntroVideos();
      setState(() {
        _ads = adsData;
        _introVideos = introData;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading ads: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog([Map<String, dynamic>? ad]) {
    showDialog(
      context: context,
      builder: (context) => _AdEditDialog(ad: ad, onSave: () => _loadAds()),
    );
  }

  void _showIntroEditDialog([Map<String, dynamic>? video]) {
    showDialog(
      context: context,
      builder: (context) =>
          _IntroVideoEditDialog(video: video, onSave: () => _loadAds()),
    );
  }

  Future<void> _deleteIntroVideo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this intro video?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.deleteIntroVideo(id);
        _loadAds();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting intro video: $e')),
        );
      }
    }
  }

  Future<void> _deleteAd(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this advertisement?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.deleteAdvertisement(id);
        _loadAds();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting ad: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: HOColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Promotion & Media',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Splash ADs'),
              Tab(text: 'Welcome Intro Video'),
            ],
            indicatorColor: HOColors.accent,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: TabBarView(
          children: [
            // Splash ADs Tab
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Splash AD Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Advertisement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HOColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _ads.isEmpty
                        ? const Center(
                            child: Text(
                              'No advertisements found',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 0.8,
                                ),
                            itemCount: _ads.length,
                            itemBuilder: (context, index) {
                              final ad = _ads[index];
                              return _AdCard(
                                ad: ad,
                                onEdit: () => _showEditDialog(ad),
                                onDelete: () => _deleteAd(ad['id']),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // Welcome Intro Video Tab
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Welcome Intro Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showIntroEditDialog(),
                        icon: const Icon(Icons.video_call),
                        label: const Text('Add Intro Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _introVideos.isEmpty
                        ? const Center(
                            child: Text(
                              'No intro videos found. Default video will be used.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 1.2,
                                ),
                            itemCount: _introVideos.length,
                            itemBuilder: (context, index) {
                              final video = _introVideos[index];
                              return _IntroVideoCard(
                                video: video,
                                onEdit: () => _showIntroEditDialog(video),
                                onDelete: () => _deleteIntroVideo(video['id']),
                              );
                            },
                          ),
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

class _AdCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdCard({
    required this.ad,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: ad['image_url'] != null
                ? Image.network(ad['image_url'], fit: BoxFit.cover)
                : const Icon(Icons.image, size: 50, color: Colors.white24),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ad['is_active'] ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: ad['is_active']
                              ? Colors.greenAccent
                              : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${ad['duration']} Seconds',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
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
}

class _AdEditDialog extends StatefulWidget {
  final Map<String, dynamic>? ad;
  final VoidCallback onSave;

  const _AdEditDialog({this.ad, required this.onSave});

  @override
  State<_AdEditDialog> createState() => _AdEditDialogState();
}

class _AdEditDialogState extends State<_AdEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dataService = HODataService();
  late TextEditingController _durationController;
  bool _isActive = true;
  String? _imageUrl;
  Uint8List? _previewBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: (widget.ad?['duration'] ?? 5).toString(),
    );
    _isActive = widget.ad?['is_active'] ?? true;
    _imageUrl = widget.ad?['image_url'];
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _previewBytes = result.files.first.bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_previewBytes == null && _imageUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? finalUrl = _imageUrl;
      if (_previewBytes != null) {
        finalUrl = await _dataService.uploadAdImage(_previewBytes!, 'png');
      }

      final data = {
        'image_url': finalUrl,
        'duration': int.parse(_durationController.text),
        'is_active': _isActive,
      };

      if (widget.ad == null) {
        await _dataService.createAdvertisement(data);
      } else {
        await _dataService.updateAdvertisement(widget.ad!['id'], data);
      }

      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving advertisement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.ad == null ? 'Add Splash AD' : 'Edit Splash AD',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _isSaving ? null : _pickImage,
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      image: _previewBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_previewBytes!),
                              fit: BoxFit.contain,
                            )
                          : (_imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_imageUrl!),
                                    fit: BoxFit.contain,
                                  )
                                : null),
                    ),
                    child: (_previewBytes == null && _imageUrl == null)
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Select AD Image (Portrait recommended)',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _durationController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Display Duration (Seconds)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (int.tryParse(val) == null) return 'Must be a number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Is Active',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  activeThumbColor: HOColors.accent,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HOColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
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
}

class _IntroVideoCard extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IntroVideoCard({
    required this.video,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: video['thumbnail_url'] != null
                ? Image.network(video['thumbnail_url'], fit: BoxFit.cover)
                : const Center(
                    child: Icon(Icons.movie, size: 64, color: Colors.white24),
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        video['is_active'] ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: video['is_active']
                              ? Colors.greenAccent
                              : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (video['duration'] != null)
                        Text(
                          '${video['duration']}s',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video['video_url']?.split('/')?.last ?? 'video.mp4',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroVideoEditDialog extends StatefulWidget {
  final Map<String, dynamic>? video;
  final VoidCallback onSave;

  const _IntroVideoEditDialog({this.video, required this.onSave});

  @override
  State<_IntroVideoEditDialog> createState() => _IntroVideoEditDialogState();
}

class _IntroVideoEditDialogState extends State<_IntroVideoEditDialog> {
  final _dataService = HODataService();
  VideoPlayerController? _videoController;
  bool _isActive = true;
  String? _videoUrl;
  String? _thumbnailUrl;
  Uint8List? _videoBytes;
  Uint8List? _thumbnailBytes;
  String? _videoExtension;
  String? _thumbnailExtension;
  bool _isSaving = false;
  int? _duration;

  @override
  void initState() {
    super.initState();
    _isActive = widget.video?['is_active'] ?? true;
    _videoUrl = widget.video?['video_url'];
    _thumbnailUrl = widget.video?['thumbnail_url'];
    _duration = widget.video?['duration'];

    if (_videoUrl != null) {
      _initRemoteVideo();
    }
  }

  void _initRemoteVideo() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(_videoUrl!))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          setState(() {
            _videoBytes = bytes;
            _videoExtension = result.files.first.extension;
          });

          // Temporary file for video_player to read duration and preview
          // Since it's web/desktop dashboard, we can use networkUrl with data URI if needed
          // or blob URL if on web. But for simplicity, we'll try to get duration.
          // In some environments, initializing from bytes is tricky.
          // Let's at least show the filename.
        }
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _thumbnailBytes = result.files.first.bytes;
          _thumbnailExtension = result.files.first.extension;
        });
      }
    } catch (e) {
      debugPrint('Error picking thumbnail: $e');
    }
  }

  Future<void> _save() async {
    if (_videoBytes == null && _videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? finalVideoUrl = _videoUrl;
      if (_videoBytes != null) {
        finalVideoUrl = await _dataService.uploadIntroVideo(
          _videoBytes!,
          _videoExtension ?? 'mp4',
        );
      }

      String? finalThumbnailUrl = _thumbnailUrl;
      if (_thumbnailBytes != null) {
        finalThumbnailUrl = await _dataService.uploadIntroThumbnail(
          _thumbnailBytes!,
          _thumbnailExtension ?? 'png',
        );
      }

      final data = {
        'video_url': finalVideoUrl,
        'thumbnail_url': finalThumbnailUrl,
        'is_active': _isActive,
        'duration': _duration,
      };

      if (widget.video == null) {
        await _dataService.createIntroVideo(data);
      } else {
        await _dataService.updateIntroVideo(widget.video!['id'], data);
      }

      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving intro video: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.video == null
                      ? 'Add Welcome Video'
                      : 'Edit Welcome Video',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Video Picker/Preview
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Video File',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isSaving ? null : _pickVideo,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _videoBytes != null
                            ? Colors.blueAccent
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _videoBytes != null || _videoUrl != null
                              ? Icons.videocam
                              : Icons.video_call,
                          size: 32,
                          color: _videoBytes != null
                              ? Colors.blueAccent
                              : Colors.white54,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _videoBytes != null
                              ? 'New Video Selected: ${_videoBytes!.lengthInBytes ~/ 1024} KB'
                              : (_videoUrl != null
                                    ? 'Existing Video Attached'
                                    : 'Select Video File (MP4)'),
                          style: TextStyle(
                            color: _videoBytes != null
                                ? Colors.blueAccent
                                : Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_videoController != null &&
                    _videoController!.value.isInitialized)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_videoController!),
                              IconButton(
                                icon: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 40,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Previewing Remote Video',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Thumbnail Picker
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Video Thumbnail',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isSaving ? null : _pickThumbnail,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      image: _thumbnailBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_thumbnailBytes!),
                              fit: BoxFit.cover,
                            )
                          : (_thumbnailUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_thumbnailUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child: (_thumbnailBytes == null && _thumbnailUrl == null)
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 32,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Select/Upload Thumbnail',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),

                // Duration Input
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Duration (Seconds)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _duration?.toString(),
                  onChanged: (val) =>
                      setState(() => _duration = int.tryParse(val)),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 5',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text(
                    'Is Active',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  activeThumbColor: Colors.blueAccent,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
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
}
