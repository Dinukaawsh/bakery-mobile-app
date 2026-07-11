import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.apiService,
    required this.user,
  });

  final ApiService apiService;
  final AppUser user;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _error;
  String? _message;
  bool _saving = false;
  late String _originalEmail;

  @override
  void initState() {
    super.initState();
    _originalEmail = widget.user.email;
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final me = await widget.apiService.getProfile();
      if (!mounted) return;
      _phoneController.text = me.phone ?? '';
    } catch (_) {
      // Phone is optional; ignore load errors here.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final email = _emailController.text.trim();
    final changingCredentials =
        newPassword.isNotEmpty || email != _originalEmail;

    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      setState(() => _error = 'New passwords do not match');
      return;
    }

    if (changingCredentials && _currentPasswordController.text.isEmpty) {
      setState(
        () => _error = 'Enter current password to change email or password',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });

    try {
      final updated = await widget.apiService.updateProfile(
        currentPassword:
            changingCredentials ? _currentPasswordController.text : null,
        email: email,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: newPassword.isNotEmpty ? newPassword : null,
      );

      if (!mounted) return;
      setState(() {
        _message = 'Account updated';
        _originalEmail = updated.email;
      });
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Enter current password when changing email or password.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: Colors.green)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
