import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../models/user_credentials.dart';

/// Authentication Service with proper credential validation,
/// role-based access control, and session management
class AuthService extends ChangeNotifier {
  UserProfile? _currentUser;
  bool _isAuthenticated = false;
  Timer? _sessionTimer;

  /// Session timeout duration (30 minutes of inactivity)
  static const Duration sessionTimeout = Duration(minutes: 30);

  // --- Getters ---
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated && _currentUser != null;
  UserRole? get currentRole => _currentUser?.role;

  /// Safe non-null access — throws if not authenticated
  UserProfile get requireUser {
    if (_currentUser == null) throw StateError('User is not authenticated');
    return _currentUser!;
  }

  // --- Permission Checking ---

  /// Check if the current user has a specific permission
  bool hasPermission(Permission perm) {
    return _currentUser?.hasPermission(perm) ?? false;
  }

  /// Check if the current user can access data for a given station
  bool canAccessStation(String stationId) {
    return _currentUser?.canAccessStation(stationId) ?? false;
  }

  /// Check if the current user can modify data for a given station
  bool canEditStation(String stationId) {
    return _currentUser?.canEditStation(stationId) ?? false;
  }

  // --- Authentication ---

  /// Authenticate with email, password, and expected role type.
  /// Returns an error message string on failure, null on success.
  String? login({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) {
    // Input validation
    if (email.trim().isEmpty) return 'Email is required';
    if (password.isEmpty) return 'Access key is required';

    // Authenticate against credential store
    final profile = UserCredentialStore.authenticate(
      email: email,
      password: password,
      expectedRole: expectedRole,
    );

    if (profile == null) {
      return 'Invalid credentials or unauthorized role access. Verify your callsign and access key.';
    }

    _currentUser = profile;
    _isAuthenticated = true;
    _resetSessionTimer();
    notifyListeners();
    return null; // Success
  }

  /// Start a session from an externally-resolved profile.
  /// Used by the family portal: the invite code is resolved against
  /// PolarDataService first, then the resulting scoped profile starts
  /// the session here so all timeout/permission machinery stays central.
  void startSession(UserProfile profile) {
    _currentUser = profile;
    _isAuthenticated = true;
    _resetSessionTimer();
    notifyListeners();
  }

  /// Log out the current user and clear session
  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    notifyListeners();
  }

  /// Reset the inactivity timer (called on user interactions)
  void touchSession() {
    if (_isAuthenticated) {
      _resetSessionTimer();
    }
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(sessionTimeout, () {
      logout();
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
