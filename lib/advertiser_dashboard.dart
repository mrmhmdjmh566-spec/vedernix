import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vedernix/add_task_page.dart';

class AdvertiserDashboard extends StatelessWidget {
  const AdvertiserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("advertiser_dashboard".tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          child: Text("add_task".tr()),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTaskPage()),
            );
          },
        ),
      ),
    );
  }
}
