import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _orange = Color(0xFFE85D24);
const Color _background = Color(0xFFF9F9F9);

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

      if (mounted) {
        setState(() {
          isAdmin =
              profile?['role']?.toString().toLowerCase() == 'admin';
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
        backgroundColor: _background,
        body: Center(
          child: CircularProgressIndicator(color: _orange),
        ),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 48, color: _orange),
                SizedBox(height: 16),
                Text(
                  'Access denied',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This page is available to administrators only.',
                  textAlign: TextAlign.center,
                ),
              ],
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
  int pendingUsers = 0;
  int totalTasks = 0;
  int activeTasks = 0;
  int completedToday = 0;
  int workingUsersToday = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day)
          .toUtc()
          .toIso8601String();

      final results = await Future.wait([
        supabase.from('profiles').select('id, created_at'),
        supabase
            .from('profiles')
            .select('id')
            .eq('role', 'user')
            .eq('status', 'pending'),
        supabase
            .from('tasks')
            .select('id, is_active'),
        supabase
            .from('completed_tasks')
            .select('id, user_id')
            .gte('executed_at', startOfToday),
      ]);

      final profiles = List<Map<String, dynamic>>.from(results[0] as List);
      final pending = results[1] as List;
      final tasks = List<Map<String, dynamic>>.from(results[2] as List);
      final completed = List<Map<String, dynamic>>.from(results[3] as List);

      int todayCount = 0;
      for (final profile in profiles) {
        final created = DateTime.tryParse(
          profile['created_at']?.toString() ?? '',
        );
        if (created != null &&
            !created.toUtc().isBefore(DateTime.parse(startOfToday))) {
          todayCount++;
        }
      }

      final workingUsers = completed
          .map((row) => row['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      if (mounted) {
        setState(() {
          registeredToday = todayCount;
          pendingUsers = pending.length;
          totalTasks = tasks.length;
          activeTasks = tasks.where((task) => task['is_active'] == true).length;
          completedToday = completed.length;
          workingUsersToday = workingUsers.length;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_DASHBOARD_ERROR: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _statCard(String title, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _orange, size: 25),
          const SizedBox(height: 16),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _orange,
          onRefresh: _loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1250),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vedernix Admin',
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF171717),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text('Monitor users and platform activity.'),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _loadDashboard,
                          icon: const Icon(Icons.refresh_rounded, color: _orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(50),
                          child: CircularProgressIndicator(color: _orange),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 850 ? 4 : 2;
                          return GridView.count(
                            crossAxisCount: columns,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.5,
                            children: [
                              _statCard('Registered today', registeredToday,
                                  Icons.person_add_alt_1_rounded),
                              _statCard('Working users today', workingUsersToday,
                                  Icons.work_outline_rounded),
                              _statCard('Total tasks', totalTasks,
                                  Icons.layers_outlined),
                              _statCard('Active tasks', activeTasks,
                                  Icons.play_circle_outline_rounded),
                              _statCard('Completed today', completedToday,
                                  Icons.task_alt_rounded),
                              _statCard('Pending registrations', pendingUsers,
                                  Icons.pending_actions_rounded),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 30),
                    const Text(
                      'Pending registrations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$pendingUsers users waiting for review',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),
                    const _PendingUsersList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingUsersList extends StatefulWidget {
  const _PendingUsersList();

  @override
  State<_PendingUsersList> createState() => _PendingUsersListState();
}

class _PendingUsersListState extends State<_PendingUsersList> {
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
    if (mounted) setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('profiles')
          .select(
            'id, full_name, email, site_usernames, site_referrers, '
            'status, created_at, role',
          )
          .eq('role', 'user')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          users = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_PENDING_USERS_ERROR: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  String _siteLabel(String key) {
    switch (key.toLowerCase().replaceAll('.', '').replaceAll('-', '')) {
      case 'seofast':
        return 'SEOFast';
      case 'aviso':
        return 'Aviso';
      case 'socpublic':
        return 'SocPublic';
      case 'unu':
        return 'UNU';
      case 'ipweb':
        return 'IPweb';
      case 'taskpay':
        return 'Taskpay';
      case 'fastsmm':
        return 'FastSMM.ru';
      case 'profittask':
        return 'ProfitTask';
      case 'wmrfast':
        return 'WMRFast';
      default:
        return key;
    }
  }

  List<Map<String, dynamic>> get filteredUsers {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return users;

    return users.where((user) {
      final name = user['full_name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Unknown date';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approveUser(Map<String, dynamic> user) async {
    await _updateStatus(user: user, status: 'approved');
  }

  Future<void> _rejectUser(Map<String, dynamic> user) async {
    String selectedReason = 'User did not register through referral link.';
    final customController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Reject registration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: 'User did not register through referral link.',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  title: const Text('Referral requirement not met'),
                ),
                RadioListTile<String>(
                  value: 'Invalid site usernames.',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  title: const Text('Invalid site usernames'),
                ),
                RadioListTile<String>(
                  value: 'Incomplete information.',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  title: const Text('Incomplete information'),
                ),
                RadioListTile<String>(
                  value: 'custom',
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  title: const Text('Custom reason'),
                ),
                if (selectedReason == 'custom')
                  TextField(
                    controller: customController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter rejection reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD64545),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final result = selectedReason == 'custom'
                    ? customController.text.trim()
                    : selectedReason;
                if (result.isNotEmpty && result != 'custom') {
                  Navigator.pop(dialogContext, result);
                }
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );

    customController.dispose();

    if (reason == null || reason.trim().isEmpty) return;
    await _updateStatus(user: user, status: 'rejected', reason: reason);
  }

  Future<void> _updateStatus({
    required Map<String, dynamic> user,
    required String status,
    String? reason,
  }) async {
    final userId = user['id']?.toString();
    final email = user['email']?.toString();

    if (userId == null) return;

    try {
      await supabase
          .from('profiles')
          .update({'status': status})
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
          debugPrint('ADMIN_EMAIL_ERROR: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        users.removeWhere((item) => item['id']?.toString() == userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'User approved successfully.'
                : 'User rejected successfully.',
          ),
          backgroundColor:
              status == 'approved' ? const Color(0xFF18A66A) : const Color(0xFFD64545),
        ),
      );
    } catch (e) {
      debugPrint('ADMIN_STATUS_UPDATE_ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update user status: $e'),
            backgroundColor: const Color(0xFFD64545),
          ),
        );
      }
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['full_name']?.toString().trim() ?? '';
    final email = user['email']?.toString().trim() ?? '';
    final usernames = _asMap(user['site_usernames']);
    final referrers = _asMap(user['site_referrers']);

    final siteKeys = <String>{
      ...usernames.keys.map((key) => key.toString()),
      ...referrers.keys.map((key) => key.toString()),
    }.toList()
      ..sort();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _orange,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unnamed user' : name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isEmpty ? 'No email' : email,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _orange,
                  ),
                ),
              ),
            ],
          ),
          if (siteKeys.isNotEmpty) ...[
            const SizedBox(height: 17),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Site accounts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF303030),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...siteKeys.map((siteKey) {
                    final username =
                        usernames[siteKey]?.toString().trim() ?? '';
                    final referrer =
                        referrers[siteKey]?.toString().trim() ?? '';

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.language_rounded,
                                size: 16,
                                color: _orange,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  _siteLabel(siteKey),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _detailLine(
                            'Username',
                            username.isEmpty ? 'Not provided' : username,
                          ),
                          const SizedBox(height: 5),
                          _detailLine(
                            'Referrer Username',
                            referrer.isEmpty ? 'Not provided' : referrer,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            const Text(
              'No site account details were saved for this user.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectUser(user),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD64545),
                    side: const BorderSide(color: Color(0xFFF0B8B8)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveUser(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No pending registrations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            searchQuery.isEmpty
                ? 'New user registrations will appear here.'
                : 'No users match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search_rounded, color: _orange),
              suffixIcon: IconButton(
                onPressed: _loadPendingUsers,
                icon: const Icon(Icons.refresh_rounded),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(45),
            child: Center(
              child: CircularProgressIndicator(color: _orange),
            ),
          )
        else if (filteredUsers.isEmpty)
          _emptyState()
        else
          ...filteredUsers.map(_buildUserCard),
      ],
    );
  }
}