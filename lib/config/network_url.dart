/// Centralized list of every backend API endpoint (relative to [ApiConfig.baseUrl]).
///
/// Keep ALL endpoint paths here instead of hardcoding strings inside service
/// files. Usage inside a service:
///
/// ```dart
/// final res = await ApiService.post(NetworkUrl.login, body: {...});
/// ```
///
/// For routes that need a dynamic id/segment, use the matching helper method,
/// e.g. `NetworkUrl.billById(5)` -> `/bills/5`.
class NetworkUrl {
  NetworkUrl._();

  // ---------------------------------------------------------------------
  // Auth / Profile
  // ---------------------------------------------------------------------
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';
  static const String profile = '/profile';
  static const String profilePassword = '/profile/password';

  // ---------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------
  static const String dashboard = '/dashboard';
  static const String dashboardRetailer = '/dashboard/retailer';

  // ---------------------------------------------------------------------
  // CRUD resources (base paths — CrudService appends /{id}, /{id}/restore)
  // ---------------------------------------------------------------------
  static const String products = '/products';
  static const String retailers = '/retailers';
  static const String users = '/users';
  static String userResetPassword(int id) => '/users/$id/reset-password';
  static const String expenses = '/expenses';
  static const String rawMaterials = '/raw-materials';
  static const String retailerLoans = '/retailer-loans';

  // ---------------------------------------------------------------------
  // Stock (give / return) — base paths used by StockService
  // ---------------------------------------------------------------------
  static const String giveStock = '/give-stock';
  static const String returnStock = '/return-stock';

  // ---------------------------------------------------------------------
  // Cash payments
  // ---------------------------------------------------------------------
  static const String cashPayments = '/cash-payments';
  static String cashPaymentById(int id) => '/cash-payments/$id';

  // ---------------------------------------------------------------------
  // Bills
  // ---------------------------------------------------------------------
  static const String billsPreview = '/bills/preview';
  static const String billsGenerate = '/bills/generate';
  static const String bills = '/bills';
  static String billById(int id) => '/bills/$id';
  static String billSettle(int id) => '/bills/$id/settle';

  // ---------------------------------------------------------------------
  // Company
  // ---------------------------------------------------------------------
  static const String company = '/company';
  static String companyById(int id) => '/company/$id';

  // ---------------------------------------------------------------------
  // Reports (admin)
  // ---------------------------------------------------------------------
  static const String reportsSales = '/reports/sales';
  static const String reportsStock = '/reports/stock';
  static const String reportsCash = '/reports/cash';

  // ---------------------------------------------------------------------
  // Retailer self-service portal ("/my/...")
  // ---------------------------------------------------------------------
  static const String myReportsSales = '/my/reports/sales';
  static const String myReportsStock = '/my/reports/stock';
  static const String myReceivedStock = '/my/received-stock';
  static const String myReturnedStock = '/my/returned-stock';
  static const String myPayments = '/my/payments';
  static const String myBills = '/my/bills';
  static String myBillById(int id) => '/my/bills/$id';
}