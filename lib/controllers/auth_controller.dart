import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/notification_listener_service.dart';
import 'package:cwc/services/fcm_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';

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
  bool get isEmailVerified => _authService.isEmailVerified;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _authSubscription =
          SupabaseService.client.auth.onAuthStateChange.listen((data) async {
        final user = data.session?.user;
        if (user != null && user.id.isNotEmpty) {
          // Only load profile if email is verified; otherwise keep null so the
          // splash / router pushes to verification screen.
          final verified = user.emailConfirmedAt != null;
          _currentUser = verified ? await _authService.getUserById(user.id) : null;
        } else {
          _currentUser = null;
        }
        _syncNotificationListener();
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
    NotificationListenerService.instance.stop();
    super.dispose();
  }

  void _syncNotificationListener() {
    final userId = _currentUser?.id;
    if (userId != null && isEmailVerified) {
      NotificationListenerService.instance.start(userId);
      if (!kIsWeb) {
        FcmService.instance.syncTokenForUser(userId);
      }
    } else {
      NotificationListenerService.instance.stop();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String role = AppConstants.roleUser,
    String phone = '',
    String? city,
    String? businessName,
    String? businessAddress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        phone: phone,
        city: city,
        businessName: businessName,
        businessAddress: businessAddress,
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

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email: email, password: password);
      _syncNotificationListener();
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

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userId = _currentUser?.id;
      if (userId != null && !kIsWeb) {
        await FcmService.instance.clearTokenForUser(userId);
      }
      await _authService.signOut();
      _currentUser = null;
      NotificationListenerService.instance.stop();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserModel userModel) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.updateUserProfile(userModel);
      _currentUser = userModel;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final ok = await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return ok;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.sendPasswordReset(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendConfirmationEmail(String email) async {
    try {
      await _authService.resendConfirmationEmail(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> refreshVerificationState() async {
    final verified = await _authService.refreshAndCheckVerified();
    if (verified) {
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid != null) {
        _currentUser = await _authService.getUserById(uid);
        _syncNotificationListener();
        notifyListeners();
      }
    }
    return verified;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
