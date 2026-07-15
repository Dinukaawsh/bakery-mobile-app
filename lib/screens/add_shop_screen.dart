import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../services/api_service.dart';
import '../utils/safe_insets.dart';
import '../widgets/bakery_app_bar.dart';

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _addressController = TextEditingController();
  final _routeController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _addressController.dispose();
    _routeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = LocaleScope.of(context).t;
    final name = _nameController.text.trim();
    final ownerName = _ownerController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || ownerName.isEmpty || address.isEmpty) {
      setState(() => _error = t('addShop.requiredFields'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final shop = await widget.apiService.createShop(
        name: name,
        ownerName: ownerName,
        address: address,
        phone: _phoneController.text.trim(),
        route: _routeController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(shop);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: bakeryAppBar(context, title: t('addShop.title')),
      body: ListView(
        padding: listPaddingWithSystemBottom(context, bottomBase: 24),
        children: [
          Text(t('addShop.subtitle')),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: t('addShop.shopName'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerController,
            decoration: InputDecoration(
              labelText: t('addShop.ownerName'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: t('addShop.address'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _routeController,
            decoration: InputDecoration(
              labelText: t('addShop.routeOptional'),
              hintText: t('addShop.routeHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: t('addShop.phoneOptional'),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? t('addShop.saving') : t('addShop.save')),
          ),
        ],
      ),
    );
  }
}
