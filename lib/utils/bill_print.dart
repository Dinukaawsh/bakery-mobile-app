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

enum _BillScript { latin, sinhala }

class _BillTextRun {
  const _BillTextRun(this.text, this.script);

  final String text;
  final _BillScript script;
}

List<_BillTextRun> _splitBillTextRuns(String text) {
  if (text.isEmpty) return const [];

  _BillScript scriptOf(int rune) {
    if (rune >= 0x0D80 && rune <= 0x0DFF) return _BillScript.sinhala;
    return _BillScript.latin;
  }

  final runs = <_BillTextRun>[];
  final runes = text.runes.toList();
  var currentScript = scriptOf(runes.first);
  final buffer = StringBuffer();

  for (final rune in runes) {
    final script = scriptOf(rune);
    if (script != currentScript && buffer.isNotEmpty) {
      runs.add(_BillTextRun(buffer.toString(), currentScript));
      buffer.clear();
      currentScript = script;
    }
    buffer.writeCharCode(rune);
  }

  if (buffer.isNotEmpty) {
    runs.add(_BillTextRun(buffer.toString(), currentScript));
  }

  return runs;
}

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
  final latinRegular = pw.Font.helvetica();
  final latinBold = pw.Font.helveticaBold();

  pw.TextStyle styleForScript(
    _BillScript script, {
    double fontSize = 10,
    bool bold = false,
  }) {
    final isSinhala = script == _BillScript.sinhala;

    return pw.TextStyle(
      font: isSinhala
          ? (bold ? sinhalaBold : sinhalaRegular)
          : (bold ? latinBold : latinRegular),
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      lineSpacing: isSinhala ? 1.5 : 1.2,
      letterSpacing: isSinhala ? 0.2 : 0,
    );
  }

  pw.Widget billText(
    String text, {
    double fontSize = 10,
    bool bold = false,
    pw.TextAlign? textAlign,
  }) {
    final runs = _splitBillTextRuns(text);
    final style = runs.length == 1
        ? styleForScript(
            runs.first.script,
            fontSize: fontSize,
            bold: bold,
          )
        : null;

    if (style != null) {
      return pw.Text(
        text,
        style: style,
        textAlign: textAlign,
      );
    }

    return pw.RichText(
      textAlign: textAlign ?? pw.TextAlign.left,
      text: pw.TextSpan(
        children: runs
            .map(
              (run) => pw.TextSpan(
                text: run.text,
                style: styleForScript(
                  run.script,
                  fontSize: fontSize,
                  bold: bold,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String itemCalculation(BillLineItem item) {
    return t('bill.itemCalculation', {
      'price': formatCurrency(item.unitPrice),
      'qty': item.quantity,
      'total': formatCurrency(item.lineTotal),
    });
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
        base: latinRegular,
        bold: latinBold,
        icons: latinRegular,
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

        pw.Widget summaryRow(String label, String value, {bool bold = false}) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: billText(label, bold: bold)),
              pw.SizedBox(width: 8),
              billText(value, bold: bold),
            ],
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: billText(
                settings.businessName,
                fontSize: 14,
                bold: true,
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (settings.ownerName != null && settings.ownerName!.isNotEmpty)
              pw.Center(
                child: billText(
                  settings.ownerName!,
                  fontSize: 9,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.address.isNotEmpty)
              pw.Center(
                child: billText(
                  settings.address,
                  fontSize: 9,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.phone.isNotEmpty)
              pw.Center(
                child: billText(
                  telLabel,
                  fontSize: 9,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: billText(
                billNumberLabel,
                bold: true,
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Divider(),
            billText(shopLabel, bold: true),
            billText(shopName),
            if (shopOwner != null && shopOwner.isNotEmpty) billText(shopOwner),
            if (shopAddress != null && shopAddress.isNotEmpty)
              billText(shopAddress),
            if (shopPhone != null && shopPhone.isNotEmpty) billText(shopPhone),
            pw.SizedBox(height: 6),
            billText(deliveryLabel, bold: true),
            billText(deliveryName),
            billText(dateLabel),
            pw.SizedBox(height: 6),
            pw.Divider(),
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    billText(item.productName),
                    pw.SizedBox(height: 2),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: billText(
                        itemCalculation(item),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            pw.Divider(),
            summaryRow(todaysDropLabel, formatCurrency(totalAmount)),
            if (previousBalance > 0)
              summaryRow(
                previousUnpaidLabel,
                formatCurrency(previousBalance),
              ),
            summaryRow(totalDueLabel, formatCurrency(amountDue), bold: true),
            summaryRow(paidLabel, formatCurrency(paidAmount)),
            summaryRow(
              remainingLabel,
              formatCurrency(remaining),
              bold: true,
            ),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              billText(t('bill.notes', {'notes': notes})),
            ],
            pw.SizedBox(height: 10),
            pw.Center(
              child: billText(
                thankYouLabel,
                fontSize: 8,
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
