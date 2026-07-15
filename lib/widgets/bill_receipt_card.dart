import 'package:flutter/material.dart';

import '../models/business_settings.dart';
import '../utils/currency.dart';

class BillLineItem {
  const BillLineItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final int quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;
}

class BillReceiptCard extends StatelessWidget {
  const BillReceiptCard({
    super.key,
    required this.settings,
    required this.billNumberLabel,
    required this.shopName,
    required this.deliveryName,
    required this.saleDate,
    required this.items,
    required this.totalAmount,
    this.previousBalance = 0,
    this.paidAmount = 0,
    this.remainingAfter,
    this.shopOwner,
    this.shopAddress,
    this.shopPhone,
    this.notes,
    this.isPreview = false,
  });

  final BusinessSettings settings;
  final String billNumberLabel;
  final String shopName;
  final String deliveryName;
  final DateTime saleDate;
  final List<BillLineItem> items;
  final double totalAmount;
  final double previousBalance;
  final double paidAmount;
  final double? remainingAfter;
  final String? shopOwner;
  final String? shopAddress;
  final String? shopPhone;
  final String? notes;
  final bool isPreview;

  double get amountDue => previousBalance + totalAmount;
  double get remaining =>
      remainingAfter ?? (amountDue - paidAmount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(saleDate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE7E5E4))),
            ),
            child: Column(
              children: [
                if (isPreview)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Bill preview',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                Text(
                  settings.businessName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (settings.ownerName != null &&
                    settings.ownerName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    settings.ownerName!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF57534E),
                    ),
                  ),
                ],
                if (settings.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    settings.address,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Color(0xFF57534E),
                    ),
                  ),
                ],
                if (settings.phone.isNotEmpty ||
                    (settings.email?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (settings.phone.isNotEmpty) 'Tel: ${settings.phone}',
                      if (settings.email?.isNotEmpty ?? false) settings.email!,
                    ].join(' • '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF57534E),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  billNumberLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF44403C),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shop',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(shopName, style: const TextStyle(fontSize: 12)),
                if (shopOwner != null && shopOwner!.isNotEmpty)
                  Text(shopOwner!, style: const TextStyle(fontSize: 12)),
                if (shopAddress != null && shopAddress!.isNotEmpty)
                  Text(shopAddress!, style: const TextStyle(fontSize: 12)),
                if (shopPhone != null && shopPhone!.isNotEmpty)
                  Text(shopPhone!, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                const Text(
                  'Delivery',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(deliveryName, style: const TextStyle(fontSize: 12)),
                Text(dateLabel, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7E5E4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Product',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF57534E),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        'Qty',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF57534E),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: Text(
                        'Total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF57534E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Add products to see bill lines',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78716C)),
                    ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            child: Text(
                              formatCurrency(item.lineTotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 20, color: Color(0xFFE7E5E4)),
                _summaryRow('Today\'s drop (Rs)', formatCurrency(totalAmount)),
                if (previousBalance > 0)
                  _summaryRow(
                    'Previous unpaid (Rs)',
                    formatCurrency(previousBalance),
                    color: const Color(0xFFB45309),
                  ),
                _summaryRow(
                  'Total due (Rs)',
                  formatCurrency(amountDue),
                  bold: true,
                ),
                _summaryRow('Paid (Rs)', formatCurrency(paidAmount)),
                _summaryRow(
                  'Remaining (Rs)',
                  formatCurrency(remaining),
                  bold: true,
                  color: const Color(0xFFB91C1C),
                ),
                if (notes != null && notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Notes: $notes',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF57534E)),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Thank you for your business',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF78716C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 14 : 12,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 14 : 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
