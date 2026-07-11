import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/business_settings.dart';
import '../utils/currency.dart';
import '../widgets/bill_receipt_card.dart';

Future<void> printBillReceipt({
  required BusinessSettings settings,
  required String billNumberLabel,
  required String shopName,
  required String deliveryName,
  required DateTime saleDate,
  required List<BillLineItem> items,
  required double totalAmount,
  String? shopOwner,
  String? shopAddress,
  String? shopPhone,
  String? notes,
}) async {
  final doc = pw.Document();
  final dateLabel = _formatDate(saleDate);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(16),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                settings.businessName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (settings.ownerName != null && settings.ownerName!.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.ownerName!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            if (settings.address.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.address,
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.phone.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'Tel: ${settings.phone}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                billNumberLabel,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Divider(),
            pw.Text('Shop', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(shopName),
            if (shopOwner != null && shopOwner.isNotEmpty) pw.Text(shopOwner),
            if (shopAddress != null && shopAddress.isNotEmpty)
              pw.Text(shopAddress),
            if (shopPhone != null && shopPhone.isNotEmpty) pw.Text(shopPhone),
            pw.SizedBox(height: 8),
            pw.Text(
              'Delivery',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(deliveryName),
            pw.Text(dateLabel),
            pw.SizedBox(height: 8),
            pw.Divider(),
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(item.productName)),
                    pw.Text('${item.quantity}'),
                    pw.SizedBox(width: 8),
                    pw.Text(formatCurrency(item.lineTotal)),
                  ],
                ),
              ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total (Rs)',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  formatCurrency(totalAmount),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Notes: $notes'),
            ],
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'Thank you for your business',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
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
