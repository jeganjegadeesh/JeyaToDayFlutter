import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  // Login
  Future<Map<String, dynamic>> login({
    required String mobile,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/login',
        data: {
          'mobile': mobile,
          'password': password,
        },
      );

      final data = response.data;
      final user = UserModel.fromJson(data['user']);
      final token = data['token'];

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);
      await prefs.setString(
          AppConstants.userKey, jsonEncode(user.toJson()));
      await prefs.setString(AppConstants.roleKey, user.role);

      return {
        'success': true,
        'user': user,
        'token': token,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _apiClient.post('/logout');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    await prefs.remove(AppConstants.roleKey);
  }

  // Get saved user
  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey) != null;
  }

  // Get token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  // Get role
  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.roleKey);
  }
}