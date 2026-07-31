class ReceiptLabels {
  final String customer, date, billNo, retailer;
  final String item, given, returned, sold, rate, amount;
  final String subtotal, commission, finalTotal, cashPaid;
  final String grandTotalBillAmount, balanceDue, settled;

  const ReceiptLabels({
    required this.customer,
    required this.date,
    required this.billNo,
    required this.retailer,
    required this.item,
    required this.given,
    required this.returned,
    required this.sold,
    required this.rate,
    required this.amount,
    required this.subtotal,
    required this.commission,
    required this.finalTotal,
    required this.cashPaid,
    required this.grandTotalBillAmount,
    required this.balanceDue,
    required this.settled,
  });
}