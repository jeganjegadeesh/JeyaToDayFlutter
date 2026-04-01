import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

class UserState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  UserState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final ApiClient _apiClient;

  UserNotifier(this._apiClient) : super(UserState());

  Future<void> fetchUsers({String? role}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (role != null) params['role'] = role;
      final response = await _apiClient.get('/users', queryParameters: params);
      final data = response.data['users'] as List;
      final users = data.map((e) => UserModel.fromJson(e)).toList();
      state = UserState(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createUser({
    required String name,
    required String mobile,
    required String password,
    required String role,
    double commission = 0,
  }) async {
    try {
      await _apiClient.post('/users', data: {
        'name': name,
        'mobile': mobile,
        'password': password,
        'role': role,
        'commission': commission,
      });
      await fetchUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateUser({
    required int id,
    required String name,
    required String mobile,
    required String role,
    double commission = 0,
    String? password,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'mobile': mobile,
        'role': role,
        'commission': commission,
      };
      if (password != null && password.isNotEmpty) {
        data['password'] = password;
      }
      await _apiClient.put('/users/$id', data: data);
      await fetchUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await _apiClient.delete('/users/$id');
      await fetchUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.read(apiClientProvider));
});