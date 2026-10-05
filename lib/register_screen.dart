import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  final String? userType;

  const RegisterScreen({
    super.key,
    this.userType,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final Map<String, TextEditingController> _siteControllers = {};

  final List<String> _selectedSites = [];

  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _sites = [
    'seofast',
    'aviso',
    'socpublic',
    'unu',
    'ipweb',
    'taskpay',
    'fastsmm',
    'profittask',
    'wmrfast',
  ];

  final Map<String, String> _siteDisplayNames = {
    'seofast': 'SEO Fast',
    'aviso': 'Aviso',
    'socpublic': 'SocPublic',
    'unu': 'Unu',
    'ipweb': 'IPWeb',
    'taskpay': 'Taskpay',
    'fastsmm': 'FastSMM',
    'profittask': 'Profittask',
    'wmrfast': 'WMRFast',
  };

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    for (final controller in _siteControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _registerUser() async {
    if (_isLoading) return;

    try {
      if (!_formKey.currentState!.validate()) {
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        throw Exception('passwords_do_not_match'.tr());
      }

      if (!_acceptTerms) {
        throw Exception('please_accept_terms'.tr());
      }

      if (widget.userType != 'advertiser' && _selectedSites.isEmpty) {
        throw Exception('select_site'.tr());
      }

      setState(() {
        _isLoading = true;
      });

      final Map<String, String> siteUsernamesMapping = {};

      for (final site in _selectedSites) {
        final controller = _siteControllers[site];

        if (controller != null) {
          siteUsernamesMapping[site] = controller.text.trim();
        }
      }

      debugPrint(
        'REGISTRATION_FLOW: Starting Auth signUp for email: '
        '${_emailController.text.trim()}',
      );

      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _fullNameController.text.trim(),
        },
      );

      if (res.user == null) {
        throw Exception(
          'Registration failed: Auth user returned is null.',
        );
      }

      final String userId = res.user!.id;

      debugPrint(
        'REGISTRATION_FLOW: Auth success. UserID: $userId',
      );

      if (widget.userType == 'advertiser') {
        debugPrint(
          'PROFILE_SYNC: Upserting advertiser profile for $userId',
        );

        await supabase.from('profiles').upsert({
          'id': userId,
          'email': _emailController.text.trim(),
          'full_name': _fullNameController.text.trim(),
          'role': 'advertiser',
          'status': 'approved',
          'is_verified': true,
          'site_usernames': {
            'advertiser': _usernameController.text.trim(),
          },
        });

        debugPrint(
          'PROFILE_SYNC: Advertiser profile successfully synchronized.',
        );
      } else {
        debugPrint(
          'PROFILE_SYNC: Upserting regular user profile for $userId',
        );

        await supabase.from('profiles').upsert({
          'id': userId,
          'email': _emailController.text.trim(),
          'full_name': _fullNameController.text.trim(),
          'site_usernames': siteUsernamesMapping,
          'status': 'pending',
          'role': 'user',
        });

        debugPrint(
          'PROFILE_SYNC: User profile successfully synchronized.',
        );
      }

      if (!mounted) return;

      final String message = widget.userType == 'advertiser'
          ? 'Registration successful!'
          : 'register_success_message'.tr();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF171717),
        ),
      );

      Navigator.pop(context);
    } on AuthException catch (e) {
      debugPrint('AUTH REGISTRATION ERROR: ${e.message}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } on Exception catch (e) {
      debugPrint('REGISTRATION VALIDATION ERROR: $e');

      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      debugPrint('REGISTRATION ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSite(String site, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedSites.contains(site)) {
          _selectedSites.add(site);
        }

        _siteControllers[site] ??= TextEditingController();
      } else {
        _selectedSites.remove(site);

        final controller = _siteControllers.remove(site);
        controller?.dispose();
      }
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF171717),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF777777),
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFE85D24),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE7E7E7),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE7E7E7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE85D24),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red.shade300,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red.shade400,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildSiteSelector(String site) {
    final bool selected = _selectedSites.contains(site);
    final String displayName = _siteDisplayNames[site] ?? site;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF1EA) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFFE85D24) : const Color(0xFFE7E7E7),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) {
          _toggleSite(site, value ?? false);
        },
        activeColor: const Color(0xFFE85D24),
        checkColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: const Color(0xFF171717),
            fontSize: 15,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          selected
              ? 'Username will be saved for this site'
              : 'Select if you work on this site',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSiteUsernameField(String site) {
    final controller = _siteControllers[site];

    if (controller == null) {
      return const SizedBox.shrink();
    }

    final String displayName = _siteDisplayNames[site] ?? site;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildTextField(
        controller: controller,
        label: '$displayName Username',
        icon: Icons.person_outline_rounded,
        validator: (value) {
          if (_selectedSites.contains(site) &&
              (value == null || value.trim().isEmpty)) {
            return 'required_field'.tr();
          }

          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdvertiser = widget.userType == 'advertiser';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 620,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEE6),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Color(0xFFE85D24),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create your account',
                                style: TextStyle(
                                  color: Color(0xFF171717),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAdvertiser
                                    ? 'Create your advertiser account'
                                    : 'Create your Vedernix worker account',
                                style: const TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Main card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE9E9E9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isAdvertiser) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4EF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFD8C8),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFFE85D24),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'referral_warning'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFF7A3B20),
                                        fontSize: 13,
                                        height: 1.45,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildTextField(
                            controller: _fullNameController,
                            label: 'full_name'.tr(),
                            icon: Icons.badge_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'error_enter_name'.tr();
                              }
                              return null;
                            },
                          ),
                          if (isAdvertiser) ...[
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Username',
                              icon: Icons.alternate_email_rounded,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'required_field'.tr();
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _emailController,
                            label: 'email_address'.tr(),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty ||
                                  !value.contains('@')) {
                                return 'error_valid_email'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'password'.tr(),
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF888888),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'error_enter_password'.tr();
                              }

                              if (value.length < 6) {
                                return 'Password must contain at least 6 characters';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'confirm_password'.tr(),
                            icon: Icons.lock_reset_outlined,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF888888),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'error_confirm_password'.tr();
                              }
                              return null;
                            },
                          ),
                          if (!isAdvertiser) ...[
                            const SizedBox(height: 26),
                            const Text(
                              'Choose the sites you work on',
                              style: TextStyle(
                                color: Color(0xFF171717),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Select your sites and enter the username you use on each one.',
                              style: TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._sites.map(
                              _buildSiteSelector,
                            ),
                            if (_selectedSites.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFEAEAEA),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Site usernames',
                                      style: TextStyle(
                                        color: Color(0xFF171717),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ..._selectedSites.map(
                                      _buildSiteUsernameField,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 18),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _acceptTerms = !_acceptTerms;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _acceptTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptTerms = value ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFFE85D24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 12,
                                      ),
                                      child: Text(
                                        'terms_and_conditions'.tr(),
                                        style: const TextStyle(
                                          color: Color(0xFF555555),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _registerUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE85D24),
                                disabledBackgroundColor:
                                    const Color(0xFFF2B49A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'register'.tr(),
                                          style: const TextStyle(
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

                    const SizedBox(height: 18),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      child: Text(
                        'already_have_account'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFE85D24),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
