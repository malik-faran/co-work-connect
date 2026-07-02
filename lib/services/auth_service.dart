import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/error_handler.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentAuthUser => _client.auth.currentUser;

  /// Email is verified when Supabase has set `email_confirmed_at` / `confirmed_at`.
  bool get isEmailVerified {
    final u = _client.auth.currentUser;
    return u?.emailConfirmedAt != null || u?.confirmedAt != null;
  }

  Future<UserModel?> signUp({
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
    try {
      final trimmedEmail = email.trim();

      final response = await _client.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: {
          'role': role,
          'name': name,
          if (phone.isNotEmpty) 'phone': phone,
          if (city != null) 'city': city,
          if (businessName != null) 'business_name': businessName,
          if (businessAddress != null) 'business_address': businessAddress,
        },
      );

      final user = response.user;
      if (user == null || user.id.isEmpty) {
        throw Exception('Unable to create account. Please try again.');
      }

      final userModel = UserModel(
        id: user.id,
        email: trimmedEmail,
        name: name,
        phone: phone,
        role: role,
        city: city,
        businessName: businessName,
        businessAddress: businessAddress,
        cnicImageUrl: cnicImageUrl,
        ownerApproved: role == AppConstants.roleOwner ? null : true,
        createdAt: DateTime.now(),
      );

      try {
        final existingUser = await _client
            .from(AppConstants.collectionUsers)
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (existingUser != null) {
          return await getUserById(user.id);
        }

        final userData = userModel.toUserMap();
        userData.removeWhere((key, value) => value == null);
        await _client.from(AppConstants.collectionUsers).insert(userData);
      } catch (dbError) {
        final errorMsg = dbError.toString();
        if (errorMsg.contains('duplicate') || errorMsg.contains('already exists')) {
          final existing = await getUserById(user.id);
          if (existing != null) return existing;
          throw Exception('Account already exists. Please try logging in.');
        }
        throw Exception(formatDatabaseError(errorMsg));
      }

      return userModel;
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      throw Exception('Error signing up: ${e.toString()}');
    }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final trimmedEmail = email.trim();

      await _client.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception(
          'Connection timed out. Check your internet and try again.',
        ),
      );

      // Session fields (e.g. email_confirmed_at) are reliable on currentUser.
      try {
        await _client.auth.refreshSession().timeout(const Duration(seconds: 10));
      } catch (_) {}

      final user = _client.auth.currentUser;
      if (user == null) return null;

      if (!_isEmailConfirmed(user)) {
        throw Exception(
          'Please verify your email before logging in. Check your inbox for the confirmation link.',
        );
      }

      return await ensureUserProfile(user);
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error signing in: ${cleanErrorMessage(e.toString())}');
    }
  }

  bool _isEmailConfirmed(User user) =>
      user.emailConfirmedAt != null || user.confirmedAt != null;

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
  }

  Future<void> updateOwnerCnic({
    required String userId,
    required String cnicImageUrl,
  }) async {
    await _client.from(AppConstants.collectionUsers).update({
      'cnic_image_url': cnicImageUrl,
      'owner_approved': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _client
          .from(AppConstants.collectionUsers)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromUserMap(Map<String, dynamic>.from(response));
    } catch (e) {
      throw Exception('Error getting user: $e');
    }
  }

  /// Create or fetch public.users row after auth sign-in (handles legacy accounts).
  Future<UserModel?> ensureUserProfile(User user) async {
    UserModel buildFromAuth() {
      final meta = user.userMetadata ?? {};
      final role = (meta['role'] as String?)?.trim();
      final resolvedRole = (role == AppConstants.roleOwner ||
              role == AppConstants.roleModerator ||
              role == AppConstants.roleUser)
          ? role!
          : AppConstants.roleUser;

      return UserModel(
        id: user.id,
        email: user.email ?? '',
        name: (meta['name'] as String?)?.trim().isNotEmpty == true
            ? (meta['name'] as String).trim()
            : (user.email?.split('@').first ?? 'User'),
        phone: (meta['phone'] as String?) ?? '',
        role: resolvedRole,
        city: meta['city'] as String?,
        businessName: meta['business_name'] as String?,
        businessAddress: meta['business_address'] as String?,
        ownerApproved: resolvedRole == AppConstants.roleOwner ? null : true,
        createdAt: DateTime.now(),
      );
    }

    try {
      final existing = await getUserById(user.id)
          .timeout(const Duration(seconds: 15));
      if (existing != null) return existing;
    } catch (_) {}

    final userModel = buildFromAuth();
    final userData = userModel.toUserMap()..removeWhere((key, value) => value == null);

    try {
      await _client
          .from(AppConstants.collectionUsers)
          .upsert(userData)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Row may already exist from trigger; fall back to auth metadata.
    }

    try {
      return await getUserById(user.id).timeout(const Duration(seconds: 10));
    } catch (_) {
      return userModel;
    }
  }

  Future<void> saveFcmToken(String userId, String token) async {
    try {
      await _client
          .from(AppConstants.collectionUsers)
          .update({
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Error saving FCM token: $e');
    }
  }

  Future<void> clearFcmToken(String userId) async {
    try {
      await _client
          .from(AppConstants.collectionUsers)
          .update({
            'fcm_token': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (_) {}
  }

  Future<void> updateUserProfile(UserModel userModel) async {
    try {
      await _client
          .from(AppConstants.collectionUsers)
          .update(userModel.copyUser(updatedAt: DateTime.now()).toUserMap())
          .eq('id', userModel.id);
    } catch (e) {
      throw Exception('Error updating user profile: $e');
    }
  }

  Future<UserModel> updateResume({
    required String userId,
    required String resumeUrl,
    required String resumeFileName,
  }) async {
    await _client.from(AppConstants.collectionUsers).update({
      'resume_url': resumeUrl,
      'resume_file_name': resumeFileName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
    final user = await getUserById(userId);
    if (user == null) throw Exception('User not found after resume update');
    return user;
  }

  Future<UserModel> clearResume(String userId) async {
    await _client.from(AppConstants.collectionUsers).update({
      'resume_url': null,
      'resume_file_name': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
    final user = await getUserById(userId);
    if (user == null) throw Exception('User not found after resume clear');
    return user;
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      final email = currentUser.email;
      if (email == null) throw Exception('User email not found');

      await _client.auth.signInWithPassword(email: email, password: oldPassword);
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      throw Exception('Error changing password: ${e.toString()}');
    }
  }

  static String get passwordResetRedirectUrl {
    if (kIsWeb) {
      return '${Uri.base.origin}/reset-password';
    }
    return AppConstants.passwordResetRedirectUrl;
  }

  /// Send a password reset email via Supabase.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: passwordResetRedirectUrl,
      );
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      throw Exception('Failed to send reset email: ${e.toString()}');
    }
  }

  /// Set a new password after opening the reset link from email.
  Future<void> completePasswordReset(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

  /// Resend the confirmation email for a signup.
  Future<void> resendConfirmationEmail(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      throw Exception('Failed to resend email: ${e.toString()}');
    }
  }

  /// Re-check email verification state (refreshes current session).
  Future<bool> refreshAndCheckVerified() async {
    try {
      await _client.auth.refreshSession();
    } catch (_) {}
    return isEmailVerified;
  }
}
