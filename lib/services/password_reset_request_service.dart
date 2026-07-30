import '../config/network_url.dart';
import '../models/password_reset_request_item.dart';
import 'api_service.dart';

class PasswordResetRequestService {
  static Future<List<PasswordResetRequestItem>> list({String? status}) async {
    final res = await ApiService.get(
      NetworkUrl.passwordResetRequests,
      query: status != null ? {'status': status} : null,
    );
    final List data = res['data'] ?? res;
    return data.map((e) => PasswordResetRequestItem.fromJson(e)).toList();
  }

  /// Resets the requester's password back to the system default and marks
  /// the request resolved. Returns the server's confirmation message.
  static Future<String> resolve(int id) async {
    final res = await ApiService.post(NetworkUrl.passwordResetRequestResolve(id));
    return res['message'] as String? ?? 'Password reset.';
  }
}
