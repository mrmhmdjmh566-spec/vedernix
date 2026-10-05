import 'package:flutter/material.dart';
import 'goal_settings_page.dart';
import 'sites_page.dart';
import 'user_profile_page.dart';

class UserSettingsMainPage extends StatelessWidget {
  const UserSettingsMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    35,
                  ),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 28),
                    _buildSectionTitle(),
                    const SizedBox(height: 13),
                    _buildSettingsCard(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF222222),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(
                color: Color(0xFFEAEAEA),
              ),
            ),
          ),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9DE),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: Color(0xFFE85D24),
            size: 24,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171717),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Manage your Vedernix preferences',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF777777),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle() {
    return const Text(
      'Settings',
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: Color(0xFF171717),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            context: context,
            icon: Icons.track_changes_rounded,
            title: 'Goal Settings',
            subtitle: 'Manage your earning goal',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GoalSettingsPage(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildSettingTile(
            context: context,
            icon: Icons.language_rounded,
            title: 'Sites Settings',
            subtitle: 'Manage your selected sites',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SitesPage(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildSettingTile(
            context: context,
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            subtitle: 'Manage your profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserProfilePage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFE85D24),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 80),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFF0F0F0),
      ),
    );
  }
}
