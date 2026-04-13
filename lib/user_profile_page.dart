import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final supabase = Supabase.instance.client;

  Future<void> changeLanguage(Locale locale) async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final existing = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('user_settings').insert({
          'user_id': user.id,
          'language_code': locale.languageCode,
        });
      } else {
        await supabase
            .from('user_settings')
            .update({'language_code': locale.languageCode})
            .eq('user_id', user.id);
      }

      if (mounted) {
        await context.setLocale(locale);
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("profile".tr())),
      body: Column(
        children: [
          ListTile(
            title: const Text("🇪🇬 العربية"),
            onTap: () => changeLanguage(const Locale('ar')),
          ),
          ListTile(
            title: const Text("🇺🇸 English"),
            onTap: () => changeLanguage(const Locale('en')),
          ),
          ListTile(
            title: const Text("🇷🇺 Русский"),
            onTap: () => changeLanguage(const Locale('ru')),
          ),
        ],
      ),
    );
  }
}
