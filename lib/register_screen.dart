import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _siteUsernameController = TextEditingController();

  String? _selectedSite;
  XFile? _proofImage;
  bool _acceptTerms = false;
  bool _isLoading = false;

  final List<String> _sites = ['seofast', 'aviso', 'socpublic'];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _proofImage = image;
      });
    }
  }

  Future<String?> _uploadImageToSupabase(XFile image) async {
    try {
      final String fileName =
          '${const Uuid().v4()}.${image.name.split('.').last}';
      final String path = 'proof_images/$fileName';

      final bytes = await image.readAsBytes();
      await supabase.storage
          .from('proof_images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicUrl = supabase.storage
          .from('proof_images')
          .getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('general_error'.tr())));
      }
      return null;
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('fill_all_fields_error'.tr())));
      return;
    }

    if (_proofImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('image_not_selected'.tr())));
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('fill_all_fields_error'.tr())));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final imageUrl = await _uploadImageToSupabase(_proofImage!);
      if (imageUrl == null) {
        return; // Error already handled in _uploadImageToSupabase
      }

      await supabase.from('pending_users').insert({
        'email': _emailController.text.trim(),
        'password': _passwordController.text
            .trim(), // Storing plain password temporarily as per prompt
        'full_name': _fullNameController.text.trim(),
        'site_username': _siteUsernameController.text.trim(),
        'referral_site': _selectedSite!,
        'proof_image_url': imageUrl,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('register_success_message'.tr())),
        );
        Navigator.pop(context); // Go back to login or welcome page
      }
    } catch (e) {
      debugPrint('Error registering user: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('general_error'.tr())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _siteUsernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('register'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'referral_warning'.tr(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(labelText: 'full_name'.tr()),
                      validator: (value) =>
                          value!.isEmpty ? 'error_enter_name'.tr() : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'email_address'.tr(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value!.isEmpty || !value.contains('@')
                          ? 'error_valid_email'.tr()
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'password'.tr()),
                      obscureText: true,
                      validator: (value) =>
                          value!.isEmpty ? 'error_enter_password'.tr() : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _siteUsernameController,
                      decoration: InputDecoration(
                        labelText: 'site_username'.tr(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'required_field'.tr() : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedSite,
                      hint: Text('select_site'.tr()),
                      items: _sites.map((site) {
                        return DropdownMenuItem(
                          value: site,
                          child: Text(site.tr()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSite = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'required_field'.tr() : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'upload_proof_screenshot'.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    _proofImage == null
                        ? OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_file),
                            label: Text('upload_proof_screenshot'.tr()),
                          )
                        : Column(
                            children: [
                              kIsWeb
                                  ? Image.network(
                                      _proofImage!.path,
                                      height: 150,
                                    )
                                  : Image.file(
                                      File(_proofImage!.path),
                                      height: 150,
                                    ),
                              TextButton(
                                onPressed: _pickImage,
                                child: Text('change_image'.tr()),
                              ),
                            ],
                          ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (bool? newValue) {
                            setState(() {
                              _acceptTerms = newValue ?? false;
                            });
                          },
                        ),
                        Expanded(child: Text('terms_and_conditions'.tr())),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _registerUser,
                      child: Text('register'.tr()),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('already_have_account'.tr()),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
