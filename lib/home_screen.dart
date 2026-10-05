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

  double? dailyGoal;
  String? userName;

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
        final lang = data['language_code'].toString();

        debugPrint("Loaded language: $lang");

        if (!mounted) return;
        await context.setLocale(Locale(lang));
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  Future<void> loadHomeData() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception("User not logged in");
      }

      final settingsData = await supabase
          .from('user_settings')
          .select('sites, daily_goal_rubles')
          .eq('user_id', userId)
          .maybeSingle();

      double? loadedGoal;

      if (settingsData != null && settingsData['daily_goal_rubles'] != null) {
        loadedGoal = double.tryParse(
          settingsData['daily_goal_rubles'].toString(),
        );
      }

      List<String> loadedSites = [];

      if (settingsData != null && settingsData['sites'] != null) {
        loadedSites = List<String>.from(settingsData['sites']);
      }

      String? loadedName;

      try {
        final profileData = await supabase
            .from('profiles')
            .select('name, full_name')
            .eq('id', userId)
            .maybeSingle();

        if (profileData != null) {
          final fullName = profileData['full_name']?.toString().trim();

          final name = profileData['name']?.toString().trim();

          if (fullName != null && fullName.isNotEmpty) {
            loadedName = fullName;
          } else if (name != null && name.isNotEmpty) {
            loadedName = name;
          }
        }
      } catch (e) {
        debugPrint('Error loading profile name: $e');
      }

      if (mounted) {
        setState(() {
          selectedSites = loadedSites;
          dailyGoal = loadedGoal;
          userName = loadedName;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading your home data: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    loadHomeData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadUserLanguage(context);
    });
  }

  Future<void> _refreshHome() async {
    await loadHomeData();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserSettingsMainPage(),
      ),
    ).then((_) {
      if (mounted) {
        loadHomeData();
      }
    });
  }

  void _openTasks(String siteName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TasksPage(
          siteName: siteName.toLowerCase(),
        ),
      ),
    );
  }

  String _formatSiteName(String siteName) {
    switch (siteName.toLowerCase()) {
      case 'seofast':
        return 'SEO Fast';

      case 'aviso':
        return 'Aviso';

      case 'socpublic':
        return 'SocPublic';

      case 'unu':
        return 'Unu';

      case 'ipweb':
        return 'IPWeb';

      case 'taskpay':
        return 'Taskpay';

      case 'fastsmm':
        return 'FastSMM';

      case 'profittask':
        return 'Profittask';

      case 'wmrfast':
        return 'WMRFast';

      default:
        return siteName;
    }
  }

  IconData _siteIcon(String siteName) {
    switch (siteName.toLowerCase()) {
      case 'seofast':
        return Icons.search_rounded;

      case 'aviso':
        return Icons.campaign_rounded;

      case 'socpublic':
        return Icons.public_rounded;

      case 'unu':
        return Icons.language_rounded;

      case 'ipweb':
        return Icons.web_rounded;

      case 'taskpay':
        return Icons.payments_outlined;

      case 'fastsmm':
        return Icons.speed_rounded;

      case 'profittask':
        return Icons.task_alt_rounded;

      case 'wmrfast':
        return Icons.flash_on_rounded;

      default:
        return Icons.language_rounded;
    }
  }

  Widget _buildTopHeader() {
    final displayName =
        userName?.trim().isNotEmpty == true ? userName!.trim() : 'there';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171717),
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Ready to complete your tasks?',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openSettings,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Color(0xFF242424),
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard() {
    final goal = dailyGoal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF3EC),
            Color(0xFFFFE5D6),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD4BD),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A3D).withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFFE85D24),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Daily Goal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF252525),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _openSettings,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFFE85D24),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                goal != null
                    ? goal.toStringAsFixed(
                        goal.truncateToDouble() == goal ? 0 : 2,
                      )
                    : '—',
                style: const TextStyle(
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF191919),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'RUB / day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF777777),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(0.75),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE85D24),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            goal != null
                ? 'Start completing tasks to work toward your daily goal.'
                : 'Set your daily goal to start planning your tasks.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF777777),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D1D1D),
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE85D24),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
            ),
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSiteCard(String siteName) {
    final formattedName = _formatSiteName(siteName);

    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () => _openTasks(siteName),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        _siteIcon(siteName),
                        color: const Color(0xFFE85D24),
                        size: 21,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                      color: Color(0xFF8C8C8C),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(
                  formattedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'View available tasks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSitesSection() {
    if (selectedSites.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.language_rounded,
                color: Color(0xFFE85D24),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No sites selected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose the task sites you want to work with.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85D24),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Choose Sites',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 153,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: selectedSites.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return _buildSiteCard(
            selectedSites[index],
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAction(
            icon: Icons.task_alt_rounded,
            title: 'Tasks',
            subtitle: 'Browse tasks',
            onTap: () {
              if (selectedSites.isNotEmpty) {
                _openTasks(selectedSites.first);
              } else {
                _openSettings();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickAction(
            icon: Icons.tune_rounded,
            title: 'Goal',
            subtitle: 'Manage goal',
            onTap: _openSettings,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFE85D24),
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE85D24),
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFFE85D24),
                onRefresh: _refreshHome,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    32,
                  ),
                  children: [
                    _buildTopHeader(),
                    const SizedBox(height: 24),
                    _buildGoalCard(),
                    const SizedBox(height: 27),
                    _buildSectionHeader(
                      title: 'Your Sites',
                      actionText: 'Manage',
                      onAction: _openSettings,
                    ),
                    const SizedBox(height: 13),
                    _buildSitesSection(),
                    const SizedBox(height: 27),
                    _buildSectionHeader(
                      title: 'Quick Access',
                    ),
                    const SizedBox(height: 13),
                    _buildQuickActions(),
                    const SizedBox(height: 27),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 43,
                            height: 43,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0E8),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFE85D24),
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your tasks are based on your settings',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choose your sites and daily goal to organize the tasks shown to you.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
