import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'webview_screen.dart';

class Task {
  final String title;
  final String taskLink;
  final String? videoUrl;

  Task({required this.title, required this.taskLink, this.videoUrl});

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      title: map['task_title'] ?? 'No Title',
      taskLink: map['task_link'] ?? '',
      videoUrl: map['video_link'],
    );
  }
}

class TaskScreen extends StatefulWidget {
  final String siteName;

  const TaskScreen({super.key, required this.siteName});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _supabase = Supabase.instance.client;
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select('task_title, task_link, video_link')
          .eq('site_name', widget.siteName);

      if (mounted) {
        setState(() {
          _tasks = (response as List)
              .map((taskData) => Task.fromMap(taskData))
              .toList();
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'failed_to_fetch_tasks'.tr(
            namedArgs: {'error': e.toString()},
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          // This is fine, but we'll also show the error in the UI
          SnackBar(
            content: Text(
              'failed_to_fetch_tasks'.tr(namedArgs: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  void _openWebView(String url) {
    if (url.isNotEmpty && Uri.tryParse(url)?.isAbsolute == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => WebViewScreen(url: url)),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('url_is_not_available'.tr())));
    }
  }

  String _getReferralUrl() {
    switch (widget.siteName.toLowerCase()) {
      case 'seofast':
        return 'https://seo-fast.ru/?r=3151488';
      case 'aviso':
        return 'https://aviso.bz/?r=khroba_242';
      case 'socpublic':
        return 'https://socpublic.com/?i=9565193&slide=3';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.siteName),
        backgroundColor: Colors.orange[300], // Light Orange
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            )
          : _tasks.isEmpty
          ? Center(child: Text('no_tasks'.tr()))
          : Column(
              children: [
                // Referral Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: () => _openWebView(_getReferralUrl()),
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.orange[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'go_to_website'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // Task List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        elevation: 4,
                        shadowColor: Colors.grey.withValues(alpha: 0.5),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _openWebView(task.taskLink),
                                    icon: const Icon(Icons.arrow_forward),
                                    label: Text('start_task'.tr()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (task.videoUrl != null &&
                                      task.videoUrl!.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () => _openWebView(
                                        task.videoUrl!,
                                      ), // Watch Tutorial
                                      icon: const Icon(Icons.arrow_forward),
                                      label: Text('watch_video'.tr()),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                ),
              ],
            ),
    );
  }
}
