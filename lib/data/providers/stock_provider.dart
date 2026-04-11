import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/stock_model.dart';
import 'auth_provider.dart';

// Stock State
class StockState {
  final List<StockEntryModel> entries;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  StockState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  StockState copyWith({
    List<StockEntryModel>? entries,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return StockState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

// Stock Item for giving stock
class StockItem {
  int productId;
  String productName;
  int quantity;

  StockItem({
    required this.productId,
    required this.productName,
    this.quantity = 0,
  });
}

// Stock Notifier
class StockNotifier extends StateNotifier<StockState> {
  final ApiClient _apiClient;

  StockNotifier(this._apiClient) : super(StockState());

  final AuthState userState = AuthState();

  // Fetch stock history
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

      var url = userState.user?.role == 'retailer' ? '/retailer/stock' : '/stock/history';

      final response = await _apiClient.get(url, queryParameters: params);
      print('History response:$response');

      final data = response.data['entries'] as List;
      final entries = data.map((e) => StockEntryModel.fromJson(e)).toList();
      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      print(e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Give stock to retailer
  Future<bool> giveStock({
    required int retailerId,
    required String date,
    required List<StockItem> items,
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
        '/stock/give',
        data: {
          'retailer_id': retailerId,
          'date': date,
          'items': itemsData,
        },
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Stock distributed successfully.',
      );
      return true;
    } catch (e) {
      print(e);
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

// Provider
final stockProvider =
    StateNotifierProvider<StockNotifier, StockState>((ref) {
  return StockNotifier(ref.read(apiClientProvider));
});
