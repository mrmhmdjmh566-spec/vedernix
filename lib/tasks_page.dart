import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sites_page.dart';

class TasksPage extends StatefulWidget {
  final String siteName;

  const TasksPage({super.key, required this.siteName});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  // Goal variables
  String goalType = 'daily';
  double goalValue = 100;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([_fetchSettings(), _fetchTasks()]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final data = await supabase
            .from('user_settings')
            .select('goal_type, daily_goal_rubles, monthly_goal_rubles')
            .eq('user_id', userId)
            .maybeSingle();
        if (data != null && mounted) {
          setState(() {
            goalType = data['goal_type'] ?? 'daily';
            if (goalType == 'daily') {
              goalValue =
                  (data['daily_goal_rubles'] as num?)?.toDouble() ?? 100;
            } else {
              goalValue =
                  (data['monthly_goal_rubles'] as num?)?.toDouble() ?? 3000;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) debugPrint('Error fetching settings: $e');
    }
  }

  Future<void> _fetchTasks() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // Fetch tasks associated with the selected site
      final data = await supabase
          .from('task_sites')
          .select('*, tasks!inner(*)')
          .eq('site_name', widget.siteName.toLowerCase())
          .eq('tasks.is_active', true);

      debugPrint("Fetched Tasks Data: $data");

      if (!mounted) {
        return;
      }

      // Get IDs of tasks already completed by this user
      final completedData = await supabase
          .from('completed_tasks')
          .select('task_id')
          .eq('user_id', userId);
      final completedIds = (completedData as List)
          .map((e) => e['task_id'])
          .toList();

      List<Map<String, dynamic>> filteredTasks = [];
      for (var item in data) {
        final taskData = (item['tasks'] is Map)
            ? item['tasks'] as Map<String, dynamic>
            : <String, dynamic>{};

        final int completedCount =
            (taskData['completed_count'] as num?)?.toInt() ?? 0;
        final int maxUsers = item['max_users'] ?? 100;

        // Exclude if max reached OR user already did it
        if (completedCount >= maxUsers ||
            completedIds.contains(taskData['id'])) {
          continue;
        }

        filteredTasks.add(Map<String, dynamic>.from(item));
      }

      setState(() {
        tasks = filteredTasks;
      });
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      rethrow;
    }
  }

  Future<void> _openLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Cannot open link'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _executeTask(Map<String, dynamic> item) async {
    final userId = supabase.auth.currentUser?.id;
    final dynamic rawTasks = item['tasks'];
    final Map<String, dynamic> taskData =
        (rawTasks is List && rawTasks.isNotEmpty)
        ? rawTasks.first as Map<String, dynamic>
        : (rawTasks is Map<String, dynamic> ? rawTasks : {});

    final taskId = taskData['id'];
    final int currentCompleted = taskData['completed_count'] ?? 0;
    final String taskLink = item['task_link'] ?? '';

    try {
      if (userId == null) return;

      // 0. Record completion first to ensure it disappears
      await supabase.from('completed_tasks').insert({
        'user_id': userId,
        'task_id': taskId,
        'site_name': widget.siteName.toLowerCase(),
      });

      // 1. Open Link
      if (taskLink.isNotEmpty) await _openLink(taskLink);

      // 1. Update completed count in tasks table
      await supabase
          .from('tasks')
          .update({'completed_count': currentCompleted + 1})
          .eq('id', taskId);

      // 2. Check if limit reached to disable task and delete video
      if (currentCompleted + 1 >= (item['max_users'] ?? 100)) {
        await supabase
            .from('tasks')
            .update({'is_active': false})
            .eq('id', taskId);

        final videoUrl = taskData['task_video_url'];
        if (videoUrl != null && videoUrl.contains('videos/')) {
          final fileName = videoUrl.split('videos/').last;
          await supabase.storage.from('videos').remove([fileName]);
        }
      }

      if (!mounted) return;

      _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task executed successfully')),
      );
    } catch (e) {
      if (mounted) debugPrint('Error executing task: $e');
    }
  }

  void _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SitesPage()),
    );

    if (result == true && mounted) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.siteName} Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
          ? const Center(child: Text('No tasks available for this site'))
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final item = tasks[index];
                final dynamic rawTasks = item['tasks'];
                final Map<String, dynamic> taskData =
                    (rawTasks is List && rawTasks.isNotEmpty)
                    ? rawTasks.first as Map<String, dynamic>
                    : (rawTasks is Map<String, dynamic> ? rawTasks : {});

                final title = taskData['task_title'] ?? 'New Task';

                final int completedCount =
                    (taskData['completed_count'] as num?)?.toInt() ?? 0;
                final int maxUsers = item['max_users'] ?? 1000;
                final double reward =
                    (item['price'] as num?)?.toDouble() ?? 0.0;

                // Ensure video is loaded
                final String videoUrl = (taskData['task_video_url'] ?? '')
                    .toString();

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reward: ${reward.toStringAsFixed(2)} RUB',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Progress: $completedCount/$maxUsers',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (videoUrl.isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _openLink(videoUrl),
                                  icon: const Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                  ),
                                  label: const Text('Watch Video'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[300],
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            if (videoUrl.isNotEmpty) const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _executeTask(item),
                                icon: const Icon(
                                  Icons.open_in_new,
                                  color: Colors.white,
                                ),
                                label: const Text('Execute Task'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
