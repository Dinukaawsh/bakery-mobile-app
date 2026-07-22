import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/currency.dart';
import '../widgets/app_toast.dart';
import '../widgets/bakery_app_bar.dart';
import '../widgets/bakery_loading_spinner.dart';
import '../widgets/qty_stepper.dart';

/// Full-screen picker for return quantities — only products previously
/// dropped at [shopId], capped by net returnable qty.
class ReturnItemsScreen extends StatefulWidget {
  const ReturnItemsScreen({
    super.key,
    required this.apiService,
    required this.shopId,
    this.initialQuantities = const {},
  });

  final ApiService apiService;
  final int shopId;
  final Map<int, int> initialQuantities;

  @override
  State<ReturnItemsScreen> createState() => _ReturnItemsScreenState();
}

class _ReturnItemsScreenState extends State<ReturnItemsScreen> {
  final Map<int, int> _quantities = {};
  List<ReturnableProduct> _products = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await widget.apiService.fetchShopReturnable(
        widget.shopId,
      );
      if (!mounted) return;

      final qty = <int, int>{};
      for (final product in products) {
        if (product.returnable <= 0) continue;
        final initial = widget.initialQuantities[product.productId] ?? 0;
        qty[product.productId] = initial.clamp(0, product.returnable);
      }

      setState(() {
        _products = products.where((p) => p.returnable > 0).toList();
        _quantities
          ..clear()
          ..addAll(qty);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<ReturnableProduct> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products
        .where(
          (p) =>
              p.productName.toLowerCase().contains(q) ||
              p.productCategory.toLowerCase().contains(q),
        )
        .toList();
  }

  int get _selectedCount =>
      _quantities.values.where((qty) => qty > 0).length;

  void _save() {
    final cleaned = <int, int>{};
    _quantities.forEach((id, qty) {
      if (qty > 0) cleaned[id] = qty;
    });
    Navigator.of(context).pop(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F4),
      appBar: bakeryAppBar(
        context,
        title: t('delivery.returnItemsTitle'),
      ),
      body: _loading
          ? const BakeryLoadingCenter()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: Text(t('common.retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            t('delivery.returnItemsHint'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF57534E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: InputDecoration(
                              hintText: t('delivery.searchProducts'),
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                t('delivery.noReturnableProducts'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF78716C),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final product = _filtered[index];
                                final qty =
                                    _quantities[product.productId] ?? 0;
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    4,
                                    10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE7E5E4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.productName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                formatCurrencyFromString(
                                                  product.productPrice,
                                                ),
                                                t(
                                                  'delivery.returnableQty',
                                                  {
                                                    'count':
                                                        product.returnable,
                                                  },
                                                ),
                                                if (!product.isActive)
                                                  t(
                                                    'delivery.inactiveProduct',
                                                  ),
                                              ].join(' · '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: product.isActive
                                                    ? const Color(0xFF57534E)
                                                    : const Color(0xFFB45309),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      QtyStepper(
                                        value: qty,
                                        max: product.returnable,
                                        onExceedMax: () {
                                          showAppToast(
                                            context,
                                            t(
                                              'delivery.qtyExceedsReturnable',
                                              {
                                                'count': product.returnable,
                                              },
                                            ),
                                          );
                                        },
                                        onChanged: (value) {
                                          setState(() {
                                            _quantities[product.productId] =
                                                value;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              _selectedCount > 0
                  ? t('delivery.saveReturnsCount', {'count': _selectedCount})
                  : t('delivery.saveReturns'),
            ),
          ),
        ),
      ),
    );
  }
}
