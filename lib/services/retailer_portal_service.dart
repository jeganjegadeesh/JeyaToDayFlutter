import 'api_service.dart';
import '../config/network_url.dart';
import '../models/stock_entry.dart';
import '../models/cash_payment.dart';
import '../models/bill.dart';

class RetailerPortalService {
  static Future<List<StockEntry>> receivedStock() async {
    final res = await ApiService.get(NetworkUrl.myReceivedStock);
    final List data = res['data'] ?? res;
    return data.map((e) => StockEntry.fromJson(e)).toList();
  }

  static Future<List<StockEntry>> returnedStock() async {
    final res = await ApiService.get(NetworkUrl.myReturnedStock);
    final List data = res['data'] ?? res;
    return data.map((e) => StockEntry.fromJson(e)).toList();
  }

  static Future<List<CashPayment>> payments() async {
    final res = await ApiService.get(NetworkUrl.myPayments);
    final List data = res['data'] ?? res;
    return data.map((e) => CashPayment.fromJson(e)).toList();
  }

  static Future<List<Bill>> bills() async {
    final res = await ApiService.get(NetworkUrl.myBills);
    final List data = res['data'] ?? res;
    return data.map((e) => Bill.fromJson(e)).toList();
  }

  static Future<Bill> billShow(int id) async {
    final res = await ApiService.get(NetworkUrl.myBillById(id));
    return Bill.fromJson(res);
  }
}
