import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

// Auth State
class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool checkedLogin;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.checkedLogin = false,
  });

  bool get isLoggedIn => token != null && user != null;

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? checkedLogin,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      checkedLogin: checkedLogin ?? this.checkedLogin,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState()) {
    _loadFromStorage();
  }

  // Load saved token and user from storage
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final userName = prefs.getString('user_name');
    final userId = prefs.getInt('user_id');
    final userMobile = prefs.getString('user_mobile');
    final userRole = prefs.getString(AppConstants.roleKey);
    final userCommission = prefs.getDouble('user_commission');
    if (token != null && userId != null) {
          print("username : $userName");
    print("usermobile : $userMobile");
    print("userrole : $userRole");
    print("usercommission : $userCommission");
    print("userid : $userId");
    print("token : $token");

      state = AuthState(
        token: token,
        checkedLogin: true,
        user: UserModel(
          id: userId,
          name: userName ?? '',
          mobile: userMobile ?? '',
          role: userRole ?? '',
          commission: userCommission ?? 0.0,
          
        ),
      );
    } else {
      state = AuthState(checkedLogin: true);
    }
  }

  // Login
  Future<bool> login(String mobile, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.post(
        '/login',
        data: {'mobile': mobile, 'password': password},
      );

      final data = response.data;
      final user = UserModel.fromJson(data['user']);
      final token = data['token'];

      // Save to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);
      await prefs.setInt('user_id', user.id);
      await prefs.setString('user_name', user.name);
      await prefs.setString('user_mobile', user.mobile);
      await prefs.setString(AppConstants.roleKey, user.role);
      await prefs.setDouble('user_commission', user.commission);

      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      print(' ERROR ::: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _apiClient.post('/logout');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = AuthState();
  }

  Future<void> updateLocalUser(Map<String, dynamic> userData) async {
    final user = UserModel.fromJson(userData);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_mobile', user.mobile);
    state = state.copyWith(user: user);
  }
}

// Providers
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.init();
  return client;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});