import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

/// Authentication data access boundary used by application state.
class AuthRepository {
  AuthRepository(this._authService);

  final AuthService _authService;

  Stream<User?> authStateChanges() => _authService.authStateChanges();

  Future<void> register({required String email, required String password}) =>
      _authService.register(email: email, password: password);

  Future<void> login({required String email, required String password}) =>
      _authService.login(email: email, password: password);

  Future<void> logout() => _authService.logout();
}
