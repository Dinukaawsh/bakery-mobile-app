import 'package:flutter/material.dart';

import '../models/business_settings.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'admin_shell.dart';
import 'delivery_home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppUser? _user;
  BusinessSettings _businessSettings = BusinessSettings.fallback;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.apiService.loadToken();

    try {
      final settings = await widget.apiService.fetchBusinessSettings();
      _businessSettings = settings;
    } catch (_) {
      _businessSettings = BusinessSettings.fallback;
    }

    try {
      final user = await widget.apiService.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = null;
        _loading = false;
      });
    }
  }

  Future<void> _refreshBusinessSettings() async {
    try {
      final settings = await widget.apiService.fetchBusinessSettings();
      if (!mounted) return;
      setState(() => _businessSettings = settings);
    } catch (_) {
      // Keep existing settings if refresh fails.
    }
  }

  Future<void> _handleLogin(AppUser user) async {
    await _refreshBusinessSettings();
    setState(() => _user = user);
  }

  void _handleUserUpdated(AppUser user) {
    setState(() => _user = user);
  }

  Future<void> _handleLogout() async {
    await widget.apiService.logout();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return LoginScreen(
        apiService: widget.apiService,
        businessSettings: _businessSettings,
        onLoggedIn: _handleLogin,
      );
    }

    if (_user!.isAdmin) {
      return AdminShell(
        apiService: widget.apiService,
        user: _user!,
        businessSettings: _businessSettings,
        onLogout: _handleLogout,
        onUserUpdated: _handleUserUpdated,
      );
    }

    return DeliveryHomeScreen(
      apiService: widget.apiService,
      user: _user!,
      businessSettings: _businessSettings,
      onLogout: _handleLogout,
      onUserUpdated: _handleUserUpdated,
    );
  }
}
