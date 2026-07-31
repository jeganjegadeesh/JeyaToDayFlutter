import 'dart:async';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill.dart';
import '../models/company.dart';
import '../models/receipt_label.dart';

const _prefsMacKey = 'aj_printer_mac';
const _prefsNameKey = 'aj_printer_name';

/// Current state of the Bluetooth thermal printer connection.
class PrinterConnectionState {
  final bool checking;
  final bool connecting;
  final bool connected;
  final String? deviceName;
  final String? deviceMac;

  const PrinterConnectionState({
    this.checking = false,
    this.connecting = false,
    this.connected = false,
    this.deviceName,
    this.deviceMac,
  });

  PrinterConnectionState copyWith({
    bool? checking,
    bool? connecting,
    bool? connected,
    String? deviceName,
    String? deviceMac,
  }) {
    return PrinterConnectionState(
      checking: checking ?? this.checking,
      connecting: connecting ?? this.connecting,
      connected: connected ?? this.connected,
      deviceName: deviceName ?? this.deviceName,
      deviceMac: deviceMac ?? this.deviceMac,
    );
  }
}

/// Manages the connection to a paired Bluetooth thermal receipt printer and
/// builds/sends the ESC/POS bytes for a [Bill].
///
/// * [refresh] checks whether we're already connected, and silently tries to
///   reconnect to the last-used printer (Bluetooth classic connections often
///   drop when the app is backgrounded).
/// * [pairedDevices] lists devices already paired in the phone's Bluetooth
///   settings, for the "select a printer" picker.
/// * [connectTo] connects to a chosen device and remembers it for next time.
class PrinterConnectionNotifier extends StateNotifier<PrinterConnectionState> {
  PrinterConnectionNotifier() : super(const PrinterConnectionState());

  /// Checks the live connection status and attempts a silent reconnect to
  /// the previously-selected printer if we're not currently connected.
  /// Call this every time a print button is about to be shown.
  Future<void> refresh() async {
    state = state.copyWith(checking: true);
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        state = state.copyWith(checking: false, connected: true);
        return;
      }

      // Not connected right now — try to silently reconnect to the last
      // printer the user picked, if any.
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_prefsMacKey);
      final savedName = prefs.getString(_prefsNameKey);
      if (savedMac == null) {
        state = state.copyWith(checking: false, connected: false, deviceName: null, deviceMac: null);
        return;
      }

      final bluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (!bluetoothOn) {
        state = state.copyWith(checking: false, connected: false);
        return;
      }

      final reconnected = await PrintBluetoothThermal.connect(macPrinterAddress: savedMac);
      state = state.copyWith(
        checking: false,
        connected: reconnected,
        deviceMac: savedMac,
        deviceName: savedName,
      );
    } catch (_) {
      state = state.copyWith(checking: false, connected: false);
    }
  }

  /// Returns whether the device's Bluetooth radio is currently on.
  Future<bool> isBluetoothEnabled() => PrintBluetoothThermal.bluetoothEnabled;

  /// Lists devices already paired with this phone (Android) / nearby
  /// devices (iOS), so the user can pick their printer from a simple list.
  Future<List<BluetoothInfo>> pairedDevices() => PrintBluetoothThermal.pairedBluetooths;

  /// Connects to the given paired device and remembers it so future screens
  /// can auto-reconnect via [refresh].
  Future<bool> connectTo(BluetoothInfo device) async {
    state = state.copyWith(connecting: true);
    try {
      final success = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsMacKey, device.macAdress);
        await prefs.setString(_prefsNameKey, device.name);
        state = state.copyWith(
          connecting: false,
          connected: true,
          deviceMac: device.macAdress,
          deviceName: device.name,
        );
      } else {
        state = state.copyWith(connecting: false, connected: false);
      }
      return success;
    } catch (_) {
      state = state.copyWith(connecting: false, connected: false);
      return false;
    }
  }

  /// Disconnects from the current printer. The saved device is kept so the
  /// next [refresh] can offer a quick reconnect.
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Ignore — we still reset local state below.
    }
    state = state.copyWith(connected: false);
  }

  /// Builds the ESC/POS ticket for [bill] and sends it to the connected
  /// printer. Returns true if the bytes were written successfully.
  Future<bool> printBill(Bill bill, Company? company, ReceiptLabels labels) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      state = state.copyWith(connected: false);
      return false;
    }
    final bytes = await _buildBillTicket(bill, company, labels);
    final result = await PrintBluetoothThermal.writeBytes(bytes);
    return result;
  }
}

final printerConnectionProvider = StateNotifierProvider<PrinterConnectionNotifier, PrinterConnectionState>((ref) {
  return PrinterConnectionNotifier();
});
/// Converts an [image] to raw ESC/POS "GS v 0" raster bitmap bytes.
/// Written by hand because esc_pos_utils_plus's own `imageRaster()` throws
/// "Cannot add to a fixed-length list" on some image widths.
List<int> _buildRasterImageBytes(img.Image image) {
  final width = image.width;
  final height = image.height;
  final bytesPerLine = (width + 7) ~/ 8; // round up — no width restriction needed

  final data = <int>[];
  data.addAll([0x1D, 0x76, 0x30, 0x00]); // GS v 0, m = normal
  data.add(bytesPerLine & 0xFF);
  data.add((bytesPerLine >> 8) & 0xFF);
  data.add(height & 0xFF);
  data.add((height >> 8) & 0xFF);

  for (int y = 0; y < height; y++) {
    for (int b = 0; b < bytesPerLine; b++) {
      int byte = 0;
      for (int bit = 0; bit < 8; bit++) {
        final x = b * 8 + bit;
        if (x < width) {
          final pixel = image.getPixel(x, y);
          final lum = img.getLuminance(pixel);
          if (lum < 255) {
            // threshold — tune this (0-255) if the logo prints too light/dark.
            // Lower = only very dark pixels print as ink.
            byte |= (0x80 >> bit);
          }
        }
      }
      data.add(byte);
    }
  }
  return data;
}

/// Builds the raw ESC/POS bytes for a 2-inch (58mm) portable thermal
/// printer, mirroring the layout of the PDF receipt.
Future<List<int>> _buildBillTicket(Bill bill, Company? company, ReceiptLabels labels) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm58, profile);
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  List<int> bytes = [];

  bytes += generator.reset();

  // --- Logo ---
  try {
    final logoBytes = await rootBundle.load('assets/logo.png');
    final decoded = img.decodePng(logoBytes.buffer.asUint8List());
    if (decoded != null) {
      final flattened = img.Image(width: decoded.width, height: decoded.height);
      img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(flattened, decoded);

      var resized = img.copyResize(flattened, width: 220);
      resized = img.grayscale(resized);
      resized = img.contrast(resized, contrast: 160); // punch up contrast so faint gold reads as solid black

      const printerDots = 384; // full print width for 58mm printers at 203dpi
      final canvas = img.Image(width: printerDots, height: resized.height);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      final offsetX = (printerDots - resized.width) ~/ 2; // center horizontally
      img.compositeImage(canvas, resized, dstX: offsetX, dstY: 0);

      bytes += _buildRasterImageBytes(canvas);
    }
  } catch (e) {
    print("Logo print skipped: $e");
  }

  if (company?.name != null) {
    bytes += generator.text(
      company!.name.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size1),
    );
  }
  if (company?.fullAddress != null) {
    bytes += generator.text(company!.fullAddress!, styles: const PosStyles(align: PosAlign.center));
  }
  if (company?.contactNumber != null || company?.gstNumber != null) {
    final line = [
      if (company?.contactNumber != null) 'PH: ${company!.contactNumber}',
      if (company?.gstNumber != null) 'GST: ${company!.gstNumber}',
    ].join('  ');
    bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
  }

  bytes += generator.hr();
  bytes += generator.text('${labels.customer}: ${bill.retailerName ?? '${labels.retailer} #${bill.retailerId}'}');
  bytes += generator.text('${labels.date}: ${DateFormat('dd-MM-yyyy').format(bill.date)}');
  bytes += generator.text('${labels.billNo}: ${bill.id != null ? '#INV-${bill.id}' : '-'}');
  bytes += generator.hr(len: 0);

  const headBold = PosStyles(fontType: PosFontType.fontA, bold: true, align: PosAlign.right);
  const cellNormal = PosStyles(fontType: PosFontType.fontA);
  const cellBold = PosStyles(fontType: PosFontType.fontA, bold: true);
  const cellBoldRight = PosStyles(fontType: PosFontType.fontA, bold: true, align: PosAlign.right);
  const cellRight = PosStyles(fontType: PosFontType.fontA, align: PosAlign.right);
  const cellLeft = PosStyles(fontType: PosFontType.fontA, align: PosAlign.left);

  // Compact header — same 3-column split (7 / 2 / 3) as the item rows below,
  // so the columns actually line up under one another.
    bytes += generator.text(labels.item, styles: cellBold);
  bytes += generator.row([
    PosColumn(text: '${labels.given}  ${labels.returned}  ${labels.sold}', width: 7, styles: const PosStyles(fontType: PosFontType.fontA, bold: true)),
    PosColumn(text: labels.rate, width: 2, styles: headBold),
    PosColumn(text: labels.amount, width: 3, styles: headBold),
  ]);

  bytes += generator.hr(ch: '-');

  for (final item in bill.items) {
    bytes += generator.text(item.productName, styles: cellBold);
    bytes += generator.row([
      PosColumn(
        text: '${item.givenQty.toStringAsFixed(0)}  ${item.returnedQty.toStringAsFixed(0)}  ${item.soldQty.toStringAsFixed(0)}',
        width: 6,
        styles: cellNormal,
      ),
      PosColumn(text: item.rate.toStringAsFixed(0), width: 3, styles: cellLeft),
      PosColumn(text: item.amount.toStringAsFixed(2), width: 3, styles: cellBoldRight),
    ]);
  }
  
  
  bytes += generator.hr();
  bytes += _totalRow(generator, labels.subtotal, currency.format(bill.subtotal));
  bytes += _totalRow(generator, '${labels.commission} (${bill.commissionPercent.toStringAsFixed(0)}%)', '-${currency.format(bill.commissionAmount)}');
  bytes += _totalRow(generator, labels.finalTotal, currency.format(bill.finalTotal), bold: true);
  bytes += _totalRow(generator, labels.cashPaid, '-${currency.format(bill.cashPaid)}');
  bytes += generator.hr();

  bytes += generator.text(labels.grandTotalBillAmount.toUpperCase(), styles: const PosStyles(align: PosAlign.center, bold: true));
  bytes += generator.text(
    currency.format(bill.finalTotal),
    styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
  );

  if (bill.grandTotal > 0.005) {
    bytes += _totalRow(generator, labels.balanceDue, currency.format(bill.grandTotal), bold: true);
  } else if (bill.settledAmount > 0.005) {
    bytes += _totalRow(generator, labels.settled, currency.format(bill.settledAmount), bold: true);
  }

  bytes += generator.feed(2);
  bytes += generator.cut();
  return bytes;
}

List<int> _totalRow(Generator generator, String label, String value, {bool bold = false}) {
  return generator.row([
    PosColumn(text: label, width: 6, styles: PosStyles(fontType: PosFontType.fontA, bold: bold, align: PosAlign.left)),
    PosColumn(text: value, width: 6, styles: PosStyles(fontType: PosFontType.fontA, bold: bold, align: PosAlign.right)),
  ]);
}
