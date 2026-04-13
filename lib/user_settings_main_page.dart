import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'goal_settings_page.dart';
import 'sites_page.dart';
import 'user_profile_page.dart';

class UserSettingsMainPage extends StatelessWidget {
  const UserSettingsMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("settings".tr())),
      body: ListView(
        children: [
          ListTile(
            title: Text("🎯 ${"goal_settings".tr()}"),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoalSettingsPage()),
              );
            },
          ),
          ListTile(
            title: Text("🌐 ${"sites_settings".tr()}"),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SitesPage()),
              );
            },
          ),
          ListTile(
            title: Text("👤 ${"profile".tr()} & ${"language".tr()}"),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfilePage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
