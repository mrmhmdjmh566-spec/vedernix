import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'webview_screen.dart';

class TaskScreen extends StatefulWidget {
  final String siteName;

  const TaskScreen({
    super.key,
    required this.siteName,
  });

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String get _siteName => widget.siteName.trim().toLowerCase();

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final siteRows = await supabase
          .from('task_sites')
          .select(
            'id, task_id, site_name, task_link, price, max_users',
          )
          .eq('site_name', _siteName)
          .order('id', ascending: false);

      final rows = List<Map<String, dynamic>>.from(siteRows);

      if (rows.isEmpty) {
        if (!mounted) return;

        setState(() {
          _offers = [];
          _loading = false;
        });

        return;
      }

      final taskIds =
          rows.map((row) => row['task_id']).where((id) => id != null).toList();

      final tasksResponse = await supabase
          .from('tasks')
          .select(
            'id, task_title, task_video_url, uploaded_video, '
            'completed_count, is_active, created_at',
          )
          .inFilter('id', taskIds);

      final tasks = List<Map<String, dynamic>>.from(tasksResponse);

      final taskMap = <dynamic, Map<String, dynamic>>{
        for (final task in tasks) task['id']: task,
      };

      final available = <Map<String, dynamic>>[];

      for (final offer in rows) {
        final task = taskMap[offer['task_id']];

        if (task == null) continue;

        final active = task['is_active'] != false;

        final completed = int.tryParse('${task['completed_count'] ?? 0}') ?? 0;

        final maxUsers = int.tryParse('${offer['max_users'] ?? 0}') ?? 0;

        if (!active) continue;

        if (maxUsers > 0 && completed >= maxUsers) {
          continue;
        }

        available.add({
          ...offer,
          'task': task,
        });
      }

      available.sort((a, b) {
        final aTask = Map<String, dynamic>.from(a['task']);
        final bTask = Map<String, dynamic>.from(b['task']);

        final aDate = DateTime.tryParse('${aTask['created_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate = DateTime.tryParse('${bTask['created_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _offers = available;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) {
      _message('Task link is not available.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url: url,
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE85D24),
          onRefresh: _loadTasks,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 35),
            children: [
              _header(),
              const SizedBox(height: 20),
              if (_loading)
                const SizedBox(
                  height: 400,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE85D24),
                    ),
                  ),
                )
              else if (_error != null)
                _errorState()
              else if (_offers.isEmpty)
                _emptyState()
              else ...[
                _summary(),
                const SizedBox(height: 18),
                ..._offers.map(_taskCard),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
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
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.siteName,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Available tasks',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF777777),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loading ? null : _loadTasks,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: const Color(0xFFFFD8C5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color(0xFFE85D24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_offers.length} tasks currently available on ${widget.siteName}.',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF5E463A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> offer) {
    final task = Map<String, dynamic>.from(offer['task']);

    final title = '${task['task_title'] ?? 'Untitled task'}';
    final link = '${offer['task_link'] ?? ''}';

    final video = task['task_video_url'] ?? task['uploaded_video'];

    final price = double.tryParse('${offer['price'] ?? 0}') ?? 0;

    final completed = int.tryParse('${task['completed_count'] ?? 0}') ?? 0;

    final maxUsers = int.tryParse('${offer['max_users'] ?? 0}') ?? 0;

    final hasVideo = video != null && video.toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFFE85D24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Reward',
                  '${price.toStringAsFixed(2)} RUB',
                  Icons.payments_outlined,
                ),
              ),
              Expanded(
                child: _metric(
                  'Completed',
                  maxUsers > 0 ? '$completed / $maxUsers' : '$completed',
                  Icons.people_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasVideo)
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: () => _openUrl(video.toString()),
                icon: const Icon(
                  Icons.play_circle_outline_rounded,
                ),
                label: const Text('Watch instructions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE85D24),
                  side: const BorderSide(
                    color: Color(0xFFFFCDB7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          if (hasVideo) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _openUrl(link),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Start task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85D24),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFFE85D24),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.assignment_late_outlined,
            size: 52,
            color: Color(0xFFE85D24),
          ),
          SizedBox(height: 16),
          Text(
            'No tasks available',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'There are currently no active tasks for this site.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF777777),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF0D0CC),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFB42318),
          ),
          const SizedBox(height: 15),
          const Text(
            'Could not load tasks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loadTasks,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85D24),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
