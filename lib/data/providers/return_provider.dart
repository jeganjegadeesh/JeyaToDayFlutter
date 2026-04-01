import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/stock_model.dart';
import 'auth_provider.dart';

// Return State
class ReturnState {
  final List<StockEntryModel> returns;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  ReturnState({
    this.returns = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  ReturnState copyWith({
    List<StockEntryModel>? returns,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return ReturnState(
      returns: returns ?? this.returns,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

// Return Item
class ReturnItem {
  int productId;
  String productName;
  int quantity;
  int maxQuantity;

  ReturnItem({
    required this.productId,
    required this.productName,
    this.quantity = 0,
    this.maxQuantity = 0,
  });
}

// Return Notifier
class ReturnNotifier extends StateNotifier<ReturnState> {
  final ApiClient _apiClient;

  ReturnNotifier(this._apiClient) : super(ReturnState());

  // Fetch return history
  Future<void> fetchHistory({
    int? retailerId,
    String? date,
    String? fromDate,
    String? toDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (retailerId != null) params['retailer_id'] = retailerId;
      if (date != null) params['date'] = date;
      if (fromDate != null) params['from_date'] = fromDate;
      if (toDate != null) params['to_date'] = toDate;

      final response = await _apiClient.get('/returns', queryParameters: params);
      final data = response.data['returns'] as List;
      final returns = data.map((e) => StockEntryModel.fromJson(e)).toList();
      state = state.copyWith(returns: returns, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Record return
  Future<bool> recordReturn({
    required int retailerId,
    required String date,
    required List<ReturnItem> items,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final itemsData = items
          .where((item) => item.quantity > 0)
          .map((item) => {
                'product_id': item.productId,
                'quantity': item.quantity,
              })
          .toList();

      if (itemsData.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please add at least one product with quantity.',
        );
        return false;
      }

      await _apiClient.post(
        '/returns',
        data: {
          'retailer_id': retailerId,
          'date': date,
          'items': itemsData,
        },
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Returns recorded successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

// Provider
final returnProvider =
    StateNotifierProvider<ReturnNotifier, ReturnState>((ref) {
  return ReturnNotifier(ref.read(apiClientProvider));
});