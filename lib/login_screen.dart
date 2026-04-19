import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vedernix/home_screen.dart';

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
        // Check user's account status
        final userId = response.user!.id;
        final userData = await supabase
            .from('user_settings')
            .select('account_status')
            .eq('user_id', userId)
            .maybeSingle();

        final String accountStatus = userData?['account_status'] ?? 'pending';

        if (mounted) {
          if (accountStatus == 'approved') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else if (accountStatus == 'pending') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('account_under_review'.tr())),
            );
            await supabase.auth.signOut(); // Sign out the user if not approved
          } else if (accountStatus == 'rejected') {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('account_rejected'.tr())));
            await supabase.auth.signOut(); // Sign out the user if rejected
          }
        }
      }
    } on AuthException catch (e) {
      debugPrint('Login error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('general_error'.tr())));
      }
    } catch (e) {
      debugPrint('Login error: $e');
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('login'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      child: Text('login'.tr()),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot-password');
                      },
                      child: Text('forgot_password'.tr()),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text('dont_have_account'.tr()),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
