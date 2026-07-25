import 'api_service.dart';
import '../config/network_url.dart';
import '../models/cash_payment.dart';

class CashPaymentService {
  static Future<List<CashPayment>> list({
    int? retailerId,
    String? dateFrom,
    String? dateTo,
    bool? isBilled,
    int? perPage,
  }) async {
    final res = await ApiService.get(NetworkUrl.cashPayments, query: {
      if (retailerId != null) 'retailer_id': retailerId,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (isBilled != null) 'is_billed': isBilled ? 1 : 0,
      if (perPage != null) 'per_page': perPage,
    });
    final List data = res['data'] ?? res;
    return data.map((e) => CashPayment.fromJson(e)).toList();
  }

  static Future<CashPayment> create(int retailerId, String date, double amount) async {
    final res = await ApiService.post(NetworkUrl.cashPayments, body: {
      'retailer_id': retailerId,
      'date': date,
      'amount': amount,
    });
    return CashPayment.fromJson(res);
  }

  static Future<void> delete(int id) async {
    await ApiService.delete(NetworkUrl.cashPaymentById(id));
  }
}