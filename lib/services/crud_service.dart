import 'api_service.dart';

class CrudService<T> {
  final String endpoint;
  final T Function(Map<String, dynamic>) fromJson;
  CrudService(this.endpoint, this.fromJson);

  Future<List<T>> list({Map<String, dynamic>? query}) async {
    final res = await ApiService.get(endpoint, query: query);
    final List data = res['data'] ?? res;
    return data.map((e) => fromJson(e)).toList();
  }

  Future<T> get(int id) async {
    final res = await ApiService.get('$endpoint/$id');
    return fromJson(res['data'] ?? res);
  }

  Future<T> create(Map<String, dynamic> body) async {
    final res = await ApiService.post(endpoint, body: body);
    return fromJson(res['data'] ?? res);
  }

  Future<T> update(int id, Map<String, dynamic> body) async {
    final res = await ApiService.put('$endpoint/$id', body: body);
    return fromJson(res['data'] ?? res);
  }

  /// Create with an attached file (e.g. profile image).
  /// [fields] must be Map<String, String> — stringify non-string values first.
  Future<T> createWithFile(
    Map<String, String> fields, {
    required String fileField,
    required String filePath,
  }) async {
    final res = await ApiService.multipart(
      endpoint,
      fields: fields,
      fileField: fileField,
      filePath: filePath,
      method: 'POST',
    );
    return fromJson(res['data'] ?? res);
  }

  /// Update with an attached file.
  Future<T> updateWithFile(
    int id,
    Map<String, String> fields, {
    required String fileField,
    required String filePath,
  }) async {
    final res = await ApiService.multipart(
      '$endpoint/$id',
      fields: fields,
      fileField: fileField,
      filePath: filePath,
      method: 'PUT',
    );
    return fromJson(res['data'] ?? res);
  }

  Future<void> delete(int id) async {
    await ApiService.delete('$endpoint/$id');
  }

  Future<void> restore(int id) async {
    await ApiService.post('$endpoint/$id/restore');
  }
}