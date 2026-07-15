import 'package:flutter/material.dart';

class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({
    super.key,
    required this.businessName,
    this.message,
  });

  final String businessName;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBEB),
              Color(0xFFFEF3C7),
              Color(0xFFFFF7ED),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  businessName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFB45309),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF57534E),
                  ),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  children: [
                    Text(
                      'Created by DDRsolutions © $year. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78716C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '+94 71 8780 945',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
