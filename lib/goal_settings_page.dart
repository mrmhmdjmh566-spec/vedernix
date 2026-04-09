import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalSettingsPage extends StatefulWidget {
  const GoalSettingsPage({super.key});

  @override
  State<GoalSettingsPage> createState() => _GoalSettingsPageState();
}

class _GoalSettingsPageState extends State<GoalSettingsPage> {
  final supabase = Supabase.instance.client;

  // Controllers definition
  final TextEditingController _dailyGoalController = TextEditingController();
  final TextEditingController _monthlyGoalController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Ensure controllers are disposed
  @override
  void dispose() {
    _dailyGoalController.dispose();
    _monthlyGoalController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
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

      if (data != null && mounted) {
        setState(() {
          _dailyGoalController.text = (data['daily_goal_rubles'] ?? 100)
              .toString();
          _monthlyGoalController.text = (data['monthly_goal_rubles'] ?? 3000)
              .toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveGoals() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      if (mounted) debugPrint("Saving goals for USER ID: $userId");
      await supabase.from('user_settings').upsert({
        'user_id': userId,
        'goal_type': 'daily', // Default value
        'daily_goal_rubles': double.tryParse(_dailyGoalController.text) ?? 100,
        'monthly_goal_rubles':
            double.tryParse(_monthlyGoalController.text) ?? 3000,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Goals saved successfully')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal Settings')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _dailyGoalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Daily Goal (RUB)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _monthlyGoalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Goal (RUB)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveGoals,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}
