import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/notification_listener_service.dart';
import 'package:cwc/services/booking_lifecycle_service.dart';
import 'package:cwc/services/fcm_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthChangeEvent;
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/error_handler.dart';
import 'package:cwc/services/navigation_service.dart';

class AuthController with ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription? _authSubscription;
  bool _signInInProgress = false;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _passwordRecoveryPending = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get passwordRecoveryPending => _passwordRecoveryPending;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _authService.isEmailVerified;

  bool _isRecoveryUrl() {
    final pending = SupabaseService.pendingAuthUri;
    final pendingStr = pending?.toString() ?? '';
    final webUrl = kIsWeb ? Uri.base.toString() : '';

    if (pendingStr.contains('confirm-email') ||
        pendingStr.contains('type=signup') ||
        webUrl.contains('confirm-email') ||
        webUrl.contains('type=signup')) {
      return false;
    }

    return pendingStr.contains('type=recovery') ||
        pendingStr.contains('reset-password') ||
        webUrl.contains('type=recovery') ||
        webUrl.contains('reset-password');
  }

  bool _isVerificationUrl() {
    final pending = SupabaseService.pendingAuthUri;
    final pendingStr = pending?.toString() ?? '';
    final webUrl = kIsWeb ? Uri.base.toString() : '';
    return pendingStr.contains('type=signup') ||
        pendingStr.contains('confirm-email') ||
        pendingStr.contains('type=email_change') ||
        webUrl.contains('type=signup') ||
        webUrl.contains('confirm-email') ||
        webUrl.contains('type=email_change');
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isRecoveryUrl()) {
        _passwordRecoveryPending = true;
        _currentUser = null;
        notifyListeners();
        NavigationService.openResetPassword();
      } else {
        await _restoreSession();
      }

      _authSubscription?.cancel();
      _authSubscription =
          SupabaseService.client.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.passwordRecovery || _isRecoveryUrl()) {
          _passwordRecoveryPending = true;
          _currentUser = null;
          SupabaseService.pendingAuthUri = null;
          notifyListeners();
          NavigationService.openResetPassword();
          return;
        }

        if (_isVerificationUrl()) {
          SupabaseService.pendingAuthUri = null;
          _currentUser = null;
          try {
            await _authService.signOut();
          } catch (_) {}
          notifyListeners();
          NavigationService.openLoginWithSuccess('Email verified successfully! Please sign in.');
          return;
        }

        if (_passwordRecoveryPending) return;
        if (_signInInProgress) return;
        await _applyAuthState(data.session?.user);
      });

      await SupabaseService.processPendingAuthLinks();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreSession() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null || user.id.isEmpty) {
      _currentUser = null;
      return;
    }
    await _applyAuthState(user);
  }

  Future<void> _applyAuthState(User? user) async {
    if (user != null && user.id.isNotEmpty) {
      try {
        _currentUser = await _authService.ensureUserProfile(user);
      } catch (_) {
        _currentUser = await _authService.getUserById(user.id);
      }
    } else {
      _currentUser = null;
    }
    _syncNotificationListener();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    NotificationListenerService.instance.stop();
    BookingLifecycleService.instance.stopPolling();
    super.dispose();
  }

  void _syncNotificationListener() {
    final userId = _currentUser?.id;
    if (userId != null) {
      NotificationListenerService.instance.start(userId);
      BookingLifecycleService.instance.startPolling();
      if (!kIsWeb) {
        FcmService.instance.syncTokenForUser(userId);
      }
    } else {
      NotificationListenerService.instance.stop();
      BookingLifecycleService.instance.stopPolling();
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
    String? cnicImageUrl,
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
        cnicImageUrl: cnicImageUrl,
      );

      // Automatically sign in if session is not active yet
      if (SupabaseService.client.auth.currentSession == null) {
        try {
          await _authService.signIn(email: email, password: password);
          final uid = SupabaseService.client.auth.currentUser?.id;
          if (uid != null) {
            _currentUser = await _authService.getUserById(uid);
          }
        } catch (_) {}
      }

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

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _signInInProgress = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email: email, password: password)
          .timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception(
          'Connection timed out. Check your internet and try again.',
        ),
      );
      if (_currentUser == null) {
        _errorMessage = 'Login failed. Please check your email and password.';
      } else {
        // Defer side effects so login UI can navigate immediately.
        Future.microtask(_syncNotificationListener);
      }
      return _currentUser != null;
    } catch (e) {
      debugPrint('AuthController signIn error: $e');
      _errorMessage = cleanErrorMessage(e.toString());
      return false;
    } finally {
      _signInInProgress = false;
      _isLoading = false;
      notifyListeners();
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
      _currentUser = await _authService.getUserById(userModel.id) ?? userModel;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userId = _currentUser?.id;
      if (userId != null && !kIsWeb) {
        await FcmService.instance.clearTokenForUser(userId);
      }
      await _authService.deleteOwnAccount();
      _currentUser = null;
      NotificationListenerService.instance.stop();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> updateCollaborationProfile({
    required bool collaborationEnabled,
    required String collaborationHeadline,
    required String bio,
    required String availability,
    String? experience,
    required List<String> skills,
  }) async {
    final userId = _currentUser?.id;
    if (userId == null) return null;

    _isLoading = true;
    notifyListeners();
    try {
      final updated = await _authService.updateCollaborationProfile(
        userId: userId,
        collaborationEnabled: collaborationEnabled,
        collaborationHeadline: collaborationHeadline,
        bio: bio,
        availability: availability,
        experience: experience,
        skills: skills,
      );
      _currentUser = updated;
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeOwnerRegistration({
    required String cnicImageUrl,
  }) async {
    final userId = _currentUser?.id;
    if (userId == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.updateOwnerCnic(
        userId: userId,
        cnicImageUrl: cnicImageUrl,
      );
      _currentUser = await _authService.getUserById(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCurrentUser() async {
    final userId = _currentUser?.id ?? SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    _currentUser = await _authService.getUserById(userId);
    notifyListeners();
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

  Future<bool> completePasswordReset(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.completePasswordReset(newPassword);
      await _authService.signOut();
      _currentUser = null;
      _passwordRecoveryPending = false;
      NotificationListenerService.instance.stop();
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
