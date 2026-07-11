import 'package:flutter/material.dart';

import '../models/business_settings.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../utils/bill_print.dart';
import '../widgets/bill_receipt_card.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({
    super.key,
    required this.apiService,
    required this.saleId,
    required this.businessSettings,
    this.embedded = false,
  });

  final ApiService apiService;
  final int saleId;
  final BusinessSettings businessSettings;
  final bool embedded;

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  Sale? _sale;
  String? _error;
  bool _loading = true;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sale = await widget.apiService.getSale(widget.saleId);
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _error = null;
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

  List<BillLineItem> _lineItems(Sale sale) {
    return sale.items
        .map(
          (item) => BillLineItem(
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: double.tryParse(item.unitPrice) ?? 0,
          ),
        )
        .toList();
  }

  double _total(Sale sale) {
    return double.tryParse(sale.totalAmount) ??
        _lineItems(sale).fold(0, (sum, item) => sum + item.lineTotal);
  }

  Future<void> _printBill() async {
    final sale = _sale;
    if (sale == null || _printing) return;

    setState(() => _printing = true);
    try {
      await printBillReceipt(
        settings: widget.businessSettings,
        billNumberLabel: 'Delivery Bill #${sale.id}',
        shopName: sale.shopName,
        deliveryName: sale.deliveryGuyName,
        saleDate: sale.saleDate,
        items: _lineItems(sale),
        totalAmount: _total(sale),
        shopOwner: sale.shopOwner,
        shopAddress: sale.shopAddress,
        shopPhone: sale.shopPhone,
        notes: sale.notes,
      );

      if (!sale.billPrinted) {
        await widget.apiService.markBillPrinted(sale.id);
        if (!mounted) return;
        setState(() {
          _sale = Sale(
            id: sale.id,
            deliveryGuyId: sale.deliveryGuyId,
            shopId: sale.shopId,
            saleDate: sale.saleDate,
            totalAmount: sale.totalAmount,
            notes: sale.notes,
            billPrinted: true,
            shopName: sale.shopName,
            deliveryGuyName: sale.deliveryGuyName,
            shopOwner: sale.shopOwner,
            shopAddress: sale.shopAddress,
            shopPhone: sale.shopPhone,
            items: sale.items,
          );
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill sent to printer')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', 'Print failed: '),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('Delivery bill'),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.embedded,
        actions: widget.embedded
            ? [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.close),
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    BillReceiptCard(
                      settings: widget.businessSettings,
                      billNumberLabel: 'Delivery Bill #${_sale!.id}',
                      shopName: _sale!.shopName,
                      deliveryName: _sale!.deliveryGuyName,
                      saleDate: _sale!.saleDate,
                      items: _lineItems(_sale!),
                      totalAmount: _total(_sale!),
                      shopOwner: _sale!.shopOwner,
                      shopAddress: _sale!.shopAddress,
                      shopPhone: _sale!.shopPhone,
                      notes: _sale!.notes,
                    ),
                    const SizedBox(height: 16),
                    if (_sale!.billPrinted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bill already printed for this delivery.',
                                style: TextStyle(color: Color(0xFF166534)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _printing ? null : _printBill,
                      icon: _printing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded),
                      label: Text(
                        _printing
                            ? 'Opening printer...'
                            : _sale!.billPrinted
                                ? 'Print again'
                                : 'Print bill for shop',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFFB45309),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
    );
  }
}
