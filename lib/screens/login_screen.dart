import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../models/business_settings.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/bakery_loading_spinner.dart';
import '../widgets/locale_toggle.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.apiService,
    required this.businessSettings,
    required this.onLoggedIn,
    this.onSuspended,
  });

  final ApiService apiService;
  final BusinessSettings businessSettings;
  final ValueChanged<AppUser> onLoggedIn;
  final VoidCallback? onSuspended;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await widget.apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      widget.onLoggedIn(user);
    } on AccountSuspendedException {
      widget.onSuspended?.call();
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = message == 'ACCOUNT_SUSPENDED'
            ? LocaleScope.of(context).t('auth.loginSuspended')
            : message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.businessSettings;
    final contactLine = [
      if (settings.phone.isNotEmpty) settings.phone,
      if (settings.email != null && settings.email!.isNotEmpty) settings.email,
    ].join('  •  ');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFBEB),
              Color(0xFFFEF3C7),
              Color(0xFFFFF7ED),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        _BrandHeader(
                          businessName: settings.businessName,
                          address: settings.address,
                          contactLine: contactLine,
                        ),
                        const SizedBox(height: 28),
                        _LoginCard(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          loading: _loading,
                          error: _error,
                          onTogglePassword: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          onSubmit: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 8,
                right: 16,
                child: LocaleToggleLight(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.businessName,
    required this.address,
    required this.contactLine,
  });

  final String businessName;
  final String address;
  final String contactLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 88,
          width: 88,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFDE68A), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB45309).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.bakery_dining_rounded,
            size: 44,
            color: Color(0xFFB45309),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          businessName.toUpperCase(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 2.4,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB45309),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          businessName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            address,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF57534E),
              height: 1.4,
            ),
          ),
        ],
        if (contactLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            contactLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('login.welcome'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              t('login.subtitle'),
              style: const TextStyle(color: Color(0xFF57534E), height: 1.4),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: t('login.email'),
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return t('login.emailRequired');
                if (!email.contains('@')) return t('login.emailInvalid');
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: t('login.password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return t('login.passwordRequired');
                }
                return null;
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFFDE68A),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: loading
                  ? const BakeryLoadingSpinner(
                      size: BakerySpinnerSize.sm,
                      color: Colors.white,
                      trackColor: Color(0x33FFFFFF),
                    )
                  : Text(
                      t('login.signIn'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  t('login.accessHint'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
