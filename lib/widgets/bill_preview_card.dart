import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../utils/num_format.dart';

class BillPreviewCard extends StatelessWidget {
  final Bill bill;
  const BillPreviewCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bill.retailerName ?? 'Retailer #${bill.retailerId}',
                style: Theme.of(context).textTheme.titleLarge),
            Text(DateFormat('dd-MM-yyyy').format(bill.date), style: const TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  TableRow(children: [
                    _headerCell('Product'),
                    _headerCell('Given'),
                    _headerCell('Returned'),
                    _headerCell('Sold'),
                    _headerCell('Rate'),
                    _headerCell('Amount'),
                  ]),
                  ...bill.items.map((i) => TableRow(children: [
                        _dataCell(i.productName),
                        _dataCell(i.givenQty.qty),
                        _dataCell(i.returnedQty.qty),
                        _dataCell(i.soldQty.qty),
                        _dataCell(i.rate.toStringAsFixed(2)),
                        _dataCell(i.amount.toStringAsFixed(2)),
                      ])),
                ],
              ),
            ),
            const Divider(height: 24),
            _row('Subtotal', currency.format(bill.subtotal)),
            _row('Commission (${bill.commissionPercent.toStringAsFixed(0)}%)', '- ${currency.format(bill.commissionAmount)}'),
            _row('Final Total', currency.format(bill.finalTotal), bold: true),
            _row('Cash Paid', '- ${currency.format(bill.cashPaid)}'),
            const Divider(),
            _row('Grand Total (Still Owed)', currency.format(bill.grandTotal), bold: true, big: true),
            if (bill.grandTotal <= 0.005 && bill.settledAmount > 0.005) ...[
              const SizedBox(height: 4),
              _row('Settled', currency.format(bill.settledAmount), color: const Color(0xFF10B981)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        softWrap: false,
      ),
    );
  }

  Widget _dataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        softWrap: false,
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool big = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: big ? 16.5 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 10),
          Text(value, style: style, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}