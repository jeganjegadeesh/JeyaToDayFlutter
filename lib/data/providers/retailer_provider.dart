import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

// Retailer State
class RetailerState {
  final List<UserModel> retailers;
  final bool isLoading;
  final String? error;

  RetailerState({
    this.retailers = const [],
    this.isLoading = false,
    this.error,
  });

  RetailerState copyWith({
    List<UserModel>? retailers,
    bool? isLoading,
    String? error,
  }) {
    return RetailerState(
      retailers: retailers ?? this.retailers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Retailer Notifier
class RetailerNotifier extends StateNotifier<RetailerState> {
  final ApiClient _apiClient;

  RetailerNotifier(this._apiClient) : super(RetailerState());

  // Fetch all retailers
  Future<void> fetchRetailers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.get('/retailers');
      final data = response.data['retailers'] as List;
      print(response);
      final retailers = data
          .map((e) => UserModel(
                id: e['id'],
                name: e['name'] ?? '',
                mobile: e['mobile'] ?? '',
                role: e['role'] ?? 'retailer',
                commission:
                    double.tryParse(e['commission'].toString()) ?? 0.0,
              ))
          .toList();
      state = RetailerState(retailers: retailers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Create retailer
  Future<bool> createRetailer({
    required String name,
    required String mobile,
    required String password,
    double commission = 0,
  }) async {
    try {
      await _apiClient.post(
        '/retailers',
        data: {
          'name': name,
          'mobile': mobile,
          'password': password,
          'commission': commission,
        },
      );
      await fetchRetailers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Update retailer
  Future<bool> updateRetailer({
    required int id,
    required String name,
    required String mobile,
    double commission = 0,
    String? password,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'mobile': mobile,
        'commission': commission,
      };
      if (password != null && password.isNotEmpty) {
        data['password'] = password;
      }
      await _apiClient.put('/retailers/$id', data: data);
      await fetchRetailers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Delete retailer
  Future<bool> deleteRetailer(int id) async {
    try {
      await _apiClient.delete('/retailers/$id');
      await fetchRetailers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// Provider
final retailerProvider =
    StateNotifierProvider<RetailerNotifier, RetailerState>((ref) {
  return RetailerNotifier(ref.read(apiClientProvider));
});