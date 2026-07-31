import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../l10n/app_localizations.dart';
import '../models/bill.dart';
import '../models/company.dart';
import '../services/api_service.dart';
import '../services/bill_service.dart';
import '../services/bluetooth_printer_service.dart';
import 'dialogs.dart';
import 'printer_picker_dialog.dart';

const _kAccentBlue = Color(0xFF3B82F6);
const _kReceiptCream = Color(0xFFF7F6EF);
const _kReceiptInk = Color(0xFF1E2430);

/// Shows a receipt-shaped popup right after a bill is generated.
///
/// * Ticking "Settle in Full" + Print settles the bill's full outstanding
///   amount and then opens the print dialog for the receipt.
/// * Leaving it unchecked + Print just prints the receipt, leaving the bill
///   generated but not settled ("not now").
/// * Cancel closes the popup without printing or settling anything.
///
/// Returns the (possibly updated) [Bill] on Print, or `null` on Cancel.
Future<Bill?> showBillReceiptDialog(
  BuildContext context, {
  required Bill bill,
  Company? company,
}) async {
  bool settleInFull = bill.grandTotal > 0.005;
  bool busy = false;
  Bill current = bill;

  // Check (and silently try to restore) the Bluetooth printer connection
  // right away, so the dialog opens already knowing whether to show the
  // Print button or the Connect Printer button.
  final container = ProviderScope.containerOf(context, listen: false);
  await container.read(printerConnectionProvider.notifier).refresh();
  if (!context.mounted) return null;

  return showDialog<Bill?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final t = ctx.l10n;
        final hasOutstanding = current.grandTotal > 0.005;

        Future<void> onPrint() async {
          setDialogState(() => busy = true);
          try {
            if (hasOutstanding && settleInFull) {
              current = await BillService.settle(current.id!, current.grandTotal);
              setDialogState(() {});
            }
            final printed = await container.read(printerConnectionProvider.notifier).printBill(current, company);
            if (!printed) {
              setDialogState(() => busy = false);
              if (ctx.mounted) showSnack(ctx, t.t('printFailed'), isError: true);
              return;
            }
            if (ctx.mounted) Navigator.pop(ctx, current);
          } on ApiException catch (e) {
            setDialogState(() => busy = false);
            if (ctx.mounted) showSnack(ctx, e.message, isError: true);
          } catch (_) {
            setDialogState(() => busy = false);
          }
        }

        Future<void> onPdfPrint() async {
          setDialogState(() => busy = true);
          try {
            if (hasOutstanding && settleInFull) {
              current = await BillService.settle(current.id!, current.grandTotal);
              setDialogState(() {});
            }
            await Printing.layoutPdf(
              onLayout: (format) => _buildReceiptPdf(current, company, format),
            );
            if (ctx.mounted) Navigator.pop(ctx, current);
          } on ApiException catch (e) {
            setDialogState(() => busy = false);
            if (ctx.mounted) showSnack(ctx, e.message, isError: true);
          } catch (_) {
            setDialogState(() => busy = false);
          }
        }

        Future<void> onConnectPrinter() async {
          final connected = await showPrinterPickerDialog(ctx);
          if (connected) setDialogState(() {});
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: _ReceiptPaper(bill: current, company: company),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Consumer(
                      builder: (consumerCtx, ref, _) {
                        final printerState = ref.watch(printerConnectionProvider);
                        final printerReady = printerState.connected;

                        return Column(
                          children: [
                            if (hasOutstanding)
                              CheckboxListTile(
                                value: settleInFull,
                                onChanged: busy ? null : (v) => setDialogState(() => settleInFull = v ?? false),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                                activeColor: _kAccentBlue,
                                title: Text(t.t('settleInFull'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${t.t('outstandingAmount')}: Rs. ${current.grandTotal.toStringAsFixed(2)}'),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    printerState.checking
                                        ? Icons.bluetooth_searching
                                        : printerReady
                                            ? Icons.bluetooth_connected
                                            : Icons.bluetooth_disabled,
                                    size: 16,
                                    color: printerReady ? Colors.green.shade600 : Theme.of(ctx).colorScheme.outline,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      printerState.checking
                                          ? t.t('checkingPrinter')
                                          : printerReady
                                              ? '${t.t('connectedTo')}: ${printerState.deviceName ?? ''}'
                                              : t.t('notConnectedToPrinter'),
                                      style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: busy ? null : () => Navigator.pop(ctx, null),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(t.t('cancel')),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: printerReady
                                      ? FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _kAccentBlue,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: busy ? null : onPrint,
                                          icon: busy
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : const Icon(Icons.print_outlined),
                                          label: Text(busy ? t.t('printing') : t.t('print')),
                                        )
                                      : FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _kAccentBlue,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: (busy || printerState.checking) ? null : onConnectPrinter,
                                          icon: const Icon(Icons.bluetooth),
                                          label: Text(t.t('connectPrinter')),
                                        ),
                                ),
                              ],
                            ),
                            if (printerReady) ...[
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: busy ? null : onPdfPrint,
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                                child: Text(
                                  t.t('printAsPdfInstead'),
                                  style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The on-screen receipt preview — visually mirrors the printed PDF.
class _ReceiptPaper extends StatelessWidget {
  final Bill bill;
  final Company? company;
  const _ReceiptPaper({required this.bill, required this.company});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kReceiptCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Image.asset('assets/logo.png', height: 44, fit: BoxFit.contain),
          const SizedBox(height: 8),
          Text(
            (company?.name ?? '').toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _kReceiptInk, letterSpacing: 0.5),
          ),
          if (company?.fullAddress != null) ...[
            const SizedBox(height: 4),
            Text(company!.fullAddress!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: _kReceiptInk)),
          ],
          if (company?.contactNumber != null || company?.gstNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (company?.contactNumber != null) 'PH: ${company!.contactNumber}',
                if (company?.gstNumber != null) 'GST: ${company!.gstNumber}',
              ].join('   '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _kReceiptInk, fontWeight: FontWeight.w600),
            ),
          ],
          _dashedDivider(),
          _receiptRow(t.t('customer'), bill.retailerName ?? 'Retailer #${bill.retailerId}'),
          _receiptRow(t.t('date'), DateFormat('dd-MM-yyyy').format(bill.date)),
          _receiptRow(t.t('billNo'), bill.id != null ? '#INV-${bill.id}' : '—'),
          _dashedDivider(),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1.3),
              5: FlexColumnWidth(1.6),
            },
            children: [
              TableRow(children: [
                _headCell('ITEM'),
                _headCell('G'),
                _headCell('R'),
                _headCell('S'),
                _headCell('RATE'),
                _headCell('AMT', end: true),
              ]),
              ...bill.items.map((i) => TableRow(children: [
                    _cell(i.productName),
                    _cell(i.givenQty.toStringAsFixed(0)),
                    _cell(i.returnedQty.toStringAsFixed(0)),
                    _cell(i.soldQty.toStringAsFixed(0), bold: true),
                    _cell(i.rate.toStringAsFixed(2)),
                    _cell(i.amount.toStringAsFixed(2), bold: true, end: true),
                  ])),
            ],
          ),
          _dashedDivider(),
          _totalRow('Subtotal', currency.format(bill.subtotal)),
          _totalRow('Commission (${bill.commissionPercent.toStringAsFixed(0)}%)', '- ${currency.format(bill.commissionAmount)}'),
          _totalRow('Final Total', currency.format(bill.finalTotal), bold: true),
          _totalRow('Cash Paid', '- ${currency.format(bill.cashPaid)}'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _kReceiptInk, width: 1.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(t.t('grandTotalBillAmount').toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kReceiptInk)),
                const SizedBox(height: 2),
                Text(currency.format(bill.finalTotal),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kReceiptInk)),
              ],
            ),
          ),
          if (bill.grandTotal > 0.005) ...[
            const SizedBox(height: 6),
            _totalRow(t.t('balanceDueTx'), currency.format(bill.grandTotal), bold: true),
          ] else if (bill.settledAmount > 0.005) ...[
            const SizedBox(height: 6),
            _totalRow(t.t('settledLabel'), currency.format(bill.settledAmount), bold: true),
          ],
        ],
      ),
    );
  }

  Widget _dashedDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter()),
      );

  Widget _receiptRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: _kReceiptInk)),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kReceiptInk)),
            ),
          ],
        ),
      );

  Widget _headCell(String text, {bool end = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(text,
            textAlign: end ? TextAlign.right : TextAlign.left,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _kReceiptInk)),
      );

  Widget _cell(String text, {bool bold = false, bool end = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Text(text,
            textAlign: end ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: _kReceiptInk)),
      );

  Widget _totalRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: _kReceiptInk)),
            Text(value, style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: _kReceiptInk)),
          ],
        ),
      );
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    const dashWidth = 5.0, dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Builds the printable PDF version of the receipt, mirroring [_ReceiptPaper].
Future<Uint8List> _buildReceiptPdf(Bill bill, Company? company, PdfPageFormat format) async {
  final doc = pw.Document();
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  final ink = PdfColor.fromInt(0xFF1E2430);
  final logoBytes = await rootBundle.load('assets/logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  pw.Widget dashed() => pw.Container(
        height: 1,
        margin: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.LayoutBuilder(
          builder: (ctx, cst) {
            final width = cst?.maxWidth ?? 400;
            const dashWidth = 5.0, dashSpace = 4.0;
            final count = (width / (dashWidth + dashSpace)).floor();
            return pw.Row(
              children: List.generate(
                count,
                (_) => pw.Container(width: dashWidth, height: 1, margin: const pw.EdgeInsets.only(right: dashSpace), color: PdfColors.grey400),
              ),
            );
          },
        ),
      );

  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: pw.TextStyle(fontSize: 11, color: ink)),
            pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: ink)),
          ],
        ),
      );

  pw.Widget totalRow(String k, String v, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: pw.TextStyle(fontSize: 12, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: ink)),
            pw.Text(v, style: pw.TextStyle(fontSize: 12, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: ink)),
          ],
        ),
      );

  doc.addPage(
    pw.Page(
      pageFormat: format,
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Image(logoImage, height: 50)),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text((company?.name ?? '').toUpperCase(),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: ink)),
            ),
            if (company?.fullAddress != null)
              pw.Center(child: pw.Text(company!.fullAddress!, style: pw.TextStyle(fontSize: 10, color: ink))),
            if (company?.contactNumber != null || company?.gstNumber != null)
              pw.Center(
                child: pw.Text(
                  [
                    if (company?.contactNumber != null) 'PH: ${company!.contactNumber}',
                    if (company?.gstNumber != null) 'GST: ${company!.gstNumber}',
                  ].join('   '),
                  style: pw.TextStyle(fontSize: 10, color: ink),
                ),
              ),
            dashed(),
            kv('Customer', bill.retailerName ?? 'Retailer #${bill.retailerId}'),
            kv('Date', DateFormat('dd-MM-yyyy').format(bill.date)),
            kv('Bill No', bill.id != null ? '#INV-${bill.id}' : '-'),
            dashed(),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(children: [
                  pw.Text('ITEM', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.Text('G', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.Text('R', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.Text('S', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.Text('RATE', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.Text('AMT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: ink)),
                ]),
                ...bill.items.map((i) => pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text(i.productName, style: pw.TextStyle(fontSize: 10, color: ink))),
                      pw.Text(i.givenQty.toStringAsFixed(0), style: pw.TextStyle(fontSize: 10, color: ink)),
                      pw.Text(i.returnedQty.toStringAsFixed(0), style: pw.TextStyle(fontSize: 10, color: ink)),
                      pw.Text(i.soldQty.toStringAsFixed(0), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink)),
                      pw.Text(i.rate.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, color: ink)),
                      pw.Text(i.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink)),
                    ])),
              ],
            ),
            dashed(),
            totalRow('Subtotal', currency.format(bill.subtotal)),
            totalRow('Commission (${bill.commissionPercent.toStringAsFixed(0)}%)', '- ${currency.format(bill.commissionAmount)}'),
            totalRow('Final Total', currency.format(bill.finalTotal), bold: true),
            totalRow('Cash Paid', '- ${currency.format(bill.cashPaid)}'),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: ink, width: 1.2), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                children: [
                  pw.Text('GRAND TOTAL (BILL AMOUNT)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.SizedBox(height: 2),
                  pw.Text(currency.format(bill.finalTotal), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: ink)),
                ],
              ),
            ),
            if (bill.grandTotal > 0.005) ...[
              pw.SizedBox(height: 6),
              totalRow('Balance Due', currency.format(bill.grandTotal), bold: true),
            ] else if (bill.settledAmount > 0.005) ...[
              pw.SizedBox(height: 6),
              totalRow('Settled', currency.format(bill.settledAmount), bold: true),
            ],
          ],
        );
      },
    ),
  );

  return doc.save();
}