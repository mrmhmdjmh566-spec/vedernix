import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vedernix/login_screen.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("welcome".tr())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_fill,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LoginScreen(userType: "user"),
                      ),
                    );
                  },
                  child: Text("iam_user".tr()),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
