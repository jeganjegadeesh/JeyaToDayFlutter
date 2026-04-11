import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/bill_model.dart';
import 'auth_provider.dart';

class BillState {
  final List<BillModel> bills;
  final BillModel? currentBill;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  BillState({
    this.bills = const [],
    this.currentBill,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  BillState copyWith({
    List<BillModel>? bills,
    BillModel? currentBill,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return BillState(
      bills: bills ?? this.bills,
      currentBill: currentBill ?? this.currentBill,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

class BillNotifier extends StateNotifier<BillState> {
  final ApiClient _apiClient;

  BillNotifier(this._apiClient) : super(BillState());

  final AuthState userState = AuthState();


  Future<bool> generateBill({
    required int retailerId,
    required String fromDate,
    required String toDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.post(
        '/bill/generate',
        data: {
          'retailer_id': retailerId,
          'from_date': fromDate,
          'to_date': toDate,
        },
      );
      final bill = BillModel.fromJson(response.data['bill']);
      state = state.copyWith(
        isLoading: false,
        currentBill: bill,
        successMessage: 'Bill generated successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> fetchHistory({
    int? retailerId,
    String? fromDate,
    String? toDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (retailerId != null) params['retailer_id'] = retailerId;
      if (fromDate != null) params['from_date'] = fromDate;
      if (toDate != null) params['to_date'] = toDate;
      var url = userState.user?.role == 'retailer' ? '/retailer/bills' : '/bills';

      final response = await _apiClient.get(url, queryParameters: params);
      final data = response.data['bills'] as List;
      final bills = data.map((e) => BillModel.fromJson(e)).toList();
      state = state.copyWith(bills: bills, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> deleteBill(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiClient.delete('/bill/$id');
      state = state.copyWith(
        isLoading: false,
        bills: state.bills.where((b) => b.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearCurrentBill() {
    state = state.copyWith(currentBill: null);
  }
}

final billProvider = StateNotifierProvider<BillNotifier, BillState>((ref) {
  return BillNotifier(ref.read(apiClientProvider));
});