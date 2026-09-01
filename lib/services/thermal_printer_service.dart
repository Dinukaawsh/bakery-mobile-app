import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedPrinter {
  const SavedPrinter({required this.name, required this.mac});

  final String name;
  final String mac;
}

class ThermalPrinterException implements Exception {
  ThermalPrinterException(this.code);

  final String code;

  @override
  String toString() => code;
}

class ThermalPrinterService {
  ThermalPrinterService._();

  static final ThermalPrinterService instance = ThermalPrinterService._();

  static const _macKey = 'thermal_printer_mac';
  static const _nameKey = 'thermal_printer_name';
  static const _paperWidthPx80 = 576;
  static const _bandHeightPx = 220;
  static const _maxReceiptHeightPx = 3200;
  static const _connectTimeout = Duration(seconds: 15);

  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS || Platform.isWindows);

  int _printerSortScore(String name) {
    final value = name.toLowerCase();
    if (value.contains('print') || value.contains('printer')) return 0;
    if (value.contains('xp') ||
        value.contains('rpp') ||
        value.contains('mpt') ||
        value.contains('pos')) {
      return 1;
    }
    return 2;
  }

  List<BluetoothInfo> sortLikelyPrinters(List<BluetoothInfo> devices) {
    final sorted = [...devices];
    sorted.sort((a, b) {
      final score =
          _printerSortScore(a.name).compareTo(_printerSortScore(b.name));
      if (score != 0) return score;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  bool looksLikePrinter(String name) => _printerSortScore(name) < 2;

  Future<bool> requestBluetoothPermissions() async {
    return PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<SavedPrinter?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_macKey);
    final name = prefs.getString(_nameKey);
    if (mac == null || mac.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    return SavedPrinter(name: name, mac: mac);
  }

  Future<void> savePrinter(SavedPrinter printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macKey, printer.mac);
    await prefs.setString(_nameKey, printer.name);
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_macKey);
    await prefs.remove(_nameKey);
  }

  Future<void> ensureReady() async {
    if (!isSupported) {
      throw ThermalPrinterException('printer.unsupported');
    }

    final granted = await requestBluetoothPermissions();
    if (!granted) {
      throw ThermalPrinterException('printer.permissionDenied');
    }

    final pluginGranted =
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!pluginGranted) {
      throw ThermalPrinterException('printer.permissionDenied');
    }

    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw ThermalPrinterException('printer.bluetoothOff');
    }
  }

  Future<List<BluetoothInfo>> listPairedPrinters() async {
    await ensureReady();
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    if (devices.isEmpty) {
      throw ThermalPrinterException('printer.notPaired');
    }
    return sortLikelyPrinters(devices);
  }

  Future<bool> connect(String mac) async {
    await ensureReady();
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: mac).timeout(
        _connectTimeout,
        onTimeout: () => false,
      );
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _releaseConnection() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Best-effort cleanup so the printer does not keep feeding.
    }
  }

  Future<T> _withPrinterSession<T>(
    String mac,
    Future<T> Function() action,
  ) async {
    await _ensureLiveConnection(mac);
    try {
      return await action();
    } finally {
      await _releaseConnection();
    }
  }

  Future<void> _ensureLiveConnection(String mac) async {
    await PrintBluetoothThermal.disconnect;
    await Future<void>.delayed(const Duration(milliseconds: 500));

    var connected = await connect(mac);
    if (!connected) {
      await PrintBluetoothThermal.disconnect;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      connected = await connect(mac);
    }

    if (!connected) {
      throw ThermalPrinterException('printer.connectFailed');
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));

    final live = await PrintBluetoothThermal.connectionStatus;
    if (!live) {
      throw ThermalPrinterException('printer.connectFailed');
    }
  }

  Future<bool> _writeBytes(List<int> bytes) async {
    if (bytes.isEmpty) return true;

    // The plugin prepends a line-feed on every writeBytes call. Sending many
    // small chunks causes continuous blank label feeds on gap/label paper.
    return PrintBluetoothThermal.writeBytes(bytes).timeout(
      const Duration(seconds: 45),
      onTimeout: () => false,
    );
  }

  Future<void> _finishJob(Generator generator) async {
    final ok = await _writeBytes([
      ...generator.feed(2),
      ...generator.reset(),
    ]);
    if (!ok) {
      throw ThermalPrinterException('printer.printFailed');
    }
  }

  img.Image _trimBlankMargins(img.Image source) {
    var top = 0;
    var bottom = source.height - 1;

    while (top < source.height) {
      var rowBlank = true;
      for (var x = 0; x < source.width; x++) {
        if (img.getLuminance(source.getPixel(x, top)) < 165) {
          rowBlank = false;
          break;
        }
      }
      if (!rowBlank) break;
      top++;
    }

    while (bottom >= top) {
      var rowBlank = true;
      for (var x = 0; x < source.width; x++) {
        if (img.getLuminance(source.getPixel(x, bottom)) < 165) {
          rowBlank = false;
          break;
        }
      }
      if (!rowBlank) break;
      bottom--;
    }

    if (bottom < top) {
      return img.Image(width: source.width, height: 1);
    }

    return img.copyCrop(
      source,
      x: 0,
      y: top,
      width: source.width,
      height: bottom - top + 1,
    );
  }

  img.Image _limitHeight(img.Image source) {
    if (source.height <= _maxReceiptHeightPx) return source;
    return img.copyResize(
      source,
      height: _maxReceiptHeightPx,
      interpolation: img.Interpolation.linear,
    );
  }

  Future<img.Image> _renderPdfPage(
    List<int> pdfBytes, {
    required int targetWidthPx,
  }) async {
    late final PdfRaster raster;
    try {
      raster = await Printing.raster(
        Uint8List.fromList(pdfBytes),
        pages: const [0],
        dpi: 180,
      ).first.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw ThermalPrinterException('printer.renderFailed');
    }

    if (raster.width <= 0 || raster.height <= 0) {
      throw ThermalPrinterException('printer.renderFailed');
    }

    var image = img.Image.fromBytes(
      width: raster.width,
      height: raster.height,
      bytes: raster.pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    if (image.width != targetWidthPx) {
      image = img.copyResize(
        image,
        width: targetWidthPx,
        interpolation: img.Interpolation.linear,
      );
    }

    return _limitHeight(_trimBlankMargins(_binarize(image)));
  }

  img.Image _binarize(img.Image source) {
    final output = img.Image(width: source.width, height: source.height);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final luma = img.getLuminance(source.getPixel(x, y));
        output.setPixel(
          x,
          y,
          luma < 165 ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255),
        );
      }
    }
    return output;
  }

  List<int> _bandBytes(Generator generator, img.Image band) {
    return generator.imageRaster(
      band,
      align: PosAlign.center,
      highDensityHorizontal: true,
      highDensityVertical: true,
    );
  }

  Future<bool> _printImageBands({
    required Generator generator,
    required img.Image image,
  }) async {
    if (image.height <= 0) {
      await _finishJob(generator);
      return true;
    }

    var y = 0;
    while (y < image.height) {
      final height = math.min(_bandHeightPx, image.height - y);
      final band = img.copyCrop(
        image,
        x: 0,
        y: y,
        width: image.width,
        height: height,
      );

      final ok = await _writeBytes(_bandBytes(generator, band));
      if (!ok) return false;

      y += height;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    await _finishJob(generator);
    return true;
  }

  Future<bool> _printWithPaper({
    required List<int> pdfBytes,
    required PaperSize paperSize,
    required int targetWidthPx,
  }) async {
    final image = await _renderPdfPage(
      pdfBytes,
      targetWidthPx: targetWidthPx,
    );
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final resetOk = await _writeBytes(generator.reset());
    if (!resetOk) return false;
    return _printImageBands(generator: generator, image: image);
  }

  Future<bool> printTestPage({required String mac}) async {
    await ensureReady();
    return _withPrinterSession(mac, () async {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final ok = await _writeBytes([
        ...generator.reset(),
        ...generator.text(
          'Bakery printer test',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
        ...generator.text('OK'),
        ...generator.feed(2),
        ...generator.reset(),
      ]);
      if (!ok) {
        throw ThermalPrinterException('printer.printFailed');
      }
      return true;
    });
  }

  Future<bool> printPdfReceipt({
    required String mac,
    required List<int> pdfBytes,
  }) async {
    await ensureReady();
    return _withPrinterSession(mac, () async {
      final printed80 = await _printWithPaper(
        pdfBytes: pdfBytes,
        paperSize: PaperSize.mm80,
        targetWidthPx: _paperWidthPx80,
      );
      if (!printed80) {
        throw ThermalPrinterException('printer.printFailed');
      }
      return true;
    });
  }
}
