import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/api_service.dart';

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
  final _phoneController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final ownerName = _ownerController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || ownerName.isEmpty || address.isEmpty) {
      setState(() => _error = 'Shop name, owner, and address are required');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add shop'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Add a new shop on your route. It will appear for deliveries and in the admin panel.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Shop name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerController,
            decoration: const InputDecoration(
              labelText: 'Owner name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving...' : 'Save shop'),
          ),
        ],
      ),
    );
  }
}
