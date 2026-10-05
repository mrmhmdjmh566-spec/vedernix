import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'advertiser_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final String? userType;

  const LoginScreen({super.key, this.userType});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        final userId = response.user!.id;

        debugPrint(
          'LOGIN_FLOW: User authenticated. ID: $userId. Fetching profile status...',
        );

        final profile = await supabase
            .from('profiles')
            .select('status, role')
            .eq('id', userId)
            .maybeSingle();

        if (profile == null) {
          debugPrint(
            'LOGIN_FLOW_ERROR: Profile record missing for authenticated user $userId',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'User profile not found. Please contact support or try registering again.',
                ),
              ),
            );
          }

          await supabase.auth.signOut();
          return;
        }

        final String status = profile['status'] ?? 'pending';
        final String role = profile['role'] ?? 'user';

        debugPrint(
          'LOGIN_FLOW: User status: $status, role: $role',
        );

        if (mounted) {
          if (status == 'approved') {
            if (role == 'advertiser') {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const AdvertiserDashboard(),
                ),
                (route) => false,
              );
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
                (route) => false,
              );
            }
          } else if (status == 'pending') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('account_under_review'.tr()),
              ),
            );

            await supabase.auth.signOut();
          } else if (status == 'rejected') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('account_rejected'.tr()),
              ),
            );

            await supabase.auth.signOut();
          } else if (status == 'banned') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account has been banned.'),
                backgroundColor: Colors.red,
              ),
            );

            await supabase.auth.signOut();
          }
        }
      }
    } on AuthException catch (e) {
      debugPrint('Login error: ${e.message}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('general_error'.tr()),
          ),
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('general_error'.tr()),
          ),
        );
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(userType: widget.userType),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.pushNamed(
      context,
      '/forgot-password',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
                maxWidth: 480,
              ),
              child: Column(
                children: [
                  _buildTopBrand(),
                  const SizedBox(height: 28),
                  _buildLoginCard(size),
                  const SizedBox(height: 22),
                  _buildRegisterPrompt(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBrand() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFFD9C5),
            ),
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: Color(0xFFE85D24),
            size: 34,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Vedernix',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Color(0xFF171717),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(Size size) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        24,
        22,
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign in',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Color(0xFF171717),
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Enter your account details to continue.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 25),
            _buildFieldLabel('Email address'),
            const SizedBox(height: 8),
            _buildEmailField(),
            const SizedBox(height: 17),
            _buildFieldLabel('Password'),
            const SizedBox(height: 8),
            _buildPasswordField(),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE85D24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  'forgot_password'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF292929),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [
        AutofillHints.email,
      ],
      decoration: _inputDecoration(
        hintText: 'email_address'.tr(),
        icon: Icons.email_outlined,
      ),
      validator: (value) {
        final email = value?.trim() ?? '';

        if (email.isEmpty || !email.contains('@')) {
          return 'error_valid_email'.tr();
        }

        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [
        AutofillHints.password,
      ],
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          _login();
        }
      },
      decoration: _inputDecoration(
        hintText: 'password'.tr(),
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          splashRadius: 20,
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: Colors.grey.shade600,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'error_enter_password'.tr();
        }

        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: Colors.grey.shade600,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
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
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE85D24),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFFFB99A),
          disabledForegroundColor: Colors.white,
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
                  strokeWidth: 2.3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'login'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRegisterPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFFE85D24),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'dont_have_account'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _openRegister,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE85D24),
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 5,
              ),
            ),
            child: const Text(
              'Register',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
