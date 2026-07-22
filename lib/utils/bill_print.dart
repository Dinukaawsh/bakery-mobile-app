import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

bool _containsSinhala(String text) {
  for (final rune in text.runes) {
    if (rune >= 0x0D80 && rune <= 0x0DFF) return true;
  }
  return false;
}

/// Rasterize text with Flutter's shaping engine so Sinhala conjuncts
/// (yansaya / rakaransaya / ZWJ) match the in-app UI.
Future<({Uint8List bytes, double width, double height})> _rasterizeTextPng({
  required String text,
  required double fontSize,
  required bool bold,
  required double maxWidth,
  TextAlign textAlign = TextAlign.left,
  double pixelRatio = 3,
}) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'NotoSansSinhala',
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: const Color(0xFF000000),
        height: 1.35,
      ),
    ),
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  final logicalWidth = painter.width.clamp(1.0, maxWidth);
  final logicalHeight = painter.height.clamp(1.0, 400.0);
  final width = (logicalWidth * pixelRatio).ceil().clamp(1, 4000);
  final height = (logicalHeight * pixelRatio).ceil().clamp(1, 4000);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  painter.paint(canvas, Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  return (
    bytes: bytes!.buffer.asUint8List(),
    width: logicalWidth,
    height: logicalHeight,
  );
}

class _BillTextFactory {
  _BillTextFactory({
    required this.contentWidth,
    required this.latinRegular,
    required this.latinBold,
  });

  final double contentWidth;
  final pw.Font latinRegular;
  final pw.Font latinBold;
  final Map<String, pw.Widget> _cache = {};

  String _key(
    String text, {
    required double fontSize,
    required bool bold,
    required TextAlign align,
  }) {
    return '$fontSize|${bold ? 1 : 0}|${align.index}|$text';
  }

  Future<pw.Widget> build(
    String text, {
    double fontSize = 10,
    bool bold = false,
    TextAlign align = TextAlign.left,
  }) async {
    if (text.isEmpty) return pw.SizedBox();

    final cacheKey = _key(
      text,
      fontSize: fontSize,
      bold: bold,
      align: align,
    );
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    late final pw.Widget widget;
    if (_containsSinhala(text)) {
      final raster = await _rasterizeTextPng(
        text: text,
        fontSize: fontSize,
        bold: bold,
        maxWidth: contentWidth,
        textAlign: align,
      );
      widget = pw.Image(
        pw.MemoryImage(raster.bytes),
        width: raster.width,
        height: raster.height,
      );
    } else {
      widget = pw.Text(
        text,
        textAlign: align == TextAlign.center
            ? pw.TextAlign.center
            : align == TextAlign.right
                ? pw.TextAlign.right
                : pw.TextAlign.left,
        style: pw.TextStyle(
          font: bold ? latinBold : latinRegular,
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          lineSpacing: 1.2,
        ),
      );
    }

    _cache[cacheKey] = widget;
    return widget;
  }
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
  List<BillLineItem> returns = const [],
  double returnsAmount = 0,
  double previousBalance = 0,
  double paidAmount = 0,
  double? remainingAfter,
  String? shopOwner,
  String? shopAddress,
  String? shopPhone,
  String? notes,
}) async {
  // Warm font so TextPainter can resolve NotoSansSinhala on all platforms.
  await rootBundle.load('assets/fonts/NotoSansSinhala-Regular.ttf');
  await rootBundle.load('assets/fonts/NotoSansSinhala-Bold.ttf');

  final latinRegular = pw.Font.helvetica();
  final latinBold = pw.Font.helveticaBold();

  final pageFormat = PdfPageFormat.roll80;
  const margin = 12.0;
  final contentWidth = pageFormat.availableWidth - margin * 2;

  final text = _BillTextFactory(
    contentWidth: contentWidth,
    latinRegular: latinRegular,
    latinBold: latinBold,
  );

  Future<pw.Widget> billText(
    String value, {
    double fontSize = 10,
    bool bold = false,
    TextAlign align = TextAlign.left,
  }) {
    return text.build(
      value,
      fontSize: fontSize,
      bold: bold,
      align: align,
    );
  }

  String itemCalculation(BillLineItem item) {
    return t('bill.itemCalculation', {
      'price': formatCurrency(item.unitPrice),
      'qty': item.quantity,
      'total': formatCurrency(item.lineTotal),
    });
  }

  final dateLabel = _formatDate(saleDate);
  final netToday = totalAmount - returnsAmount;
  final amountDue = previousBalance + netToday;
  final remaining =
      remainingAfter ?? (amountDue - paidAmount).clamp(0, double.infinity);

  final telLabel = t('bill.tel', {'phone': settings.phone});
  final shopLabel = t('bill.shop');
  final deliveryLabel = t('bill.delivery');
  final todaysDropLabel = t('bill.todaysDrop');
  final returnsCreditLabel = t('bill.returnsCredit');
  final estimatedLossLabel = t('bill.estimatedLoss');
  final netTodayLabel = t('bill.netToday');
  final returnsCollectedLabel = t('bill.returnsCollected');
  final previousUnpaidLabel = t('bill.previousUnpaid');
  final totalDueLabel = t('bill.totalDue');
  final paidLabel = t('bill.paid');
  final remainingLabel = t('bill.remaining');
  final thankYouLabel = t('bill.thankYou');
  final notesLabel =
      notes != null && notes.isNotEmpty ? t('bill.notes', {'notes': notes}) : null;

  Future<pw.Widget> summaryRow(
    String label,
    String value, {
    bool bold = false,
  }) async {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: await billText(label, bold: bold)),
        pw.SizedBox(width: 8),
        await billText(value, bold: bold),
      ],
    );
  }

  final children = <pw.Widget>[
    pw.Center(
      child: await billText(
        settings.businessName,
        fontSize: 14,
        bold: true,
        align: TextAlign.center,
      ),
    ),
  ];

  if (settings.ownerName != null && settings.ownerName!.isNotEmpty) {
    children.add(
      pw.Center(
        child: await billText(
          settings.ownerName!,
          fontSize: 9,
          align: TextAlign.center,
        ),
      ),
    );
  }
  if (settings.address.isNotEmpty) {
    children.add(
      pw.Center(
        child: await billText(
          settings.address,
          fontSize: 9,
          align: TextAlign.center,
        ),
      ),
    );
  }
  if (settings.phone.isNotEmpty) {
    children.add(
      pw.Center(
        child: await billText(
          telLabel,
          fontSize: 9,
          align: TextAlign.center,
        ),
      ),
    );
  }

  children.addAll([
    pw.SizedBox(height: 6),
    pw.Center(
      child: await billText(
        billNumberLabel,
        bold: true,
        align: TextAlign.center,
      ),
    ),
    pw.Divider(),
    await billText(shopLabel, bold: true),
    await billText(shopName),
  ]);

  if (shopOwner != null && shopOwner.isNotEmpty) {
    children.add(await billText(shopOwner));
  }
  if (shopAddress != null && shopAddress.isNotEmpty) {
    children.add(await billText(shopAddress));
  }
  if (shopPhone != null && shopPhone.isNotEmpty) {
    children.add(await billText(shopPhone));
  }

  children.addAll([
    pw.SizedBox(height: 6),
    await billText(deliveryLabel, bold: true),
    await billText(deliveryName),
    await billText(dateLabel),
    pw.SizedBox(height: 6),
    pw.Divider(),
  ]);

  for (final item in items) {
    children.add(
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            await billText(item.productName),
            pw.SizedBox(height: 2),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: await billText(itemCalculation(item), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  if (returns.isNotEmpty) {
    children.add(pw.Divider());
    children.add(await billText(returnsCollectedLabel, bold: true));
    children.add(pw.SizedBox(height: 4));
    for (final item in returns) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              await billText(item.productName),
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: await billText(itemCalculation(item), fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }
  }

  children.add(pw.Divider());
  children.add(await summaryRow(todaysDropLabel, formatCurrency(totalAmount)));

  if (returnsAmount > 0) {
    children.add(
      await summaryRow(
        returnsCreditLabel,
        '-${formatCurrency(returnsAmount)}',
      ),
    );
    children.add(
      await summaryRow(
        estimatedLossLabel,
        formatCurrency(returnsAmount),
      ),
    );
    children.add(await summaryRow(netTodayLabel, formatCurrency(netToday)));
  }

  if (previousBalance > 0) {
    children.add(
      await summaryRow(
        previousUnpaidLabel,
        formatCurrency(previousBalance),
      ),
    );
  }

  children.addAll([
    await summaryRow(totalDueLabel, formatCurrency(amountDue), bold: true),
    await summaryRow(paidLabel, formatCurrency(paidAmount)),
    await summaryRow(
      remainingLabel,
      formatCurrency(remaining),
      bold: true,
    ),
  ]);

  if (notesLabel != null) {
    children.add(pw.SizedBox(height: 6));
    children.add(await billText(notesLabel));
  }

  children.addAll([
    pw.SizedBox(height: 10),
    pw.Center(
      child: await billText(
        thankYouLabel,
        fontSize: 9,
        align: TextAlign.center,
      ),
    ),
  ]);

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(margin),
      theme: pw.ThemeData.withFont(
        base: latinRegular,
        bold: latinBold,
        icons: latinRegular,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
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
