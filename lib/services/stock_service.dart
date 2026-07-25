import 'api_service.dart';
import '../models/stock_entry.dart';

/// Pass [NetworkUrl.giveStock] or [NetworkUrl.returnStock] as the endpoint.
class StockService {
  final String endpoint; // NetworkUrl.giveStock or NetworkUrl.returnStock
  StockService(this.endpoint);

  Future<List<StockEntry>> list({
    int? retailerId,
    String? dateFrom,
    String? dateTo,
    bool? isBilled,
    int? perPage,
  }) async {
    final res = await ApiService.get(endpoint, query: {
      if (retailerId != null) 'retailer_id': retailerId,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (isBilled != null) 'is_billed': isBilled ? 1 : 0,
      if (perPage != null) 'per_page': perPage,
    });
    final List data = res['data'] ?? res;
    return data.map((e) => StockEntry.fromJson(e)).toList();
  }

  Future<StockEntry> create({
    required int retailerId,
    required String date,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await ApiService.post(endpoint, body: {
      'retailer_id': retailerId,
      'date': date,
      'items': items,
    });
    return StockEntry.fromJson(res);
  }

  Future<StockEntry> update(int id, {String? date, List<Map<String, dynamic>>? items}) async {
    final res = await ApiService.put('$endpoint/$id', body: {
      if (date != null) 'date': date,
      if (items != null) 'items': items,
    });
    return StockEntry.fromJson(res);
  }

  Future<void> delete(int id) async {
    await ApiService.delete('$endpoint/$id');
  }
}