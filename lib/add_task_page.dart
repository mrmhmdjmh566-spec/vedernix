import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _SiteDraft {
  final String key;
  final String name;
  final String subtitle;
  final IconData icon;

  bool selected = false;

  final TextEditingController linkController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController maxUsersController = TextEditingController();

  _SiteDraft({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  void dispose() {
    linkController.dispose();
    priceController.dispose();
    maxUsersController.dispose();
  }
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();

  final supabase = Supabase.instance.client;

  late final List<_SiteDraft> _sites;

  XFile? _videoFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();

    _sites = [
      _SiteDraft(
        key: 'seofast',
        name: 'SEO Fast',
        subtitle: 'Configure the SEO Fast task offer',
        icon: Icons.search_rounded,
      ),
      _SiteDraft(
        key: 'aviso',
        name: 'Aviso',
        subtitle: 'Configure the Aviso task offer',
        icon: Icons.storefront_outlined,
      ),
      _SiteDraft(
        key: 'socpublic',
        name: 'SocPublic',
        subtitle: 'Configure the SocPublic task offer',
        icon: Icons.public_rounded,
      ),
      _SiteDraft(
        key: 'unu',
        name: 'Unu',
        subtitle: 'Configure the Unu task offer',
        icon: Icons.language_rounded,
      ),
      _SiteDraft(
        key: 'ipweb',
        name: 'IPWeb',
        subtitle: 'Configure the IPWeb task offer',
        icon: Icons.web_rounded,
      ),
      _SiteDraft(
        key: 'taskpay',
        name: 'Taskpay',
        subtitle: 'Configure the Taskpay task offer',
        icon: Icons.payments_outlined,
      ),
      _SiteDraft(
        key: 'fastsmm',
        name: 'FastSMM',
        subtitle: 'Configure the FastSMM task offer',
        icon: Icons.speed_rounded,
      ),
      _SiteDraft(
        key: 'profittask',
        name: 'Profittask',
        subtitle: 'Configure the Profittask task offer',
        icon: Icons.trending_up_rounded,
      ),
      _SiteDraft(
        key: 'wmrfast',
        name: 'WMRFast',
        subtitle: 'Configure the WMRFast task offer',
        icon: Icons.flash_on_rounded,
      ),
    ];
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();

    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video != null && mounted) {
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

    final bytes = await _videoFile!.readAsBytes();

    await supabase.storage.from('videos').uploadBinary(
          fileName,
          bytes,
        );

    return supabase.storage.from('videos').getPublicUrl(fileName);
  }

  String _normalizedTitle(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Future<bool> _advertiserAlreadyHasTask({
    required String advertiserId,
    required String title,
  }) async {
    final normalizedTitle = _normalizedTitle(title);

    final response = await supabase
        .from('tasks')
        .select('id, task_title')
        .eq('advertiser_id', advertiserId);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.any(
      (row) =>
          _normalizedTitle(
            (row['task_title'] ?? '').toString(),
          ) ==
          normalizedTitle,
    );
  }

  bool _hasSelectedSite() {
    return _sites.any((site) => site.selected);
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasSelectedSite()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select at least one site"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must be logged in to create a task"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();

    setState(() {
      _isUploading = true;
    });

    try {
      /*
       * Check before uploading the video.
       *
       * The database also has a unique constraint on:
       * advertiser_id + normalized task title.
       *
       * This check gives the advertiser a friendly message instead
       * of allowing the task creation process to continue.
       */
      final alreadyExists = await _advertiserAlreadyHasTask(
        advertiserId: currentUser.id,
        title: title,
      );

      if (alreadyExists) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "You have already created a task with this title.",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      final String? uploadedVideoUrl = await _uploadVideo();

      final taskVideoUrl = _videoUrlController.text.trim().isNotEmpty
          ? _videoUrlController.text.trim()
          : uploadedVideoUrl;

      final List<dynamic> response = await supabase.from('tasks').insert([
        {
          'task_title': title,
          'task_video_url': taskVideoUrl,
          'uploaded_video': uploadedVideoUrl,
          'completed_count': 0,
          'advertiser_id': currentUser.id,
        },
      ]).select();

      if (response.isEmpty) {
        throw Exception('Failed to create task');
      }

      final taskId = response.first['id'];

      final List<Map<String, dynamic>> siteRows = [];

      for (final site in _sites) {
        if (!site.selected) {
          continue;
        }

        final link = site.linkController.text.trim();

        if (link.isEmpty) {
          continue;
        }

        final price = double.tryParse(site.priceController.text.trim()) ?? 0;

        final maxUsers = int.tryParse(site.maxUsersController.text.trim()) ?? 1;

        siteRows.add({
          'task_id': taskId,
          'site_name': site.key,
          'task_link': link,
          'price': price,
          'max_users': maxUsers,
        });
      }

      if (siteRows.isEmpty) {
        throw Exception('At least one valid site offer is required');
      }

      await supabase.from('task_sites').insert(siteRows);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Task added successfully"),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (!mounted) {
        return;
      }

      /*
       * PostgreSQL unique violation.
       *
       * This is also protected at database level, so even if two
       * requests happen at nearly the same time, the same advertiser
       * cannot create the same task twice.
       */
      if (e.code == '23505') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "You have already created this task.",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.isNotEmpty ? e.message : "Could not create the task",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();

    for (final site in _sites) {
      site.dispose();
    }

    super.dispose();
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF171717),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: const Color(0xFF8A8A8A),
                size: 20,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF777777),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFAAAAAA),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFE9E9E9),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFE9E9E9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFE85D24),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _siteCard(_SiteDraft site) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: site.selected ? const Color(0xFFFFF4EE) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              site.selected ? const Color(0xFFE85D24) : const Color(0xFFE8E8E8),
          width: site.selected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                site.selected = !site.selected;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: site.selected
                        ? const Color(0xFFFFE5D8)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    site.icon,
                    color: site.selected
                        ? const Color(0xFFE85D24)
                        : const Color(0xFF777777),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          color: Color(0xFF171717),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        site.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF858585),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: site.selected,
                  activeColor: const Color(0xFFE85D24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (value) {
                    setState(() {
                      site.selected = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          if (site.selected) ...[
            const SizedBox(height: 16),
            _textField(
              controller: site.linkController,
              label: "Task link",
              hint: "Paste the task link for ${site.name}",
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
              validator: (v) {
                if (!site.selected) {
                  return null;
                }

                if (v == null || v.trim().isEmpty) {
                  return "${site.name} link is required";
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final priceField = _textField(
                  controller: site.priceController,
                  label: "Task price",
                  hint: "0.00",
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (!site.selected) {
                      return null;
                    }

                    if (v == null || v.trim().isEmpty) {
                      return "Price is required";
                    }

                    final value = double.tryParse(v.trim());

                    if (value == null || value <= 0) {
                      return "Enter valid number";
                    }

                    return null;
                  },
                );

                final maxUsersField = _textField(
                  controller: site.maxUsersController,
                  label: "Allowed users",
                  hint: "1",
                  icon: Icons.people_outline_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (!site.selected) {
                      return null;
                    }

                    if (v == null || v.trim().isEmpty) {
                      return "Required field";
                    }

                    final value = int.tryParse(v.trim());

                    if (value == null || value <= 0) {
                      return "Must be > 0";
                    }

                    return null;
                  },
                );

                if (constraints.maxWidth < 500) {
                  return Column(
                    children: [
                      priceField,
                      const SizedBox(height: 12),
                      maxUsersField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: priceField),
                    const SizedBox(width: 12),
                    Expanded(child: maxUsersField),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF171717),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF858585),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 900;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1050,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 28 : 20,
                        18,
                        isDesktop ? 28 : 20,
                        10,
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(context),
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Color(0xFF171717),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Create Task",
                                  style: TextStyle(
                                    color: Color(0xFF171717),
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Create a new task for Vedernix users",
                                  style: TextStyle(
                                    color: Color(0xFF858585),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE9DE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.add_task_rounded,
                              color: Color(0xFFE85D24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 28 : 20,
                            12,
                            isDesktop ? 28 : 20,
                            35,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFEAEAEA),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.035),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFFFE9DE,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.description_outlined,
                                            color: Color(
                                              0xFFE85D24,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          "Task details",
                                          style: TextStyle(
                                            color: Color(0xFF171717),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    _textField(
                                      controller: _titleController,
                                      label: "Task title",
                                      hint: "Enter a clear task title",
                                      icon: Icons.title_rounded,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return "Title required";
                                        }

                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 13),
                                    _textField(
                                      controller: _videoUrlController,
                                      label: "Tutorial video link",
                                      hint: "Optional video URL",
                                      icon: Icons.play_circle_outline_rounded,
                                      keyboardType: TextInputType.url,
                                    ),
                                    const SizedBox(height: 14),
                                    InkWell(
                                      onTap: _pickVideo,
                                      borderRadius: BorderRadius.circular(17),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: _videoFile != null
                                              ? const Color(
                                                  0xFFFFF4EE,
                                                )
                                              : const Color(
                                                  0xFFF9F9F9,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            17,
                                          ),
                                          border: Border.all(
                                            color: _videoFile != null
                                                ? const Color(
                                                    0xFFE85D24,
                                                  )
                                                : const Color(
                                                    0xFFE8E8E8,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: _videoFile != null
                                                    ? const Color(
                                                        0xFFFFE5D8,
                                                      )
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  13,
                                                ),
                                              ),
                                              child: Icon(
                                                _videoFile != null
                                                    ? Icons
                                                        .check_circle_outline_rounded
                                                    : Icons
                                                        .video_library_outlined,
                                                color: const Color(
                                                  0xFFE85D24,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 12,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _videoFile == null
                                                        ? "Upload tutorial video"
                                                        : "Tutorial video selected",
                                                    style: const TextStyle(
                                                      color: Color(
                                                        0xFF171717,
                                                      ),
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: 4,
                                                  ),
                                                  Text(
                                                    _videoFile == null
                                                        ? "Choose a video from your device"
                                                        : _videoFile!.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(
                                                        0xFF858585,
                                                      ),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(
                                                0xFF9A9A9A,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              _sectionTitle(
                                title: "Task sites",
                                subtitle:
                                    "Choose where this task will be available and configure its offer.",
                              ),
                              const SizedBox(height: 14),
                              ..._sites.map(
                                (site) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _siteCard(site),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8F4),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFFFE1D1),
                                  ),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFFE85D24),
                                      size: 21,
                                    ),
                                    SizedBox(width: 11),
                                    Expanded(
                                      child: Text(
                                        "Select at least one site. Each selected site needs its task link, price, and allowed user count. The same advertiser cannot create the same task twice.",
                                        style: TextStyle(
                                          color: Color(0xFF6E5143),
                                          fontSize: 12.5,
                                          height: 1.45,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isUploading ? null : _submitTask,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE85D24),
                                    disabledBackgroundColor:
                                        const Color(0xFFF1B69A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                  ),
                                  child: _isUploading
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 11),
                                            Text(
                                              "Creating task...",
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_task_rounded,
                                              size: 20,
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              "Create Task",
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
