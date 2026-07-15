import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/locale_scope.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/safe_insets.dart';
import '../widgets/app_toast.dart';
import '../widgets/bakery_app_bar.dart';
import '../widgets/bakery_loading_spinner.dart';

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
  bool _saving = false;
  bool _uploadingPhoto = false;
  late String _originalEmail;
  String? _imageUrl;
  late AppUser _latestUser;

  @override
  void initState() {
    super.initState();
    _originalEmail = widget.user.email;
    _imageUrl = widget.user.imageUrl;
    _latestUser = widget.user;
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final me = await widget.apiService.getProfile();
      if (!mounted) return;
      setState(() {
        _phoneController.text = me.phone ?? '';
        _imageUrl = me.imageUrl ?? me.user.imageUrl;
        _nameController.text = me.user.name;
        _emailController.text = me.user.email;
        _originalEmail = me.user.email;
        _latestUser = me.user;
      });
    } catch (_) {
      // Optional fields; ignore load errors here.
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

  Future<AppUser> _persistPhoto({
    String? imageUrl,
    bool clearImageUrl = false,
  }) {
    return widget.apiService.updateProfile(
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : widget.user.name,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : widget.user.email,
      imageUrl: clearImageUrl ? null : imageUrl,
      clearImageUrl: clearImageUrl,
    );
  }

  Future<void> _pickPhoto() async {
    final t = LocaleScope.of(context).t;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() {
        _uploadingPhoto = true;
        _error = null;
      });

      final bytes = await file.readAsBytes();
      final url = await widget.apiService.uploadImage(
        bytes: bytes,
        filename: file.name.isNotEmpty ? file.name : 'profile.jpg',
      );

      // Save to DB immediately so refresh keeps the photo.
      final updated = await _persistPhoto(imageUrl: url);

      if (!mounted) return;
      setState(() {
        _imageUrl = updated.imageUrl ?? url;
        _latestUser = updated;
        _uploadingPhoto = false;
      });
      showSuccessToast(context, t('account.photoSaved'));
    } on AccountSuspendedException {
      // AuthGate handles suspended banner.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      showErrorToast(context, _error!);
    }
  }

  Future<void> _removePhoto() async {
    final t = LocaleScope.of(context).t;
    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });
    try {
      final updated = await _persistPhoto(clearImageUrl: true);
      if (!mounted) return;
      setState(() {
        _imageUrl = null;
        _latestUser = updated;
        _uploadingPhoto = false;
      });
      showSuccessToast(context, t('account.photoRemoved'));
    } on AccountSuspendedException {
      // AuthGate handles suspended banner.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      showErrorToast(context, _error!);
    }
  }

  Future<void> _submit() async {
    final t = LocaleScope.of(context).t;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final email = _emailController.text.trim();
    final changingCredentials =
        newPassword.isNotEmpty || email != _originalEmail;

    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      setState(() => _error = t('account.passwordMismatch'));
      return;
    }

    if (changingCredentials && _currentPasswordController.text.isEmpty) {
      setState(() => _error = t('account.currentPasswordRequired'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.apiService.updateProfile(
        currentPassword:
            changingCredentials ? _currentPasswordController.text : null,
        email: email,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: newPassword.isNotEmpty ? newPassword : null,
        imageUrl: _imageUrl,
      );

      if (!mounted) return;
      showSuccessToast(context, t('account.updated'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on AccountSuspendedException {
      // AuthGate handles suspended banner.
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      showErrorToast(context, _error!);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _popWithLatest() {
    Navigator.of(context).pop(_latestUser);
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    final hasImage = _imageUrl != null && _imageUrl!.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popWithLatest();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBEB),
        appBar: bakeryAppBar(
          context,
          title: t('account.title'),
          onBack: _popWithLatest,
        ),
        body: ListView(
          padding: listPaddingWithSystemBottom(context, bottomBase: 24),
          children: [
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(48),
                    child: Container(
                      width: 96,
                      height: 96,
                      color: const Color(0xFFFFEDD5),
                      child: hasImage
                          ? Image.network(
                              _imageUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 48,
                                color: Color(0xFFB45309),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 48,
                              color: Color(0xFFB45309),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_uploadingPhoto)
                    const BakeryLoadingCenter()
                  else ...[
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(t('account.changePhoto')),
                    ),
                    if (hasImage)
                      TextButton(
                        onPressed: _removePhoto,
                        child: Text(t('account.removePhoto')),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('account.name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: t('account.email'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: t('account.phone'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t('account.passwordHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t('account.currentPassword'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t('account.newPassword'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t('account.confirmPassword'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_saving || _uploadingPhoto) ? null : _submit,
              child: Text(
                _saving ? t('account.saving') : t('account.save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
