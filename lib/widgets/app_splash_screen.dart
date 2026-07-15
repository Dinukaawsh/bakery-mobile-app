import 'package:flutter/material.dart';

import 'bakery_loading_spinner.dart';

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
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF78350F).withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
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
                    letterSpacing: -0.3,
                    color: Color(0xFF1C1917),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              BakeryLoadingSpinner(
                size: BakerySpinnerSize.lg,
                color: const Color(0xFFB45309),
                trackColor: const Color(0xFFFDE68A),
                label: message,
              ),
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
