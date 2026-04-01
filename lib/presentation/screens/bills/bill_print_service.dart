import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/models/cash_payment_model.dart';

class BillPrintService {
  static Future<void> printBill(
    BuildContext context,
    BillModel bill, {
    List stockEntry = const [],
    List returnEntry = const [],
    List<CashPaymentModel> cashPayments = const [],
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius:
                      pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'A',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Ice Cream Distribution System',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Bill Info
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILL',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        'Bill #${bill.id}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(bill.date))}',
                        style: const pw.TextStyle(
                            fontSize: 12),
                      ),
                      pw.Text(
                        'Retailer: ${bill.retailer?.name ?? ''}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Stock Given Section
              if (stockEntry.isNotEmpty) ...[
                pw.Text(
                  'Stock Given',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.orange100,
                      ),
                      children: [
                        _tableCell('Product',
                            isHeader: true),
                        _tableCell('Quantity',
                            isHeader: true),
                      ],
                    ),
                    ...stockEntry.map<pw.TableRow>(
                        (item) => pw.TableRow(
                              children: [
                                _tableCell(
                                    item.product?.name ??
                                        ''),
                                _tableCell(
                                    '${item.quantity}'),
                              ],
                            )),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              // Returns Section
              if (returnEntry.isNotEmpty) ...[
                pw.Text(
                  'Stock Returned',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.red50,
                      ),
                      children: [
                        _tableCell('Product',
                            isHeader: true),
                        _tableCell('Quantity',
                            isHeader: true),
                      ],
                    ),
                    ...returnEntry
                        .map<pw.TableRow>((item) =>
                            pw.TableRow(
                              children: [
                                _tableCell(
                                    item.product?.name ??
                                        ''),
                                _tableCell(
                                    '${item.quantity}'),
                              ],
                            )),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              // Bill Items
              pw.Text(
                'Bill Details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue800,
                    ),
                    children: [
                      _tableCell('Product',
                          isHeader: true,
                          headerColor: true),
                      _tableCell('Given',
                          isHeader: true,
                          headerColor: true),
                      _tableCell('Return',
                          isHeader: true,
                          headerColor: true),
                      _tableCell('Sold',
                          isHeader: true,
                          headerColor: true),
                      _tableCell('Price',
                          isHeader: true,
                          headerColor: true),
                      _tableCell('Amount',
                          isHeader: true,
                          headerColor: true),
                    ],
                  ),
                  ...bill.items
                      .asMap()
                      .entries
                      .map((e) {
                    final i = e.key;
                    final item = e.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i % 2 == 0
                            ? PdfColors.white
                            : PdfColors.grey50,
                      ),
                      children: [
                        _tableCell(
                            item.product?.name ?? ''),
                        _tableCell(
                            '${item.givenQty}'),
                        _tableCell(
                            '${item.returnedQty}'),
                        _tableCell(
                            '${item.soldQty}'),
                        _tableCell(
                            '₹${item.price.toStringAsFixed(2)}'),
                        _tableCell(
                            '₹${item.amount.toStringAsFixed(2)}'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              if (cashPayments.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  'Cash Payments Received',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.green50),
                      children: [
                        _tableCell('Date', isHeader: true),
                        _tableCell('Note', isHeader: true),
                        _tableCell('Amount', isHeader: true),
                      ],
                    ),
                    ...cashPayments.map((p) => pw.TableRow(
                      children: [
                        _tableCell(DateFormat('dd MMM yyyy').format(DateTime.parse(p.date))),
                        _tableCell(p.note ?? '-'),
                        _tableCell('₹${p.amount.toStringAsFixed(2)}'),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],

              // Summary
              pw.Column(
                children: [
                  _summaryRow('Total Sales', '₹${bill.totalSales.toStringAsFixed(2)}'),
                  pw.Divider(color: PdfColors.grey300),
                  _summaryRow(
                    'Commission (${bill.retailer?.commission ?? 0}%)',
                    '- ₹${bill.commission.toStringAsFixed(2)}',
                    isRed: true,
                  ),
                  pw.Divider(color: PdfColors.grey400),
                  _summaryRow(
                    'Final Amount',
                    '₹${bill.finalAmount.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                  if (bill.paidAmount > 0) ...[
                    pw.Divider(color: PdfColors.grey300),
                    _summaryRow(
                      'Already Paid',
                      '- ₹${bill.paidAmount.toStringAsFixed(2)}',
                      isGreen: true,
                    ),
                    pw.Divider(color: PdfColors.grey400),
                    _summaryRow(
                      'Balance Due',
                      '₹${bill.balanceAmount.toStringAsFixed(2)}',
                      isBold: true,
                      isRed: bill.balanceAmount > 0,
                      isGreen: bill.balanceAmount <= 0,
                    ),
                  ],
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async =>
          pdf.save(),
      name:
          'Bill_${bill.id}_${bill.retailer?.name ?? ''}_${bill.date}',
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool headerColor = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: headerColor
              ? PdfColors.white
              : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isRed = false,
    bool isGreen = false,
  }) {
    final color = isGreen
        ? PdfColors.green700
        : isRed
            ? PdfColors.red700
            : PdfColors.black;
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}