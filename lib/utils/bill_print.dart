import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/business_settings.dart';
import '../utils/currency.dart';
import '../widgets/bill_receipt_card.dart';

typedef BillTranslate = String Function(
  String key, [
  Map<String, Object?>? params,
]);

Future<void> printBillReceipt({
  required BusinessSettings settings,
  required String billNumberLabel,
  required String shopName,
  required String deliveryName,
  required DateTime saleDate,
  required List<BillLineItem> items,
  required double totalAmount,
  required BillTranslate t,
  double previousBalance = 0,
  double paidAmount = 0,
  double? remainingAfter,
  String? shopOwner,
  String? shopAddress,
  String? shopPhone,
  String? notes,
}) async {
  final sinhalaRegularData = await rootBundle.load(
    'assets/fonts/NotoSansSinhala-Regular.ttf',
  );
  final sinhalaBoldData = await rootBundle.load(
    'assets/fonts/NotoSansSinhala-Bold.ttf',
  );
  final sinhalaRegular = pw.Font.ttf(sinhalaRegularData);
  final sinhalaBold = pw.Font.ttf(sinhalaBoldData);

  // Prefer broad Latin coverage for EN + fallback Sinhala shaping.
  pw.Font baseFont;
  pw.Font boldFont;
  try {
    baseFont = await PdfGoogleFonts.notoSansRegular();
    boldFont = await PdfGoogleFonts.notoSansBold();
  } catch (_) {
    // Offline fallback: still render Sinhala reliably.
    baseFont = sinhalaRegular;
    boldFont = sinhalaBold;
  }

  pw.TextStyle baseStyle({
    double fontSize = 10,
    bool bold = false,
  }) {
    return pw.TextStyle(
      font: bold ? boldFont : baseFont,
      fontFallback: [sinhalaRegular, sinhalaBold],
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      lineSpacing: 1.2,
    );
  }

  final doc = pw.Document();
  final dateLabel = _formatDate(saleDate);
  final amountDue = previousBalance + totalAmount;
  final remaining =
      remainingAfter ?? (amountDue - paidAmount).clamp(0, double.infinity);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(12),
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        icons: baseFont,
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                settings.businessName,
                style: baseStyle(fontSize: 14, bold: true),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (settings.ownerName != null && settings.ownerName!.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.ownerName!,
                  style: baseStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.address.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.address,
                  style: baseStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.phone.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  t('bill.tel', {'phone': settings.phone}),
                  style: baseStyle(fontSize: 9),
                ),
              ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                billNumberLabel,
                style: baseStyle(bold: true),
              ),
            ),
            pw.Divider(),
            pw.Text(t('bill.shop'), style: baseStyle(bold: true)),
            pw.Text(shopName, style: baseStyle()),
            if (shopOwner != null && shopOwner.isNotEmpty)
              pw.Text(shopOwner, style: baseStyle()),
            if (shopAddress != null && shopAddress.isNotEmpty)
              pw.Text(shopAddress, style: baseStyle()),
            if (shopPhone != null && shopPhone.isNotEmpty)
              pw.Text(shopPhone, style: baseStyle()),
            pw.SizedBox(height: 6),
            pw.Text(t('bill.delivery'), style: baseStyle(bold: true)),
            pw.Text(deliveryName, style: baseStyle()),
            pw.Text(dateLabel, style: baseStyle()),
            pw.SizedBox(height: 6),
            pw.Divider(),
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(item.productName, style: baseStyle()),
                    ),
                    pw.Text('${item.quantity}', style: baseStyle()),
                    pw.SizedBox(width: 8),
                    pw.Text(formatCurrency(item.lineTotal), style: baseStyle()),
                  ],
                ),
              ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(t('bill.todaysDrop'), style: baseStyle()),
                pw.Text(formatCurrency(totalAmount), style: baseStyle()),
              ],
            ),
            if (previousBalance > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(t('bill.previousUnpaid'), style: baseStyle()),
                  pw.Text(formatCurrency(previousBalance), style: baseStyle()),
                ],
              ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(t('bill.totalDue'), style: baseStyle(bold: true)),
                pw.Text(
                  formatCurrency(amountDue),
                  style: baseStyle(bold: true),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(t('bill.paid'), style: baseStyle()),
                pw.Text(formatCurrency(paidAmount), style: baseStyle()),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(t('bill.remaining'), style: baseStyle(bold: true)),
                pw.Text(
                  formatCurrency(remaining),
                  style: baseStyle(bold: true),
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                t('bill.notes', {'notes': notes}),
                style: baseStyle(),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                t('bill.thankYou'),
                style: baseStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
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
