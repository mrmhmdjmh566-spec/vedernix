import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalSettingsPage extends StatefulWidget {
  const GoalSettingsPage({super.key});

  @override
  State<GoalSettingsPage> createState() => _GoalSettingsPageState();
}

class _GoalSettingsPageState extends State<GoalSettingsPage> {
  final supabase = Supabase.instance.client;

  final TextEditingController _dailyGoalController = TextEditingController();
  final TextEditingController _monthlyGoalController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

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
          _dailyGoalController.text =
              (data['daily_goal_rubles'] ?? 100).toString();

          _monthlyGoalController.text =
              (data['monthly_goal_rubles'] ?? 3000).toString();
        });
      } else if (mounted) {
        _dailyGoalController.text = '100';
        _monthlyGoalController.text = '3000';
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');

      if (mounted) {
        _dailyGoalController.text = '100';
        _monthlyGoalController.text = '3000';
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveGoals() async {
    if (isSaving) return;

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to save your goals.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final dailyGoal = double.tryParse(_dailyGoalController.text.trim());
    final monthlyGoal = double.tryParse(_monthlyGoalController.text.trim());

    if (dailyGoal == null || dailyGoal <= 0) {
      _showError('Please enter a valid daily goal.');
      return;
    }

    if (monthlyGoal == null || monthlyGoal <= 0) {
      _showError('Please enter a valid monthly goal.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      debugPrint('Saving goals for USER ID: $userId');

      await supabase.from('user_settings').upsert(
        {
          'user_id': userId,
          'goal_type': 'daily',
          'daily_goal_rubles': dailyGoal,
          'monthly_goal_rubles': monthlyGoal,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goals saved successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2E7D32),
          margin: EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB42318),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB42318),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 850,
                ),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE85D24),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          35,
                        ),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 28),
                          _buildIntroCard(),
                          const SizedBox(height: 20),
                          _buildGoalsCard(),
                          const SizedBox(height: 20),
                          _buildSaveButton(),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF222222),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(
                color: Color(0xFFEAEAEA),
              ),
            ),
          ),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9DE),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.track_changes_rounded,
            color: Color(0xFFE85D24),
            size: 25,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goal Settings',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171717),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Set your daily and monthly earning targets',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF777777),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF3EC),
            Color(0xFFFFE7D9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD7C4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Color(0xFFE85D24),
              size: 25,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your earning targets',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF171717),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Choose realistic targets to keep track of your progress.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earning goals',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Amounts are stored in RUB.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 22),
          _buildGoalField(
            controller: _dailyGoalController,
            label: 'Daily Goal',
            hint: '100',
            icon: Icons.today_rounded,
          ),
          const SizedBox(height: 16),
          _buildGoalField(
            controller: _monthlyGoalController,
            label: 'Monthly Goal',
            hint: '3000',
            icon: Icons.calendar_month_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF171717),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFE85D24),
                size: 20,
              ),
            ),
            suffixText: 'RUB',
            suffixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF777777),
            ),
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFFE6E6E6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFFE6E6E6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFFE85D24),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveGoals,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE85D24),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFFFB89A),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 21,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
