import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tasks_page.dart';
import 'sites_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  List<String> selectedSites = [];
  bool isLoading = true;

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
  }

  void _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SitesPage()),
    );

    if (result == true && mounted) {
      loadSelectedSites();
    }
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
        title: const Text("المواقع المختارة"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'الإعدادات',
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
                  const Text("لم تقم باختيار أي مواقع للعمل عليها."),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _openSettings,
                    child: const Text("اذهب للإعدادات"),
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
