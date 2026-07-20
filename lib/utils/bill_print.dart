import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_locale.dart';
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
  AppLocale locale = AppLocale.en,
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

  pw.Font latinRegular;
  pw.Font latinBold;
  try {
    latinRegular = await PdfGoogleFonts.notoSansRegular();
    latinBold = await PdfGoogleFonts.notoSansBold();
  } catch (_) {
    latinRegular = sinhalaRegular;
    latinBold = sinhalaBold;
  }

  final useSinhalaPrimary = locale == AppLocale.si;
  final primaryRegular = useSinhalaPrimary ? sinhalaRegular : latinRegular;
  final primaryBold = useSinhalaPrimary ? sinhalaBold : latinBold;

  bool containsSinhala(String text) {
    return text.runes.any((rune) => rune >= 0x0D80 && rune <= 0x0DFF);
  }

  pw.TextStyle styleFor(
    String text, {
    double fontSize = 10,
    bool bold = false,
  }) {
    final useSinhalaFont = useSinhalaPrimary || containsSinhala(text);
    final font = useSinhalaFont
        ? (bold ? sinhalaBold : sinhalaRegular)
        : (bold ? latinBold : latinRegular);

    return pw.TextStyle(
      font: font,
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      lineSpacing: useSinhalaFont ? 1.45 : 1.2,
      letterSpacing: useSinhalaFont ? 0.15 : 0,
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
        base: primaryRegular,
        bold: primaryBold,
        icons: primaryRegular,
      ),
      build: (context) {
        final telLabel = t('bill.tel', {'phone': settings.phone});
        final shopLabel = t('bill.shop');
        final deliveryLabel = t('bill.delivery');
        final todaysDropLabel = t('bill.todaysDrop');
        final previousUnpaidLabel = t('bill.previousUnpaid');
        final totalDueLabel = t('bill.totalDue');
        final paidLabel = t('bill.paid');
        final remainingLabel = t('bill.remaining');
        final thankYouLabel = t('bill.thankYou');

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                settings.businessName,
                style: styleFor(
                  settings.businessName,
                  fontSize: 14,
                  bold: true,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (settings.ownerName != null && settings.ownerName!.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.ownerName!,
                  style: styleFor(settings.ownerName!, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.address.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.address,
                  style: styleFor(settings.address, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.phone.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  telLabel,
                  style: styleFor(telLabel, fontSize: 9),
                ),
              ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                billNumberLabel,
                style: styleFor(billNumberLabel, bold: true),
              ),
            ),
            pw.Divider(),
            pw.Text(shopLabel, style: styleFor(shopLabel, bold: true)),
            pw.Text(shopName, style: styleFor(shopName)),
            if (shopOwner != null && shopOwner.isNotEmpty)
              pw.Text(shopOwner, style: styleFor(shopOwner)),
            if (shopAddress != null && shopAddress.isNotEmpty)
              pw.Text(shopAddress, style: styleFor(shopAddress)),
            if (shopPhone != null && shopPhone.isNotEmpty)
              pw.Text(shopPhone, style: styleFor(shopPhone)),
            pw.SizedBox(height: 6),
            pw.Text(
              deliveryLabel,
              style: styleFor(deliveryLabel, bold: true),
            ),
            pw.Text(deliveryName, style: styleFor(deliveryName)),
            pw.Text(dateLabel, style: styleFor(dateLabel)),
            pw.SizedBox(height: 6),
            pw.Divider(),
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item.productName,
                        style: styleFor(item.productName),
                      ),
                    ),
                    pw.Text(
                      '${item.quantity}',
                      style: styleFor('${item.quantity}'),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      formatCurrency(item.lineTotal),
                      style: styleFor(formatCurrency(item.lineTotal)),
                    ),
                  ],
                ),
              ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  todaysDropLabel,
                  style: styleFor(todaysDropLabel),
                ),
                pw.Text(
                  formatCurrency(totalAmount),
                  style: styleFor(formatCurrency(totalAmount)),
                ),
              ],
            ),
            if (previousBalance > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    previousUnpaidLabel,
                    style: styleFor(previousUnpaidLabel),
                  ),
                  pw.Text(
                    formatCurrency(previousBalance),
                    style: styleFor(formatCurrency(previousBalance)),
                  ),
                ],
              ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  totalDueLabel,
                  style: styleFor(totalDueLabel, bold: true),
                ),
                pw.Text(
                  formatCurrency(amountDue),
                  style: styleFor(formatCurrency(amountDue), bold: true),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(paidLabel, style: styleFor(paidLabel)),
                pw.Text(
                  formatCurrency(paidAmount),
                  style: styleFor(formatCurrency(paidAmount)),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  remainingLabel,
                  style: styleFor(remainingLabel, bold: true),
                ),
                pw.Text(
                  formatCurrency(remaining),
                  style: styleFor(formatCurrency(remaining), bold: true),
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                t('bill.notes', {'notes': notes}),
                style: styleFor(t('bill.notes', {'notes': notes})),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                thankYouLabel,
                style: styleFor(thankYouLabel, fontSize: 8),
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
