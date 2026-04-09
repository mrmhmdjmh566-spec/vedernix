import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:omar_242/login_screen.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("welcome".tr())),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(userType: "user"),
                  ),
                );
              },
              child: Text("iam_user".tr()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const LoginScreen(userType: "advertiser"),
                  ),
                );
              },
              child: Text("iam_advertiser".tr()),
            ),
          ],
        ),
      ),
    );
  }
}
