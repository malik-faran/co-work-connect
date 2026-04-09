import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/supabase_service.dart';

class AuthController with ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription? _authSubscription;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((data) async {
        final user = data.session?.user;
        if (user != null && user.id.isNotEmpty) {
          _currentUser = await _authService.getUserById(user.id);
        } else {
          _currentUser = null;
        }
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? city,
    String? businessName,
    String? businessAddress,
    String? cnicImageUrl, // CNIC image URL
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
        city: city,
        businessName: businessName,
        businessAddress: businessAddress,
        cnicImageUrl: cnicImageUrl,
      );

      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<void> updateProfile(UserModel userModel) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateUserProfile(userModel);
      _currentUser = userModel;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

