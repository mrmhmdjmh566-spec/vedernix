import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tasks_page.dart';
import 'user_settings_main_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  List<String> selectedSites = [];
  bool isLoading = true;

  Future<void> loadUserLanguage(BuildContext context) async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final data = await supabase
          .from('user_settings')
          .select('language_code')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && data['language_code'] != null) {
        final lang = data['language_code'];
        debugPrint("Loaded language: $lang");
        if (mounted) {
          await context.setLocale(Locale(lang));
        }
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  Future<void> loadSelectedSites() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("User not logged in");
      }

      final data = await supabase
          .from('user_settings')
          .select('sites')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (data != null && data['sites'] != null) {
            selectedSites = List<String>.from(data['sites']);
          } else {
            selectedSites = [];
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user sites: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading your sites: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    loadSelectedSites();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadUserLanguage(context);
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSettingsMainPage()),
    ).then((_) {
      if (mounted) loadSelectedSites();
    });
  }

  String _formatSiteName(String siteName) {
    switch (siteName.toLowerCase()) {
      case 'seofast':
        return 'SEO Fast';
      case 'aviso':
        return 'Aviso';
      case 'socpublic':
        return 'SocPublic';
      default:
        return siteName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("sites_settings".tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSettingsMainPage()),
              ).then((_) => loadSelectedSites());
            },
            tooltip: 'settings'.tr(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : selectedSites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("no_sites_currently".tr()),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _openSettings,
                    child: Text("settings".tr()),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadSelectedSites,
              child: ListView.builder(
                itemCount: selectedSites.length,
                itemBuilder: (context, index) {
                  final siteName = selectedSites[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: ListTile(
                      title: Text(_formatSiteName(siteName)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TasksPage(siteName: siteName.toLowerCase()),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
