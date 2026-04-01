import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/product_model.dart';
import 'auth_provider.dart';

// Products State
class ProductState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;

  ProductState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  ProductState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    String? error,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Product Notifier
class ProductNotifier extends StateNotifier<ProductState> {
  final ApiClient _apiClient;

  ProductNotifier(this._apiClient) : super(ProductState());

  // Fetch all products
  Future<void> fetchProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.get('/products');
      print('products $response');
      final data = response.data['products'] as List;
      final products = data.map((e) => ProductModel.fromJson(e)).toList();
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Create product
  Future<bool> createProduct({
    required String name,
    String? tamilName,
    required double price,
    String? category,
  }) async {
    try {
      await _apiClient.post(
        '/products',
        data: {
          'name': name,
          'tamil_name': tamilName,
          'price': price,
          'category': category,
        },
      );
      await fetchProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Update product
  Future<bool> updateProduct({
    required int id,
    required String name,
    required String tamilName,
    required double price,
    String? category,
  }) async {
    try {
      await _apiClient.put(
        '/products/$id',
        data: {
          'name': name,
          'tamil_name': tamilName,
          'price': price,
          'category': category,
        },
      );
      await fetchProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
  // Delete product
  Future<bool> deleteProduct(int id) async {
    try {
      await _apiClient.delete('/products/$id');
      await fetchProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// Provider
final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier(ref.read(apiClientProvider));
});