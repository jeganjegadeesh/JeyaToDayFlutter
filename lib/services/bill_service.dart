import 'api_service.dart';
import '../config/network_url.dart';
import '../models/bill.dart';

class BillService {
  static Future<Bill> preview(int retailerId, String date) async {
    final res = await ApiService.post(NetworkUrl.billsPreview, body: {
      'retailer_id': retailerId,
      'date': date,
    });
    return Bill.fromJson(res);
  }

  /// [cashCollectedNow] optionally settles part/all of the bill's grand
  /// total immediately as part of generation (the post-generate
  /// confirmation step - "did the retailer pay now?").
  static Future<Bill> generate(int retailerId, String date, {double? cashCollectedNow}) async {
    final res = await ApiService.post(NetworkUrl.billsGenerate, body: {
      'retailer_id': retailerId,
      'date': date,
      if (cashCollectedNow != null) 'cash_collected_now': cashCollectedNow,
    });
    return Bill.fromJson(res);
  }

  static Future<List<Bill>> list({int? retailerId}) async {
    final res = await ApiService.get(NetworkUrl.bills, query: {
      if (retailerId != null) 'retailer_id': retailerId,
    });
    final List data = res['data'] ?? res;
    return data.map((e) => Bill.fromJson(e)).toList();
  }

  static Future<Bill> show(int id) async {
    final res = await ApiService.get(NetworkUrl.billById(id));
    return Bill.fromJson(res);
  }

  /// Records cash collected from the retailer against this bill's
  /// outstanding grand total (full or partial), any time after generation.
  static Future<Bill> settle(int id, double amount) async {
    final res = await ApiService.post(NetworkUrl.billSettle(id), body: {
      'amount': amount,
    });
    return Bill.fromJson(res);
  }

  static Future<void> delete(int id) async {
    await ApiService.delete(NetworkUrl.billById(id));
  }
}