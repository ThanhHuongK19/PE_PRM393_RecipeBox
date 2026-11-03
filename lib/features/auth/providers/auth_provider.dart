import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../repositories/auth_repository.dart';

enum AuthStatus { checking, signedOut, signedIn }

/// Holds authentication state and coordinates auth operations for the UI.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository repository}) : _authRepository = repository {
    _authSubscription = _authRepository.authStateChanges().listen(
      _handleAuthStateChange,
      onError: _handleAuthStateError,
    );
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<User?> _authSubscription;

  AuthStatus _status = AuthStatus.checking;
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get uid => _currentUser?.uid;
  String? get email => _currentUser?.email;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.signedIn;

  Future<bool> register({required String email, required String password}) =>
      _runAuthOperation(
        () => _authRepository.register(email: email, password: password),
      );

  Future<bool> login({required String email, required String password}) =>
      _runAuthOperation(
        () => _authRepository.login(email: email, password: password),
      );

  Future<bool> logout() => _runAuthOperation(_authRepository.logout);

  Future<bool> _runAuthOperation(Future<void> Function() operation) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await operation();
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _messageForAuthError(error);
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleAuthStateChange(User? user) {
    _currentUser = user;
    _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    _errorMessage = null;
    notifyListeners();
  }

  void _handleAuthStateError(Object error) {
    _status = AuthStatus.signedOut;
    _currentUser = null;
    _errorMessage = error is FirebaseAuthException
        ? _messageForAuthError(error)
        : 'Unable to check your sign-in status. Please try again.';
    notifyListeners();
  }

  String _messageForAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account already exists for this email.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Incorrect email or password.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
