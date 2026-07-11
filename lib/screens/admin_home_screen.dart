import 'package:flutter/material.dart';

import '../utils/currency.dart';
import '../models/business_settings.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/confirm_dialog.dart';
import 'account_settings_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.apiService,
    required this.user,
    required this.businessSettings,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final ApiService apiService;
  final AppUser user;
  final BusinessSettings businessSettings;
  final VoidCallback onLogout;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;
  List<Product> _products = [];
  List<Sale> _sales = [];
  late BusinessSettings _businessSettings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _businessSettings = widget.businessSettings;
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.apiService.fetchBusinessSettings();
      final products = await widget.apiService.fetchProducts();
      List<Sale> sales;
      if (_tab == 1) {
        sales = await widget.apiService.fetchSales(today: true);
      } else if (_tab == 2) {
        sales = await widget.apiService.fetchSales();
      } else {
        sales = [];
      }
      if (!mounted) return;
      setState(() {
        _businessSettings = settings;
        _products = products;
        _sales = sales;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to use the admin mobile view.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
      isDanger: true,
    );
    if (shouldLogout) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: Text('${_businessSettings.businessName} • Admin'),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await Navigator.of(context).push<AppUser>(
                MaterialPageRoute(
                  builder: (_) => AccountSettingsScreen(
                    apiService: widget.apiService,
                    user: widget.user,
                  ),
                ),
              );
              if (updated != null) widget.onUserUpdated(updated);
            },
            icon: const Icon(Icons.person),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _confirmLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Products')),
              ButtonSegment(value: 1, label: Text('Today Sales')),
              ButtonSegment(value: 2, label: Text('All Sales')),
            ],
            selected: {_tab},
            onSelectionChanged: (value) {
              setState(() => _tab = value.first);
              _load();
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _tab == 0
                ? _ProductsList(products: _products)
                : _SalesList(sales: _sales),
          ),
        ],
      ),
    );
  }
}

class _ProductsList extends StatelessWidget {
  const _ProductsList({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('No products yet'));
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text('Stock: ${product.stockAvailable}'),
          trailing: Text(formatCurrencyFromString(product.price)),
        );
      },
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({required this.sales});

  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Center(child: Text('No sales found'));
    }

    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return ListTile(
          title: Text(sale.shopName),
          subtitle: Text(
            '${sale.deliveryGuyName} • ${sale.saleDate.toLocal()}',
          ),
          trailing: Text(formatCurrencyFromString(sale.totalAmount)),
        );
      },
    );
  }
}
