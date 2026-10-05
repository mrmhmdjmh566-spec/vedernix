import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_task_page.dart';

class AdvertiserDashboard extends StatefulWidget {
  const AdvertiserDashboard({super.key});

  @override
  State<AdvertiserDashboard> createState() => _AdvertiserDashboardState();
}

class _AdvertiserDashboardState extends State<AdvertiserDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  int _tasksCreated = 0;
  int _activeTasks = 0;
  int _completedTasks = 0;
  int _tasksCreatedToday = 0;

  double _totalTaskValue = 0;
  final Set<String> _sitesUsed = {};

  List<Map<String, dynamic>> _recentTasks = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No authenticated advertiser found.');
      }

      final response = await supabase
          .from('tasks')
          .select(
            'id, task_title, completed_count, is_active, created_at',
          )
          .eq('advertiser_id', user.id)
          .order('created_at', ascending: false);

      final tasks = List<Map<String, dynamic>>.from(response);

      int activeCount = 0;
      int completedCount = 0;
      int createdToday = 0;

      final now = DateTime.now();
      final startOfToday = DateTime(
        now.year,
        now.month,
        now.day,
      );

      for (final task in tasks) {
        final isActive = task['is_active'] == true;

        if (isActive) {
          activeCount++;
        }

        final completed = _toInt(task['completed_count']);

        completedCount += completed;

        final createdAt = _parseDate(task['created_at']);

        if (createdAt != null && !createdAt.isBefore(startOfToday)) {
          createdToday++;
        }
      }

      double totalTaskValue = 0;
      final Set<String> sitesUsed = {};

      if (tasks.isNotEmpty) {
        final taskIds =
            tasks.map((task) => task['id']).where((id) => id != null).toList();

        if (taskIds.isNotEmpty) {
          final taskSitesResponse = await supabase
              .from('task_sites')
              .select('task_id, site_name, price, max_users')
              .inFilter('task_id', taskIds);

          final taskSites = List<Map<String, dynamic>>.from(taskSitesResponse);

          for (final site in taskSites) {
            final siteName = (site['site_name'] ?? '').toString().trim();

            if (siteName.isNotEmpty) {
              sitesUsed.add(siteName);
            }

            final price = _toDouble(site['price']);
            final maxUsers = _toInt(site['max_users']);

            totalTaskValue += price * maxUsers;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _tasksCreated = tasks.length;
        _activeTasks = activeCount;
        _completedTasks = completedCount;
        _tasksCreatedToday = createdToday;
        _totalTaskValue = totalTaskValue;
        _sitesUsed
          ..clear()
          ..addAll(sitesUsed);
        _recentTasks = tasks.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(e);
      });
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('advertiser_id')) {
      return 'The advertiser ownership field is not available yet. '
          'Please make sure the latest Supabase changes were applied.';
    }

    if (message.contains('task_sites')) {
      return 'Unable to load task site information.';
    }

    return 'Unable to load your dashboard right now.';
  }

  Future<void> _openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTaskPage(),
      ),
    );

    if (mounted) {
      _loadDashboard();
    }
  }

  void _openProfile() {
    Navigator.pushNamed(context, '/profile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE85D24),
          onRefresh: _loadDashboard,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : 20,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1180,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 28),
                        _buildWelcomeSection(isDesktop),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          _buildLoadingState()
                        else if (_errorMessage != null)
                          _buildErrorState()
                        else ...[
                          _buildStatsSection(isDesktop),
                          const SizedBox(height: 24),
                          _buildTaskOverview(isDesktop),
                          const SizedBox(height: 24),
                          _buildSitesSection(),
                          const SizedBox(height: 24),
                          _buildRecentTasksSection(),
                          const SizedBox(height: 24),
                          _buildQuickActions(isDesktop),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E8),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFFFD9C5),
            ),
          ),
          child: const Icon(
            Icons.campaign_rounded,
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
                'Vedernix',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF171717),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Advertiser workspace',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF777777),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: _openProfile,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF333333),
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 26 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD8C5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Advertiser Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF171717),
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Track your tasks, activity, reach and task value '
                  'from one simple workspace.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 20),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFFFD8C5),
                ),
              ),
              child: const Icon(
                Icons.dashboard_customize_rounded,
                color: Color(0xFFE85D24),
                size: 34,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isDesktop) {
    final cards = [
      _StatData(
        icon: Icons.task_alt_rounded,
        title: 'Tasks created',
        value: _tasksCreated.toString(),
        subtitle: 'Total tasks',
      ),
      _StatData(
        icon: Icons.playlist_play_rounded,
        title: 'Active tasks',
        value: _activeTasks.toString(),
        subtitle: 'Currently active',
      ),
      _StatData(
        icon: Icons.check_circle_outline_rounded,
        title: 'Completed',
        value: _completedTasks.toString(),
        subtitle: 'Total executions',
      ),
      _StatData(
        icon: Icons.today_rounded,
        title: 'Created today',
        value: _tasksCreatedToday.toString(),
        subtitle: 'New today',
      ),
    ];

    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.45,
        ),
        itemBuilder: (context, index) {
          return _buildStatCard(cards[index]);
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.28,
      ),
      itemBuilder: (context, index) {
        return _buildStatCard(cards[index]);
      },
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              data.icon,
              color: const Color(0xFFE85D24),
              size: 21,
            ),
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Color(0xFF171717),
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskOverview(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    Icons.payments_outlined,
                    'Task value',
                    '${_formatMoney(_totalTaskValue)} ₽',
                    'Current task capacity value',
                  ),
                ),
                Container(
                  width: 1,
                  height: 65,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _buildOverviewItem(
                    Icons.language_rounded,
                    'Sites used',
                    _sitesUsed.length.toString(),
                    _sitesUsed.isEmpty
                        ? 'No sites yet'
                        : 'Connected task sites',
                  ),
                ),
                Container(
                  width: 1,
                  height: 65,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _buildOverviewItem(
                    Icons.insights_rounded,
                    'Completion activity',
                    _completedTasks.toString(),
                    'Recorded task executions',
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildOverviewItem(
                  Icons.payments_outlined,
                  'Task value',
                  '${_formatMoney(_totalTaskValue)} ₽',
                  'Current task capacity value',
                ),
                const SizedBox(height: 18),
                Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 18),
                _buildOverviewItem(
                  Icons.language_rounded,
                  'Sites used',
                  _sitesUsed.length.toString(),
                  _sitesUsed.isEmpty ? 'No sites yet' : 'Connected task sites',
                ),
                const SizedBox(height: 18),
                Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 18),
                _buildOverviewItem(
                  Icons.insights_rounded,
                  'Completion activity',
                  _completedTasks.toString(),
                  'Recorded task executions',
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewItem(
    IconData icon,
    String title,
    String value,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF171717),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSitesSection() {
    final sites = _sitesUsed.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sites used',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF171717),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sites currently connected to your tasks.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          if (sites.isEmpty)
            _buildEmptyInline(
              Icons.language_outlined,
              'No sites used yet.',
            )
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: sites.map((site) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD8C5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        size: 15,
                        color: Color(0xFFE85D24),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _prettySiteName(site),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent tasks',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF171717),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openAddTask,
                icon: const Icon(
                  Icons.add,
                  size: 17,
                ),
                label: const Text(
                  'Add task',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE85D24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Your latest advertiser tasks.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 15),
          if (_recentTasks.isEmpty)
            _buildEmptyTasks()
          else
            Column(
              children: [
                for (int i = 0; i < _recentTasks.length; i++) ...[
                  _buildTaskRow(_recentTasks[i]),
                  if (i != _recentTasks.length - 1)
                    Divider(
                      height: 22,
                      color: Colors.grey.shade200,
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task) {
    final title = (task['task_title'] ?? 'Untitled task').toString();

    final isActive = task['is_active'] == true;
    final completed = _toInt(task['completed_count']);

    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFF0E8) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            isActive
                ? Icons.playlist_play_rounded
                : Icons.pause_circle_outline_rounded,
            color: isActive ? const Color(0xFFE85D24) : const Color(0xFF888888),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$completed completions',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEAF8EF) : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color:
                  isActive ? const Color(0xFF277A45) : const Color(0xFF777777),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTasks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 38,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Create your first task to start reaching users.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _openAddTask,
            icon: const Icon(
              Icons.add,
              size: 18,
            ),
            label: const Text(
              'Create task',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85D24),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInline(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade400,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF171717),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 13),
        isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.add_task_rounded,
                      title: 'Add task',
                      subtitle: 'Create a new task for users.',
                      onTap: _openAddTask,
                      primary: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.refresh_rounded,
                      title: 'Refresh dashboard',
                      subtitle: 'Load the latest advertiser data.',
                      onTap: _loadDashboard,
                      primary: false,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildActionCard(
                    icon: Icons.add_task_rounded,
                    title: 'Add task',
                    subtitle: 'Create a new task for users.',
                    onTap: _openAddTask,
                    primary: true,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.refresh_rounded,
                    title: 'Refresh dashboard',
                    subtitle: 'Load the latest advertiser data.',
                    onTap: _loadDashboard,
                    primary: false,
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: primary ? const Color(0xFFFFD5C1) : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary
                      ? const Color(0xFFFFF0E8)
                      : const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: primary
                      ? const Color(0xFFE85D24)
                      : const Color(0xFF555555),
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202020),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: primary ? const Color(0xFFE85D24) : Colors.grey.shade500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 70,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFE85D24),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading your dashboard...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFD5C5),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFE85D24),
              size: 28,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Dashboard data could not be loaded',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _errorMessage ?? 'Unknown error.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),
            label: const Text(
              'Try again',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85D24),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _prettySiteName(String value) {
    final normalized = value.trim().toLowerCase();

    switch (normalized) {
      case 'seofast':
      case 'seo fast':
        return 'SEOFast';

      case 'aviso':
        return 'Aviso';

      case 'socpublic':
      case 'soc public':
        return 'SocPublic';

      default:
        if (value.isEmpty) {
          return value;
        }

        return value
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }
}

class _StatData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _StatData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });
}
