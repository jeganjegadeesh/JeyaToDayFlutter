import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Holds the current signed-in user and session-loading state.
///
/// Exposed to the widget tree via the [authProvider] below. Kept as a
/// [ChangeNotifier] (registered with Riverpod's [ChangeNotifierProvider]) so
/// the public API (`user`, `loading`, `isLoggedIn`, `login`, `logout`,
/// `updateUser`) stays unchanged for every screen that already reads it.
class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _loading = true;

  AppUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;

  Future<void> restoreSession() async {
    _loading = true;
    notifyListeners();
    _user = await AuthService.restoreSession();
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String phoneNumber, String password) async {
    _user = await AuthService.login(phoneNumber, password);
    notifyListeners();
  }

  /// Re-fetches the current user from the server and replaces the cached
  /// one. Used after flows that change server-side state the app needs to
  /// react to immediately but that don't go through [updateUser] — e.g.
  /// completing the Company Setup onboarding screen, which needs the
  /// freshly-updated `company.is_setup_complete` flag to unlock the
  /// regular dashboard.
  Future<void> refreshUser() async {
    final refreshed = await AuthService.restoreSession();
    if (refreshed != null) {
      _user = refreshed;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }

  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }
}

/// Riverpod provider for [AuthProvider].
///
/// Read with `ref.watch(authProvider)` / `ref.read(authProvider)` from any
/// [ConsumerWidget] or [ConsumerStatefulWidget].
final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider()..restoreSession();
});