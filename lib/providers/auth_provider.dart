// lib/providers/auth_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// AuthProvider — holds the currently logged-in user and drives role-based
// routing.  Consumed by every screen that needs to know who is logged in.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // 10-minute inactivity timer
  Timer? _inactivityTimer;
  VoidCallback? _onInactivityLogout;

  // ── Getters ────────────────────────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  bool get isAdmin => _currentUser?.role == AppConstants.roleAdmin;
  bool get isBarangayStaff => _currentUser?.role == AppConstants.roleBarangay;
  bool get isHealthStaff => _currentUser?.role == AppConstants.roleHealth;

  // ── Set the logged-in user (called by AuthService after login) ─────────────
  void setUser(UserModel user) {
    _currentUser = user;
    _errorMessage = null;
    notifyListeners();
    _resetInactivityTimer();
  }

  // ── Clear user on logout ───────────────────────────────────────────────────
  void clearUser() {
    _currentUser = null;
    _cancelInactivityTimer();
    notifyListeners();
  }

  // ── Loading state helpers ──────────────────────────────────────────────────
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Inactivity timer ───────────────────────────────────────────────────────
  // Call this on every user interaction (tap, scroll, key press).
  void registerOnInactivityLogout(VoidCallback callback) {
    _onInactivityLogout = callback;
  }

  void resetActivityTimer() {
    if (_currentUser != null) {
      _resetInactivityTimer();
    }
  }

  void _resetInactivityTimer() {
    _cancelInactivityTimer();
    _inactivityTimer = Timer(
      const Duration(minutes: AppConstants.inactivityMinutes),
      () {
        if (_onInactivityLogout != null) {
          _onInactivityLogout!();
        }
      },
    );
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  @override
  void dispose() {
    _cancelInactivityTimer();
    super.dispose();
  }
}
