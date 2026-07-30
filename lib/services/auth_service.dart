import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../config/network_url.dart';
import '../models/app_user.dart';
import 'api_service.dart';

class AuthService {
  static Future<AppUser> login(String phoneNumber, String password) async {
    final res = await ApiService.post(NetworkUrl.login, body: {
      'phone_number': phoneNumber,
      'password': password,
    });
    await ApiService.setToken(res['token']);
    final user = AppUser.fromJson(res['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.userKey, jsonEncode(res['user']));
    return user;
  }

  static Future<void> logout() async {
    try {
      await ApiService.post(NetworkUrl.logout);
    } catch (_) {
      // ignore network errors on logout, clear local state regardless
    }
    await ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.userKey);
  }

  static Future<AppUser?> restoreSession() async {
    await ApiService.loadToken();
    if (ApiService.token == null) return null;
    try {
      final res = await ApiService.get(NetworkUrl.me);
      return AppUser.fromJson(res);
    } catch (_) {
      await ApiService.setToken(null);
      return null;
    }
  }

  /// Sends a forgot-password request to the admin using the user's phone
  /// number. Backend enforces a max of one request per phone number per
  /// day; on the 429 case ApiException.message already contains a friendly
  /// explanation to show the user as-is.
  static Future<String> forgotPassword(String phoneNumber) async {
    final res = await ApiService.post(NetworkUrl.forgotPassword, body: {
      'phone_number': phoneNumber,
    });
    return res['message'] as String? ?? 'Request sent.';
  }

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    await ApiService.put(NetworkUrl.profilePassword, body: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPassword,
    });
  }

  static Future<AppUser> updateProfile(Map<String, dynamic> data, {String? imagePath}) async {
    final dynamic res;
    if (imagePath == null) {
      res = await ApiService.put(NetworkUrl.profile, body: data);
    } else {
      res = await ApiService.multipart(
        NetworkUrl.profile,
        fields: data.map((k, v) => MapEntry(k, '$v')),
        fileField: 'profile_image',
        filePath: imagePath,
        method: 'PUT',
      );
    }
    return AppUser.fromJson(res);
  }
}