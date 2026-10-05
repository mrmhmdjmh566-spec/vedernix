import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_settings_main_page.dart';

class TasksPage extends StatefulWidget {
  final String siteName;

  const TasksPage({
    super.key,
    required this.siteName,
  });

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  String goalType = 'daily';
  double goalValue = 100;

  bool _executingTask = false;

  String get normalizedSiteName => widget.siteName.trim().toLowerCase();

  String get displaySiteName {
    switch (normalizedSiteName) {
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
        return widget.siteName;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      await Future.wait([
        _fetchSettings(),
        _fetchTasks(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        return;
      }

      final data = await supabase
          .from('user_settings')
          .select(
            'goal_type, daily_goal_rubles, monthly_goal_rubles',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          goalType = data['goal_type'] ?? 'daily';

          if (goalType == 'daily') {
            goalValue = (data['daily_goal_rubles'] as num?)?.toDouble() ?? 100;
          } else {
            goalValue =
                (data['monthly_goal_rubles'] as num?)?.toDouble() ?? 3000;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
  }

  Map<String, dynamic>? _extractTaskData(dynamic rawTasks) {
    if (rawTasks is Map) {
      return Map<String, dynamic>.from(rawTasks);
    }

    if (rawTasks is List && rawTasks.isNotEmpty) {
      final first = rawTasks.first;

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return null;
  }

  Future<void> _fetchTasks() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        if (mounted) {
          setState(() {
            tasks = [];
          });
        }
        return;
      }

      final siteName = normalizedSiteName;

      debugPrint('----------------------------------------');
      debugPrint('FETCHING TASKS');
      debugPrint('Original site: "${widget.siteName}"');
      debugPrint('Normalized site: "$siteName"');
      debugPrint('User ID: $userId');

      /*
       * We only load active task offers for this specific site.
       *
       * IMPORTANT:
       * We intentionally do NOT use tasks.completed_count here
       * to determine whether this site has reached its limit.
       *
       * The actual per-site capacity is checked atomically by
       * the Supabase claim_task RPC.
       */
      final data = await supabase
          .from('task_sites')
          .select('*, tasks!inner(*)')
          .eq('site_name', siteName)
          .eq('tasks.is_active', true);

      debugPrint('Fetched task_sites count: ${data.length}');

      final completedData = await supabase
          .from('completed_tasks')
          .select('task_id, site_name')
          .eq('user_id', userId)
          .eq('site_name', siteName);

      final completedTaskIds = (completedData as List)
          .map((e) => e['task_id'])
          .where((id) => id != null)
          .toSet();

      final List<Map<String, dynamic>> filteredTasks = [];

      for (final item in data) {
        final taskData = _extractTaskData(item['tasks']);

        if (taskData == null) {
          continue;
        }

        final taskId = taskData['id'];

        if (taskId == null) {
          continue;
        }

        /*
         * Hide tasks already completed by this user on this site.
         * Capacity is NOT checked here because claim_task does that
         * safely inside the database.
         */
        if (completedTaskIds.contains(taskId)) {
          continue;
        }

        final int maxUsers = (item['max_users'] as num?)?.toInt() ?? 1;

        /*
         * Ignore invalid offers.
         */
        if (maxUsers <= 0) {
          continue;
        }

        filteredTasks.add(
          Map<String, dynamic>.from(item),
        );
      }

      debugPrint(
        'FINAL AVAILABLE TASKS FOR "$siteName": ${filteredTasks.length}',
      );

      if (mounted) {
        setState(() {
          tasks = filteredTasks;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching tasks: $e');
      debugPrint('StackTrace: $stackTrace');

      if (mounted) {
        setState(() {
          tasks = [];
        });
      }
    }
  }

  Future<bool> _openLink(String url) async {
    if (url.trim().isEmpty) {
      return false;
    }

    try {
      final Uri? uri = Uri.tryParse(url.trim());

      if (uri == null || !uri.isAbsolute) {
        if (mounted) {
          _showMessage(
            'The task link is not valid.',
            isError: true,
          );
        }
        return false;
      }

      final canOpen = await canLaunchUrl(uri);

      if (!canOpen) {
        if (mounted) {
          _showMessage(
            'Unable to open the task link.',
            isError: true,
          );
        }
        return false;
      }

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      return true;
    } catch (e) {
      debugPrint('Error opening task link: $e');

      if (mounted) {
        _showMessage(
          'Unable to open the task link.',
          isError: true,
        );
      }

      return false;
    }
  }

  Future<void> _openVideo(String url) async {
    if (url.trim().isEmpty) {
      return;
    }

    final Uri? uri = Uri.tryParse(url.trim());

    if (uri == null || !uri.isAbsolute) {
      if (mounted) {
        _showMessage(
          'The video link is not valid.',
          isError: true,
        );
      }
      return;
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error opening video: $e');

      if (mounted) {
        _showMessage(
          'Unable to open the video.',
          isError: true,
        );
      }
    }
  }

  Future<void> _executeTask(
    Map<String, dynamic> item,
  ) async {
    if (_executingTask) {
      return;
    }

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      _showMessage(
        'You must be logged in to execute a task.',
        isError: true,
      );
      return;
    }

    final taskData = _extractTaskData(item['tasks']);

    if (taskData == null) {
      _showMessage(
        'Task data is unavailable.',
        isError: true,
      );
      return;
    }

    final taskId = taskData['id'];

    if (taskId == null) {
      _showMessage(
        'Task ID is unavailable.',
        isError: true,
      );
      return;
    }

    final String taskLink = (item['task_link'] ?? '').toString().trim();

    if (taskLink.isEmpty) {
      _showMessage(
        'This task does not have a valid task link.',
        isError: true,
      );
      return;
    }

    if (mounted) {
      setState(() {
        _executingTask = true;
      });
    }

    try {
      /*
       * The database RPC is the source of truth.
       *
       * It checks:
       * - authentication
       * - site offer existence
       * - task active status
       * - duplicate completion
       * - per-site capacity
       * - atomic insertion
       */
      final response = await supabase.rpc(
        'claim_task',
        params: {
          'p_task_id': taskId,
          'p_site_name': normalizedSiteName,
        },
      );

      final Map<String, dynamic> result =
          response is Map ? Map<String, dynamic>.from(response) : {};

      final bool success = result['success'] == true;

      final String status = (result['status'] ?? '').toString();

      debugPrint(
        'claim_task response: $result',
      );

      if (!success) {
        switch (status) {
          case 'already_completed':
            _showMessage(
              'You have already completed this task on this site.',
              isError: true,
            );
            break;

          case 'capacity_reached':
            _showMessage(
              'This task has reached its user limit on this site.',
              isError: true,
            );
            break;

          case 'task_inactive':
            _showMessage(
              'This task is no longer active.',
              isError: true,
            );
            break;

          case 'site_offer_not_found':
            _showMessage(
              'This task is not available on this site.',
              isError: true,
            );
            break;

          case 'not_authenticated':
            _showMessage(
              'Your session has expired. Please log in again.',
              isError: true,
            );
            break;

          default:
            _showMessage(
              'The task could not be claimed. Please try again.',
              isError: true,
            );
        }

        await _loadData();
        return;
      }

      /*
       * Important:
       * The completion is already safely recorded by the RPC.
       * Only after a successful claim do we open the advertiser link.
       */
      await _openLink(taskLink);

      if (!mounted) {
        return;
      }

      await _loadData();

      if (mounted) {
        _showMessage(
          'Task completed successfully.',
          isError: false,
        );
      }
    } catch (e) {
      debugPrint('Error executing task: $e');

      if (mounted) {
        _showMessage(
          'Unable to execute this task. Please try again.',
          isError: true,
        );

        await _loadData();
      }
    } finally {
      if (mounted) {
        setState(() {
          _executingTask = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? const Color(0xFFB42318) : const Color(0xFF2E7D32),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9DE),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: Color(0xFFE85D24),
            size: 25,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displaySiteName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF171717),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'tasks'.tr(),
                style: const TextStyle(
                  color: Color(0xFF858585),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserSettingsMainPage(),
                ),
              ).then((_) => _loadData());
            },
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.settings_outlined,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
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
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: Color(0xFFE85D24),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goalType == 'daily' ? 'Daily goal' : 'Monthly goal',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${goalValue.toStringAsFixed(0)} RUB',
                  style: const TextStyle(
                    color: Color(0xFF171717),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFAAAAAA),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    Map<String, dynamic> item,
  ) {
    final taskData = _extractTaskData(item['tasks']);

    if (taskData == null) {
      return const SizedBox.shrink();
    }

    final String title = (taskData['task_title'] ?? 'New Task').toString();

    final int maxUsers = (item['max_users'] as num?)?.toInt() ?? 1;

    final double reward = (item['price'] as num?)?.toDouble() ?? 0.0;

    final String videoUrl = (taskData['task_video_url'] ?? '').toString();

    final bool hasVideo = videoUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF171717),
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${reward.toStringAsFixed(2)} RUB',
                  style: const TextStyle(
                    color: Color(0xFFE85D24),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          /*
           * This is intentionally NOT:
           * completedCount / maxUsers
           *
           * because completed_count belongs to the whole task,
           * while max_users belongs to this site's offer.
           */
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFEDEDED),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  size: 18,
                  color: Color(0xFF777777),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Up to $maxUsers users on this site',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.verified_outlined,
                  size: 17,
                  color: Color(0xFF5F9E68),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: Color(0xFFE85D24),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Availability is checked automatically when you execute the task.',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (hasVideo)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _executingTask ? null : () => _openVideo(videoUrl),
                    icon: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 19,
                    ),
                    label: const Text(
                      'Watch video',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85D24),
                      disabledForegroundColor: const Color(0xFFBBBBBB),
                      side: const BorderSide(
                        color: Color(0xFFFFD3C0),
                      ),
                      backgroundColor: const Color(0xFFFFFAF7),
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasVideo) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _executingTask ? null : () => _executeTask(item),
                  icon: _executingTask
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _executingTask ? 'Processing...' : 'Execute task',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE85D24),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFF1B89D),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEE6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                color: Color(0xFFE85D24),
                size: 37,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'no_tasks_found'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF171717),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'There are no available tasks for this site right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF858585),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
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
            final bool isDesktop = constraints.maxWidth >= 900;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1050,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 28 : 20,
                        18,
                        isDesktop ? 28 : 20,
                        12,
                      ),
                      child: _buildHeader(),
                    ),
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE85D24),
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFFE85D24),
                              onRefresh: _loadData,
                              child: tasks.isEmpty
                                  ? ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        SizedBox(
                                          height: MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.55,
                                          child: _buildEmptyState(),
                                        ),
                                      ],
                                    )
                                  : ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(
                                        isDesktop ? 28 : 20,
                                        4,
                                        isDesktop ? 28 : 20,
                                        30,
                                      ),
                                      children: [
                                        _buildGoalCard(),
                                        const SizedBox(
                                          height: 27,
                                        ),
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Available tasks',
                                                style: TextStyle(
                                                  color: Color(
                                                    0xFF171717,
                                                  ),
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${tasks.length}',
                                              style: const TextStyle(
                                                color: Color(
                                                  0xFFE85D24,
                                                ),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                          height: 14,
                                        ),
                                        ...tasks.map(
                                          _buildTaskCard,
                                        ),
                                      ],
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
