import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../models/business_settings.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/app_splash_screen.dart';
import 'account_suspended_screen.dart';
import 'admin_shell.dart';
import 'delivery_home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  AppUser? _user;
  BusinessSettings _businessSettings = BusinessSettings.fallback;
  bool _bootstrapping = true;
  bool _splashDone = false;
  bool _suspended = false;
  Timer? _sessionTimer;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.apiService.onAccountSuspended = _handleSuspended;
    _start();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _presenceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.apiService.onAccountSuspended == _handleSuspended) {
      widget.apiService.onAccountSuspended = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _user != null && !_suspended) {
      unawaited(_checkSession());
      unawaited(_pingPresence());
    }
  }

  void _handleSuspended() {
    if (!mounted) return;
    setState(() {
      _user = null;
      _suspended = true;
    });
    _sessionTimer?.cancel();
    _presenceTimer?.cancel();
  }

  Future<void> _start() async {
    final splashFuture =
        Future<void>.delayed(const Duration(milliseconds: 2000));
    await Future.wait([
      splashFuture,
      _bootstrap(),
    ]);
    if (!mounted) return;
    setState(() {
      _splashDone = true;
      _bootstrapping = false;
    });
  }

  void _startSessionWatch() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_checkSession()),
    );
    _startPresenceWatch();
  }

  void _startPresenceWatch() {
    _presenceTimer?.cancel();
    unawaited(_pingPresence());
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_pingPresence()),
    );
  }

  Future<void> _pingPresence() async {
    if (_user == null || _suspended) return;
    try {
      await widget.apiService.pingPresence();
    } catch (_) {
      // Ignore transient presence errors.
    }
  }

  Future<void> _checkSession() async {
    if (_user == null || _suspended) return;
    try {
      final user = await widget.apiService.getMe();
      if (!mounted) return;
      setState(() => _user = user);
    } on AccountSuspendedException {
      // Handled by onAccountSuspended callback.
    } catch (_) {
      // Ignore transient network errors while checking.
    }
  }

  Future<void> _bootstrap() async {
    await widget.apiService.loadToken();

    try {
      final settings = await widget.apiService.fetchBusinessSettings();
      if (!mounted) return;
      setState(() => _businessSettings = settings);
    } catch (_) {
      if (!mounted) return;
      setState(() => _businessSettings = BusinessSettings.fallback);
    }

    try {
      final user = await widget.apiService.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _suspended = false;
      });
      _startSessionWatch();
    } on AccountSuspendedException {
      if (!mounted) return;
      setState(() {
        _user = null;
        _suspended = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = null;
        _suspended = false;
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
    if (!mounted) return;
    setState(() {
      _user = user;
      _suspended = false;
    });
    _startSessionWatch();
  }

  void _handleUserUpdated(AppUser user) {
    setState(() => _user = user);
  }

  Future<void> _handleLogout() async {
    _sessionTimer?.cancel();
    _presenceTimer?.cancel();
    await widget.apiService.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _suspended = false;
    });
  }

  void _dismissSuspended() {
    setState(() => _suspended = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone || _bootstrapping) {
      final message = (() {
        try {
          return LocaleScope.of(context).t('splash.loading');
        } catch (_) {
          return 'Loading...';
        }
      })();

      return AppSplashScreen(
        businessName: _businessSettings.businessName,
        message: message,
      );
    }

    if (_suspended) {
      return AccountSuspendedScreen(
        businessName: _businessSettings.businessName,
        onBackToLogin: _dismissSuspended,
      );
    }

    if (_user == null) {
      return LoginScreen(
        apiService: widget.apiService,
        businessSettings: _businessSettings,
        onLoggedIn: _handleLogin,
        onSuspended: _handleSuspended,
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
