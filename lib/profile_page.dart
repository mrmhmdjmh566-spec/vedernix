import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? profileData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        setState(() {
          profileData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text("profile".tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Verification Status Chip
            if (profileData?['is_verified'] == true)
              const Align(
                alignment: Alignment.topRight,
                child: Chip(
                  label: Text(
                    "Verified",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.blue,
                  avatar: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            CircleAvatar(
              radius: 50,
              backgroundImage: profileData?['avatar_url'] != null
                  ? NetworkImage(profileData!['avatar_url'])
                  : null,
              child: profileData?['avatar_url'] == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              profileData?['name'] ?? "User",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              profileData?['email'] ?? user?.email ?? "",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // Stats Section (Balance & Total Earned)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "balance".tr(),
                    "${(profileData?['balance'] ?? 0.0).toStringAsFixed(2)} RUB",
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    "total_earned".tr(),
                    "${(profileData?['total_earned'] ?? 0.0).toStringAsFixed(2)} RUB",
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            _buildInfoTile(
              Icons.qr_code,
              "referral_code".tr(),
              profileData?['referral_code'] ?? "VEDER-NEW-USER",
            ),
            _buildInfoTile(
              Icons.calendar_today,
              "joined".tr(),
              DateFormat.yMMMMd().format(
                DateTime.parse(
                  profileData?['created_at'] ?? DateTime.now().toString(),
                ),
              ),
            ),
            _buildInfoTile(
              Icons.phone,
              "phone".tr(),
              profileData?['phone'] ?? "not_set".tr(),
            ),
            _buildInfoTile(
              Icons.public,
              "country".tr(),
              profileData?['country'] ?? "not_set".tr(),
            ),
            _buildInfoTile(
              Icons.info_outline,
              "bio".tr(),
              profileData?['bio'] ?? "not_set".tr(),
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.orange),
              title: Text("language".tr()),
              trailing: DropdownButton<Locale>(
                value: context.locale,
                onChanged: (Locale? newLocale) {
                  if (newLocale != null) {
                    context.setLocale(newLocale);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: Locale('en'),
                    child: Text("🇺🇸 English"),
                  ),
                  DropdownMenuItem(
                    value: Locale('ar'),
                    child: Text("🇪🇬 العربية"),
                  ),
                  DropdownMenuItem(
                    value: Locale('ru'),
                    child: Text("🇷🇺 Русский"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => supabase.auth.signOut().then(
                (_) => Navigator.pushReplacementNamed(context, '/welcome'),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                "logout",
                style: TextStyle(color: Colors.white),
              ).tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
