import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/cash_payment_model.dart';
import 'auth_provider.dart';

class CashPaymentState {
  final List<CashPaymentModel> payments;
  final double totalPaid;
  final bool isLoading;
  final String? error;

  CashPaymentState({
    this.payments = const [],
    this.totalPaid = 0,
    this.isLoading = false,
    this.error,
  });

  CashPaymentState copyWith({
    List<CashPaymentModel>? payments,
    double? totalPaid,
    bool? isLoading,
    String? error,
  }) {
    return CashPaymentState(
      payments: payments ?? this.payments,
      totalPaid: totalPaid ?? this.totalPaid,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CashPaymentNotifier extends StateNotifier<CashPaymentState> {
  final ApiClient _apiClient;

  CashPaymentNotifier(this._apiClient) : super(CashPaymentState());

  Future<void> fetchPayments({
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

      final response = await _apiClient.get('/cash-payments', queryParameters: params);
      final data = response.data['payments'] as List;
      final payments = data.map((e) => CashPaymentModel.fromJson(e)).toList();
      state = state.copyWith(
        payments: payments,
        totalPaid: payments.fold(0, (sum, p) => sum! + p.amount),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addPayment({
    required int retailerId,
    required String date,
    required double amount,
    String? note,
  }) async {
    try {
      await _apiClient.post('/cash-payments', data: {
        'retailer_id': retailerId,
        'date': date,
        'amount': amount,
        'note': note,
      });
      await fetchPayments(retailerId: retailerId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deletePayment(int id) async {
    try {
      await _apiClient.delete('/cash-payments/$id');
      state = state.copyWith(
        payments: state.payments.where((p) => p.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> getTotal({
    required int retailerId,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await _apiClient.get('/cash-payments/total', queryParameters: {
        'retailer_id': retailerId,
        'from_date': fromDate,
        'to_date': toDate,
      });
      return {
        'total': double.tryParse(response.data['total'].toString()) ?? 0.0,
        'payments': (response.data['payments'] as List)
            .map((e) => CashPaymentModel.fromJson(e))
            .toList(),
      };
    } catch (e) {
      return {'total': 0.0, 'payments': []};
    }
  }
}

final cashPaymentProvider =
    StateNotifierProvider<CashPaymentNotifier, CashPaymentState>((ref) {
  return CashPaymentNotifier(ref.read(apiClientProvider));
});