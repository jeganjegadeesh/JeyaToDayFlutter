import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;
  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiService {
  static String? _token;

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(ApiConfig.tokenKey);
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(ApiConfig.tokenKey);
    } else {
      await prefs.setString(ApiConfig.tokenKey, token);
    }
  }

  static String? get token => _token;

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = query?.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: cleaned);
  }

  static dynamic _handle(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    print("RESPONSE $body");
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw ApiException(
      body?['message'] ?? 'Request failed (${res.statusCode})',
      statusCode: res.statusCode,
      errors: body?['errors'],
    );
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    print("URL :: ${_uri(path, query)}");
    print("HEADER :: $_headers");
    final res = await http.get(_uri(path, query), headers: _headers);
    return _handle(res);
  }

  static Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
      print("URL :: ${_uri(path)}");
    print("HEADER :: $_headers");
    final res = await http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}));
    return _handle(res);
  }

  static Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final res = await http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {}));
    return _handle(res);
  }

  static Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    final res = await http.delete(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  static Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
    String method = 'POST',
  }) async {

      print("URL :: ${_uri(path)}");
      print("BODY :: $fields");
      print("FILE :: $filePath");
    
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll({
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
      // no Content-Type here — http.MultipartRequest sets its own multipart boundary header
    });
    request.fields.addAll(fields);
    if (method == 'PUT') {
      request.fields['_method'] = 'PUT'; // Laravel method-spoofing for multipart PUT
    }
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }
}
