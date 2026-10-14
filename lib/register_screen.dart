import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Map<String, TextEditingController> _referrerControllers = {};

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

  final Map<String, String> _siteLinks = {
    'seofast': 'https://seo-fast.ru/?r=3151488',
    'aviso': 'https://aviso.bz/?r=khroba_242',
    'socpublic': 'https://socpublic.com/?i=9565193&slide=3',
    'unu': 'https://unu.im/re/4409943/work',
    'ipweb': 'https://www.ipweb.ru/?gg102001293699541602847',
    'taskpay': 'https://taskpay.ru/?ref=3430487',
    'fastsmm': 'https://fastsmm.ru/u/256455',
    'profittask': 'https://profittask.com/?from=1425298',
    'wmrfast': 'https://wmrfast.com/?r=2360765',
  };

  final Map<String, String> _siteDisplayNames = {
    'seofast': 'SEO Fast',
    'aviso': 'Aviso',
    'socpublic': 'SocPublic',
    'unu': 'UNU',
    'ipweb': 'IPweb',
    'taskpay': 'Taskpay',
    'fastsmm': 'FastSMM.ru',
    'profittask': 'ProfitTask',
    'wmrfast': 'WMRFast',
  };

  @override
  void initState() {
    super.initState();

    // Select all nine sites by default for worker registration.
    _selectedSites.addAll(_sites);

    for (final site in _sites) {
      _siteControllers[site] = TextEditingController();
      _referrerControllers[site] = TextEditingController();
    }
  }

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

    for (final controller in _referrerControllers.values) {
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

      final bool isAdvertiser = widget.userType == 'advertiser';

      if (!isAdvertiser && _selectedSites.length != _sites.length) {
        throw Exception('Please select all 9 sites and complete their details.');
      }

      setState(() {
        _isLoading = true;
      });

      final Map<String, String> siteUsernamesMapping = {};
      final Map<String, String> siteReferrersMapping = {};

      // Worker accounts must provide both usernames for every site.
      // Advertiser registration keeps its original behavior.
      if (!isAdvertiser) {
        for (final site in _sites) {
          final username = _siteControllers[site]?.text.trim() ?? '';
          final referrer = _referrerControllers[site]?.text.trim() ?? '';

          if (username.isEmpty || referrer.isEmpty) {
            throw Exception(
              'Enter both username and referrer username for every site.',
            );
          }

          siteUsernamesMapping[site] = username;
          siteReferrersMapping[site] = referrer;
        }
      }

      debugPrint(
        'REGISTRATION_FLOW: Starting Auth signUp for email: '
        '${_emailController.text.trim()}',
      );

      final Map<String, dynamic> authMetadata = {
        'full_name': _fullNameController.text.trim(),
      };

      if (!isAdvertiser) {
        // Referrer usernames are stored in Supabase Auth user metadata.
        authMetadata['site_referrers'] = siteReferrersMapping;
      }

      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: authMetadata,
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

      if (isAdvertiser) {
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

      final String message = isAdvertiser
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
        _referrerControllers[site] ??= TextEditingController();
      } else {
        _selectedSites.remove(site);

        final controller = _siteControllers.remove(site);
        controller?.dispose();

        final referrerController = _referrerControllers.remove(site);
        referrerController?.dispose();
      }
    });
  }

  Future<void> _openSite(String site) async {
    final String? link = _siteLinks[site];

    if (link == null) return;

    final Uri uri = Uri.parse(link);

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this website.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this website.'),
        ),
      );
    }
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

  Widget _buildLinksSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: Color(0xFFE85D24),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Links',
                style: TextStyle(
                  color: Color(0xFF171717),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Open each website and enter the username and referrer username '
            'for your account below. These links are provided for account '
            'registration. Any benefits depend on each platform’s own terms.',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          ..._sites.map(
            (site) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openSite(site),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 17,
                          color: Color(0xFFE85D24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _siteDisplayNames[site] ?? site,
                            style: const TextStyle(
                              color: Color(0xFF171717),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF888888),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
        color: selected
            ? const Color(0xFFFFF1EA)
            : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? const Color(0xFFE85D24)
              : const Color(0xFFE7E7E7),
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
              ? 'Username and referrer username are required'
              : 'Select this site',
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
            return 'Enter your username for $displayName';
          }

          return null;
        },
      ),
    );
  }

  Widget _buildSiteReferrerField(String site) {
    final controller = _referrerControllers[site];

    if (controller == null) {
      return const SizedBox.shrink();
    }

    final String displayName = _siteDisplayNames[site] ?? site;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildTextField(
        controller: controller,
        label: '$displayName Referrer Username',
        icon: Icons.group_outlined,
        validator: (value) {
          if (_selectedSites.contains(site) &&
              (value == null || value.trim().isEmpty)) {
            return 'Enter the referrer username for $displayName';
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
                    // Page header.
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

                    // Main registration card.
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
                            _buildLinksSection(),
                            const SizedBox(height: 18),
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

                          // Full name.
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

                          // Advertiser username only.
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

                          // Email.
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

                          // Password.
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

                          // Confirm password.
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

                          // Worker sites and account details.
                          if (!isAdvertiser) ...[
                            const SizedBox(height: 26),
                            const Text(
                              'Choose all 9 sites',
                              style: TextStyle(
                                color: Color(0xFF171717),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'All nine sites are required. Enter the username '
                              'and referrer username you use on each site.',
                              style: TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),

                            ..._sites.map(_buildSiteSelector),

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
                                      'Site usernames and referrers',
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
                                    ..._selectedSites.map(
                                      _buildSiteReferrerField,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],

                          const SizedBox(height: 18),

                          // Terms checkbox.
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
                                      padding: const EdgeInsets.only(top: 12),
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

                          // Register button.
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