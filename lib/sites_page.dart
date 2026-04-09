import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SitesPage extends StatefulWidget {
  const SitesPage({super.key});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  final supabase = Supabase.instance.client;

  // المتغيرات المطلوبة للتعامل مع الأعمدة الجديدة
  double dailyGoalRubles = 100;
  double monthlyGoalRubles = 3000;
  String goalType = 'daily';

  List<Map<String, dynamic>> availableSites = [];
  List<String> selectedSites = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([loadAvailableSites(), loadUserSettings()]);

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadUserSettings() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        return;
      }

      final data = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        goalType = data['goal_type'] as String? ?? 'daily';
        dailyGoalRubles =
            (data['daily_goal_rubles'] as num?)?.toDouble() ?? 100;
        monthlyGoalRubles =
            (data['monthly_goal_rubles'] as num?)?.toDouble() ?? 3000;
        selectedSites = List<String>.from(data['sites'] ?? []);
      }
    } catch (e) {
      debugPrint('Error loading user settings: $e');
    }
  }

  Future<void> loadAvailableSites() async {
    try {
      final data = await supabase.from('sites').select();

      if (mounted) {
        setState(() {
          availableSites = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading sites: $e');
    }
  }

  Future<void> saveSettings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      final data = {
        'user_id': userId,
        'goal_type': goalType,
        'daily_goal_rubles': dailyGoalRubles,
        'monthly_goal_rubles': monthlyGoalRubles,
        'sites': selectedSites,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (mounted) debugPrint('Saving Data: $data');
      await supabase.from('user_settings').upsert(data, onConflict: 'user_id');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved successfully")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // منطق الـ Slider الديناميكي بناءً على نوع الهدف المختار
    double currentGoalValue = goalType == 'daily'
        ? dailyGoalRubles
        : monthlyGoalRubles;
    double minVal = goalType == 'daily' ? 10 : 100;
    double maxVal = goalType == 'daily' ? 100 : 3000;
    int divisions = goalType == 'daily' ? 18 : 29;

    return Scaffold(
      appBar: AppBar(title: const Text("User Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 1. Select goal type
            const Text(
              "Goal Type",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("Daily Goal"),
                    value: 'daily',
                    // ignore: deprecated_member_use
                    groupValue: goalType,
                    onChanged: (v) => setState(() => goalType = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text("Monthly Goal"),
                    value: 'monthly',
                    // ignore: deprecated_member_use
                    groupValue: goalType,
                    onChanged: (v) => setState(() => goalType = v!),
                  ),
                ),
              ],
            ),

            // 2. Dynamic Slider
            Text(
              "Goal Value (${goalType == 'daily' ? 'Daily' : 'Monthly'}): ${currentGoalValue.toStringAsFixed(0)} RUB",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: currentGoalValue,
                    min: minVal,
                    max: maxVal,
                    divisions: divisions,
                    label: currentGoalValue.toStringAsFixed(0),
                    onChanged: (v) {
                      setState(() {
                        if (goalType == 'daily') {
                          dailyGoalRubles = v;
                        } else {
                          monthlyGoalRubles = v;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Select the sites you want to work on",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...availableSites.map((site) {
              final siteName = (site['site_name'] ?? '').toString();

              // CheckboxListTile مستقل لكل عنصر
              return CheckboxListTile(
                title: Text(_formatSiteName(siteName)),
                value: selectedSites.contains(siteName),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      selectedSites.add(siteName);
                    } else {
                      selectedSites.remove(siteName);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: saveSettings,
              child: const Text("Save Settings"),
            ),
          ],
        ),
      ),
    );
  }
}
