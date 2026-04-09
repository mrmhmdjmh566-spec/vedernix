import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();

  final TextEditingController _seoFastLinkController = TextEditingController();
  final TextEditingController _avisoLinkController = TextEditingController();
  final TextEditingController _socPublicLinkController =
      TextEditingController();

  final TextEditingController _seoFastPriceController = TextEditingController();
  final TextEditingController _seoFastMaxUsersController =
      TextEditingController();

  final TextEditingController _avisoPriceController = TextEditingController();
  final TextEditingController _avisoMaxUsersController =
      TextEditingController();

  final TextEditingController _socPublicPriceController =
      TextEditingController();
  final TextEditingController _socPublicMaxUsersController =
      TextEditingController();

  bool _seoFastSelected = false;
  bool _avisoSelected = false;
  bool _socPublicSelected = false;

  XFile? _videoFile;
  bool _isUploading = false;

  final supabase = Supabase.instance.client;

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videoFile = video;
      });
    }
  }

  Future<String?> _uploadVideo() async {
    if (_videoFile == null) {
      return null;
    }

    final fileName = "video_${DateTime.now().millisecondsSinceEpoch}.mp4";
    // Read as bytes to avoid _Namespace errors
    final bytes = await _videoFile!.readAsBytes();
    await supabase.storage.from('videos').uploadBinary(fileName, bytes);
    return supabase.storage.from('videos').getPublicUrl(fileName);
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_seoFastSelected && !_avisoSelected && !_socPublicSelected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select at least one site")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final String? uploadedVideoUrl = await _uploadVideo();

      final List<dynamic> response = await supabase.from('tasks').insert([
        {
          'task_title': _titleController.text.trim(),
          'task_video_url': _videoUrlController.text.trim().isNotEmpty
              ? _videoUrlController.text.trim()
              : uploadedVideoUrl,
          'uploaded_video': uploadedVideoUrl,
          'completed_count': 0,
        },
      ]).select();

      if (response.isEmpty) {
        throw Exception('Failed to create task');
      }

      final taskId = response.first['id'];

      final List<Map<String, dynamic>> sites = [];

      if (_seoFastSelected && _seoFastLinkController.text.trim().isNotEmpty) {
        sites.add({
          'task_id': taskId,
          'site_name': 'seofast',
          'task_link': _seoFastLinkController.text.trim(),
          'price': double.tryParse(_seoFastPriceController.text.trim()) ?? 0,
          'max_users':
              int.tryParse(_seoFastMaxUsersController.text.trim()) ?? 1,
        });
      }

      if (_avisoSelected && _avisoLinkController.text.trim().isNotEmpty) {
        sites.add({
          'task_id': taskId,
          'site_name': 'aviso',
          'task_link': _avisoLinkController.text.trim(),
          'price': double.tryParse(_avisoPriceController.text.trim()) ?? 0,
          'max_users': int.tryParse(_avisoMaxUsersController.text.trim()) ?? 1,
        });
      }
      if (_socPublicSelected &&
          _socPublicLinkController.text.trim().isNotEmpty) {
        sites.add({
          'task_id': taskId,
          'site_name': 'socpublic',
          'task_link': _socPublicLinkController.text.trim(),
          'price': double.tryParse(_socPublicPriceController.text.trim()) ?? 0,
          'max_users':
              int.tryParse(_socPublicMaxUsersController.text.trim()) ?? 1,
        });
      }

      if (sites.isNotEmpty) {
        // Bulk insert sites
        await supabase.from('task_sites').insert(sites);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Task added successfully")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();

    _seoFastLinkController.dispose();
    _seoFastPriceController.dispose();
    _seoFastMaxUsersController.dispose();

    _avisoLinkController.dispose();
    _avisoPriceController.dispose();
    _avisoMaxUsersController.dispose();

    _socPublicLinkController.dispose();
    _socPublicPriceController.dispose();
    _socPublicMaxUsersController.dispose();

    super.dispose();
  }

  Widget _siteField(
    bool selected,
    TextEditingController linkController,
    TextEditingController priceController,
    TextEditingController maxUsersController,
    String siteName,
  ) {
    if (!selected) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            controller: linkController,
            decoration: InputDecoration(labelText: "Task link in $siteName"),
            validator: (v) {
              if (selected && (v == null || v.trim().isEmpty)) {
                return "$siteName link is required";
              }
              return null;
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextFormField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: "Task price in $siteName"),
            validator: (v) {
              if (!selected) {
                return null;
              }
              if (v == null || v.trim().isEmpty) {
                return "Price is required";
              }
              if (double.tryParse(v.trim()) == null ||
                  double.parse(v.trim()) <= 0) {
                return "Enter valid number";
              }
              return null;
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: maxUsersController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Allowed users in $siteName",
            ),
            validator: (v) {
              if (!selected) {
                return null;
              }
              if (v == null || v.trim().isEmpty) {
                return "Required field";
              }
              final parsed = int.tryParse(v.trim());
              if (parsed == null || parsed <= 0) {
                return "Must be > 0";
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Task")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Task Title"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Title required" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _videoUrlController,
              decoration: const InputDecoration(
                labelText: "Video link (Optional)",
              ),
            ),
            const SizedBox(height: 15),
            ListTile(
              title: Text(
                _videoFile == null
                    ? "Upload Tutorial Video"
                    : "Video Selected ✓",
              ),
              trailing: Icon(Icons.video_library, color: Colors.orange[400]),
              onTap: _pickVideo,
            ),
            const SizedBox(height: 20),
            const Text(
              "Select Sites",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              value: _seoFastSelected,
              activeColor: Colors.orange[400],
              title: const Text("SEO Fast"),
              onChanged: (v) => setState(() => _seoFastSelected = v ?? false),
            ),
            _siteField(
              _seoFastSelected,
              _seoFastLinkController,
              _seoFastPriceController,
              _seoFastMaxUsersController,
              "SEO Fast",
            ),
            CheckboxListTile(
              value: _avisoSelected,
              activeColor: Colors.orange[400],
              title: const Text("Aviso"),
              onChanged: (v) => setState(() => _avisoSelected = v ?? false),
            ),
            _siteField(
              _avisoSelected,
              _avisoLinkController,
              _avisoPriceController,
              _avisoMaxUsersController,
              "Aviso",
            ),
            CheckboxListTile(
              value: _socPublicSelected,
              activeColor: Colors.orange[400],
              title: const Text("SocPublic"),
              onChanged: (v) => setState(() => _socPublicSelected = v ?? false),
            ),
            _siteField(
              _socPublicSelected,
              _socPublicLinkController,
              _socPublicPriceController,
              _socPublicMaxUsersController,
              "SocPublic",
            ),
            const SizedBox(height: 30),
            _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.orange[600],
                    ),
                    onPressed: _submitTask,
                    child: const Text("Submit Task"),
                  ),
          ],
        ),
      ),
    );
  }
}
