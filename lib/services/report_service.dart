import 'api_service.dart';
import '../config/network_url.dart';

class ReportService {
  static Future<Map<String, dynamic>> sales(String type, {String? from, String? to, int? retailerId}) async {
    final res = await ApiService.get(NetworkUrl.reportsSales, query: {
      'type': type,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (retailerId != null) 'retailer_id': retailerId,
    });
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> stock(String type, {String? from, String? to, int? retailerId}) async {
    final res = await ApiService.get(NetworkUrl.reportsStock, query: {
      'type': type,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (retailerId != null) 'retailer_id': retailerId,
    });
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> cashReport(String filter, {String? from, String? to}) async {
    final res = await ApiService.get(NetworkUrl.reportsCash, query: {
      'filter': filter,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> mySales() async {
    final res = await ApiService.get(NetworkUrl.myReportsSales);
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> myStock() async {
    final res = await ApiService.get(NetworkUrl.myReportsStock);
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> dashboard(String period) async {
    final res = await ApiService.get(NetworkUrl.dashboard, query: {'period': period});
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> retailerDashboard(String period) async {
    final res = await ApiService.get(NetworkUrl.dashboardRetailer, query: {'period': period});
    return Map<String, dynamic>.from(res);
  }
}