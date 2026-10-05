import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isCheckingAccess = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            isAdmin = false;
            isCheckingAccess = false;
          });
        }
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = profile?['role']?.toString().toLowerCase();

      if (mounted) {
        setState(() {
          isAdmin = role == 'admin';
          isCheckingAccess = false;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_ACCESS_ERROR: $e');

      if (mounted) {
        setState(() {
          isAdmin = false;
          isCheckingAccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F9F9),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE85D24),
          ),
        ),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFE85D24),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Access denied',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This page is available to administrators only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
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

    return const _AdminDashboard();
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard();

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;

  int registeredToday = 0;
  int workingUsersToday = 0;
  int tasksCreatedToday = 0;
  int completedTasksToday = 0;
  int totalTasks = 0;
  int activeTasks = 0;
  int pendingUsers = 0;

  double completedValueToday = 0;
  double totalTaskValue = 0;

  bool visitTrackingAvailable = false;
  bool onlineTrackingAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final startIso = startOfToday.toUtc().toIso8601String();

      await Future.wait([
        _loadUserStats(startIso),
        _loadTaskStats(startIso),
        _loadPendingUsers(),
      ]);
    } catch (e) {
      debugPrint('ADMIN_DASHBOARD_ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserStats(String startIso) async {
    try {
      final profiles = await supabase
          .from('profiles')
          .select('id, role, status, created_at');

      final rows = List<Map<String, dynamic>>.from(profiles);

      int todayRegistered = 0;

      final Set<String> workingUsers = {};

      for (final profile in rows) {
        final createdAt = profile['created_at']?.toString();

        if (createdAt != null) {
          final parsed = DateTime.tryParse(createdAt);

          if (parsed != null && parsed.toUtc().isAfter(DateTime.parse(startIso))) {
            todayRegistered++;
          }
        }
      }

      try {
        final completedToday = await supabase
            .from('completed_tasks')
            .select('user_id')
            .gte('executed_at', startIso);

        for (final row in completedToday) {
          final userId = row['user_id']?.toString();

          if (userId != null && userId.isNotEmpty) {
            workingUsers.add(userId);
          }
        }
      } catch (e) {
        debugPrint(
          'ADMIN_WORKING_USERS_ERROR: $e',
        );
      }

      if (mounted) {
        setState(() {
          registeredToday = todayRegistered;
          workingUsersToday = workingUsers.length;

          // These are intentionally false because the current schema
          // does not contain visit/session/presence tracking.
          visitTrackingAvailable = false;
          onlineTrackingAvailable = false;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_USER_STATS_ERROR: $e');
    }
  }

  Future<void> _loadPendingUsers() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'user')
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          pendingUsers = response.length;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_PENDING_COUNT_ERROR: $e');
    }
  }

  Future<void> _loadTaskStats(String startIso) async {
    try {
      final tasksResponse = await supabase
          .from('tasks')
          .select(
            'id, task_title, completed_count, is_active, created_at',
          );

      final tasks = List<Map<String, dynamic>>.from(tasksResponse);

      int todayCreated = 0;
      int active = 0;
      int completedTotal = 0;

      for (final task in tasks) {
        if (task['is_active'] == true) {
          active++;
        }

        completedTotal +=
            (task['completed_count'] as num?)?.toInt() ?? 0;

        final createdAt = task['created_at']?.toString();

        if (createdAt != null) {
          final parsed = DateTime.tryParse(createdAt);

          if (parsed != null &&
              parsed.toUtc().isAfter(DateTime.parse(startIso))) {
            todayCreated++;
          }
        }
      }

      double allTaskValue = 0;

      try {
        final taskSites = await supabase
            .from('task_sites')
            .select('task_id, price, max_users');

        for (final row in taskSites) {
          final price =
              (row['price'] as num?)?.toDouble() ?? 0;

          final maxUsers =
              (row['max_users'] as num?)?.toInt() ?? 0;

          allTaskValue += price * maxUsers;
        }
      } catch (e) {
        debugPrint('ADMIN_TASK_VALUE_ERROR: $e');
      }

      double completedTodayValue = 0;

      try {
        final completedRows = await supabase
            .from('completed_tasks')
            .select('task_id, site_name, executed_at')
            .gte('executed_at', startIso);

        if (completedRows.isNotEmpty) {
          final taskIds = completedRows
              .map((row) => row['task_id'])
              .where((id) => id != null)
              .toSet()
              .toList();

          if (taskIds.isNotEmpty) {
            final taskSites = await supabase
                .from('task_sites')
                .select(
                  'task_id, site_name, price',
                )
                .inFilter('task_id', taskIds);

            for (final completed in completedRows) {
              final completedTaskId = completed['task_id'];
              final completedSite =
                  completed['site_name']?.toString().toLowerCase();

              for (final site in taskSites) {
                final siteTaskId = site['task_id'];
                final siteName =
                    site['site_name']?.toString().toLowerCase();

                if (siteTaskId == completedTaskId &&
                    siteName == completedSite) {
                  completedTodayValue +=
                      (site['price'] as num?)?.toDouble() ?? 0;
                  break;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint(
          'ADMIN_COMPLETED_VALUE_ERROR: $e',
        );
      }

      int completedTodayCount = 0;

      try {
        final completedRows = await supabase
            .from('completed_tasks')
            .select('id')
            .gte('executed_at', startIso);

        completedTodayCount = completedRows.length;
      } catch (e) {
        debugPrint(
          'ADMIN_COMPLETED_COUNT_ERROR: $e',
        );
      }

      if (mounted) {
        setState(() {
          totalTasks = tasks.length;
          tasksCreatedToday = todayCreated;
          activeTasks = active;
          completedTasksToday = completedTodayCount;
          completedValueToday = completedTodayValue;
          totalTaskValue = allTaskValue;

          // Kept for future display/debugging if needed.
          completedTotal = completedTotal;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_TASK_STATS_ERROR: $e');
    }
  }

  String _formatRubles(double value) {
    return '${value.toStringAsFixed(2)} ₽';
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
                  horizontal: isDesktop ? 36 : 20,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1250,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        if (isLoading)
                          _buildLoading()
                        else
                          _buildDashboard(isDesktop),
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

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vedernix Admin',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171717),
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Monitor users, tasks, activity and platform value.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: _loadDashboard,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFFE85D24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 80,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE85D24),
        ),
      ),
    );
  }

  Widget _buildDashboard(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Overview',
          'Live numbers available from Supabase',
        ),
        const SizedBox(height: 13),
        _buildStatsGrid(isDesktop),

        const SizedBox(height: 30),

        _sectionTitle(
          'Task activity',
          'Current task inventory and completed value',
        ),
        const SizedBox(height: 13),
        _buildTaskOverview(isDesktop),

        const SizedBox(height: 30),

        _sectionTitle(
          'User activity',
          'Registration and working-user information',
        ),
        const SizedBox(height: 13),
        _buildUserOverview(isDesktop),

        const SizedBox(height: 30),

        _sectionTitle(
          'Pending registrations',
          pendingUsers == 0
              ? 'No pending registrations'
              : '$pendingUsers users waiting for review',
        ),
        const SizedBox(height: 13),
        const _PendingUsersList(),

        const SizedBox(height: 30),

        _buildTrackingNotice(),
      ],
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171717),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDesktop) {
    final cards = [
      _StatData(
        title: 'Registered today',
        value: '$registeredToday',
        icon: Icons.person_add_alt_1_rounded,
        accent: const Color(0xFFE85D24),
      ),
      _StatData(
        title: 'Working users today',
        value: '$workingUsersToday',
        icon: Icons.work_outline_rounded,
        accent: const Color(0xFF3D7EFF),
      ),
      _StatData(
        title: 'Tasks created today',
        value: '$tasksCreatedToday',
        icon: Icons.add_task_rounded,
        accent: const Color(0xFF7B61FF),
      ),
      _StatData(
        title: 'Completed today',
        value: '$completedTasksToday',
        icon: Icons.task_alt_rounded,
        accent: const Color(0xFF18A66A),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(
              child: _buildStatCard(cards[i]),
            ),
            if (i != cards.length - 1)
              const SizedBox(width: 14),
          ],
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
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
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: data.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              data.icon,
              color: data.accent,
              size: 22,
            ),
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskOverview(bool isDesktop) {
    final cards = [
      _InfoCardData(
        title: 'Total tasks',
        value: '$totalTasks',
        subtitle: 'All task records',
        icon: Icons.layers_outlined,
      ),
      _InfoCardData(
        title: 'Active tasks',
        value: '$activeTasks',
        subtitle: 'Currently available',
        icon: Icons.play_circle_outline_rounded,
      ),
      _InfoCardData(
        title: 'Completed value today',
        value: _formatRubles(completedValueToday),
        subtitle: 'Value of completed work',
        icon: Icons.payments_outlined,
      ),
      _InfoCardData(
        title: 'Total task capacity',
        value: _formatRubles(totalTaskValue),
        subtitle: 'Price × allowed users',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(
              child: _buildInfoCard(cards[i]),
            ),
            if (i != cards.length - 1)
              const SizedBox(width: 14),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          _buildInfoCard(cards[i]),
          if (i != cards.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildInfoCard(_InfoCardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFFE85D24),
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF303030),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF171717),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
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

  Widget _buildUserOverview(bool isDesktop) {
    final cards = [
      _InfoCardData(
        title: 'Pending registrations',
        value: '$pendingUsers',
        subtitle: 'Waiting for admin review',
        icon: Icons.pending_actions_rounded,
      ),
      _InfoCardData(
        title: 'Working users today',
        value: '$workingUsersToday',
        subtitle: 'Users with completed work',
        icon: Icons.groups_outlined,
      ),
      _InfoCardData(
        title: 'Visits today',
        value: visitTrackingAvailable
            ? 'Tracked'
            : 'Not tracked',
        subtitle: visitTrackingAvailable
            ? 'Activity tracking enabled'
            : 'Requires visit tracking',
        icon: Icons.visibility_outlined,
      ),
      _InfoCardData(
        title: 'Online now',
        value: onlineTrackingAvailable
            ? 'Tracked'
            : 'Not tracked',
        subtitle: onlineTrackingAvailable
            ? 'Presence tracking enabled'
            : 'Requires presence tracking',
        icon: Icons.wifi_tethering_rounded,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(
              child: _buildInfoCard(cards[i]),
            ),
            if (i != cards.length - 1)
              const SizedBox(width: 14),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          _buildInfoCard(cards[i]),
          if (i != cards.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildTrackingNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFE1D1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFE85D24),
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin tracking note',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4B3024),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Registration, task creation and task completion '
                  'are available from the current database. '
                  'Exact visits and real-time online presence are '
                  'not currently stored by the existing schema, '
                  'so this dashboard does not invent those numbers.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF6E5143),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });
}

class _InfoCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _InfoCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });
}

class _PendingUsersList extends StatefulWidget {
  const _PendingUsersList();

  @override
  State<_PendingUsersList> createState() =>
      _PendingUsersListState();
}

class _PendingUsersListState
    extends State<_PendingUsersList> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String searchQuery = '';

  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  Future<void> _loadPendingUsers() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response = await supabase
          .from('profiles')
          .select(
            'id, full_name, email, site_usernames, '
            'status, created_at, role',
          )
          .eq('role', 'user')
          .eq('status', 'pending')
          .order(
            'created_at',
            ascending: false,
          );

      if (mounted) {
        setState(() {
          users = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'ADMIN_PENDING_USERS_ERROR: $e',
      );

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get filteredUsers {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return users;
    }

    return users.where((user) {
      final name =
          user['full_name']?.toString().toLowerCase() ?? '';

      final email =
          user['email']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          email.contains(query);
    }).toList();
  }

  Future<void> _approveUser(
    Map<String, dynamic> user,
  ) async {
    await _updateStatus(
      user: user,
      status: 'approved',
    );
  }

  Future<void> _rejectUser(
    Map<String, dynamic> user,
  ) async {
    String? reason;

    reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String selectedReason =
            'User did not register through referral link.';

        final customController =
            TextEditingController();

        return AlertDialog(
          title: const Text(
            'Reject registration',
          ),
          content: StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value:
                          'User did not register through referral link.',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedReason = value!;
                        });
                      },
                      title: const Text(
                        'Referral requirement not met',
                      ),
                    ),
                    RadioListTile<String>(
                      value:
                          'Invalid site usernames.',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedReason = value!;
                        });
                      },
                      title: const Text(
                        'Invalid site usernames',
                      ),
                    ),
                    RadioListTile<String>(
                      value:
                          'Incomplete information.',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedReason = value!;
                        });
                      },
                      title: const Text(
                        'Incomplete information',
                      ),
                    ),
                    RadioListTile<String>(
                      value: 'custom',
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedReason = value!;
                        });
                      },
                      title: const Text(
                        'Custom reason',
                      ),
                    ),
                    if (selectedReason == 'custom') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(
                          hintText:
                              'Enter rejection reason',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFD64545),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final result =
                    selectedReason == 'custom'
                        ? customController.text.trim()
                        : selectedReason;

                if (result.isEmpty) {
                  return;
                }

                Navigator.pop(
                  context,
                  result,
                );
              },
              child: const Text(
                'Reject',
              ),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    await _updateStatus(
      user: user,
      status: 'rejected',
      reason: reason,
    );
  }

  Future<void> _updateStatus({
    required Map<String, dynamic> user,
    required String status,
    String? reason,
  }) async {
    final userId = user['id']?.toString();
    final email = user['email']?.toString();

    if (userId == null) {
      return;
    }

    try {
      await supabase
          .from('profiles')
          .update({
        'status': status,
      })
          .eq('id', userId);

      if (email != null && email.isNotEmpty) {
        try {
          await supabase.functions.invoke(
            'send-email',
            body: {
              'email': email,
              'status': status,
              'reason': reason,
            },
          );
        } catch (e) {
          debugPrint(
            'ADMIN_EMAIL_ERROR: $e',
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        users.removeWhere(
          (item) => item['id'] == userId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'User approved successfully.'
                : 'User rejected successfully.',
          ),
          backgroundColor: status == 'approved'
              ? const Color(0xFF18A66A)
              : const Color(0xFFD64545),
        ),
      );
    } catch (e) {
      debugPrint(
        'ADMIN_STATUS_UPDATE_ERROR: $e',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update user status: $e',
            ),
            backgroundColor:
                const Color(0xFFD64545),
          ),
        );
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Unknown date';
    }

    final date =
        DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _siteUsernames(
    dynamic raw,
  ) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  String _siteLabel(String key) {
    switch (key.toLowerCase()) {
      case 'seofast':
        return 'SEO Fast';
      case 'aviso':
        return 'Aviso';
      case 'socpublic':
        return 'SocPublic';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search by name or email...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFE85D24),
              ),
              suffixIcon: IconButton(
                onPressed: _loadPendingUsers,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(45),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(21),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE85D24),
              ),
            ),
          )
        else if (filteredUsers.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: filteredUsers
                .map(_buildUserCard)
                .toList(),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
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
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: Color(0xFF777777),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No pending registrations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF202020),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            searchQuery.isEmpty
                ? 'New user registrations will appear here.'
                : 'No users match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
  ) {
    final name =
        user['full_name']?.toString().trim();

    final email =
        user['email']?.toString().trim();

    final siteUsernames =
        _siteUsernames(user['site_usernames']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFFE85D24),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name?.isNotEmpty == true
                          ? name!
                          : 'Unnamed user',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202020),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email?.isNotEmpty == true
                          ? email!
                          : 'No email',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Registered: ${_formatDate(user['created_at'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E9),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE85D24),
                  ),
                ),
              ),
            ],
          ),

          if (siteUsernames.isNotEmpty) ...[
            const SizedBox(height: 17),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Site accounts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 9),
                  ...siteUsernames.entries.map(
                    (entry) {
                      final value =
                          entry.value?.toString() ?? '';

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 7,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              size: 16,
                              color: Color(0xFFE85D24),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${_siteLabel(entry.key)}: ',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    Color(0xFF333333),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                value.isEmpty
                                    ? 'Not provided'
                                    : value,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors
                                      .grey
                                      .shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _rejectUser(user),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(0xFFD64545),
                    side: const BorderSide(
                      color: Color(0xFFF0B8B8),
                    ),
                    minimumSize:
                        const Size.fromHeight(46),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _approveUser(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFE85D24),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize:
                        const Size.fromHeight(46),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}