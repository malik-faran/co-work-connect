import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
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
    // ignore: deprecated_member_use
    return u != null && (u.emailConfirmedAt != null || u.confirmedAt != null);
  }

  static String get emailRedirectUrl {
    if (kIsWeb) {
      return '${Uri.base.origin}/confirm-email';
    }
    return 'cwc://confirm-email';
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
        emailRedirectTo: emailRedirectUrl,
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

      // True duplicate: email already registered AND no new identity was created.
      // Do not use identities-empty alone — some successful signups still report
      // an empty list depending on Auth settings, which falsely showed "exists".
      final identities = user.identities;
      final looksLikeDuplicate =
          identities != null && identities.isEmpty && response.session == null;
      if (looksLikeDuplicate) {
        // Confirm whether this auth user actually just got created for us.
        // If a profile/auth row exists for this id, treat signup as success.
        try {
          final existing = await getUserById(user.id);
          if (existing != null) {
            return existing;
          }
        } catch (_) {}
        throw Exception(
          'An account with this email already exists. Please login instead.',
        );
      }

      // Never fail the button after auth account creation — profile sync is
      // best-effort (trigger / ensureUserProfile). Success must reach the UI.
      try {
        final profile = await ensureUserProfile(user);
        if (profile != null) {
          if (cnicImageUrl != null && profile.cnicImageUrl == null) {
            return profile.copyUser(cnicImageUrl: cnicImageUrl);
          }
          return profile;
        }
      } catch (_) {}

      return UserModel(
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
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      final msg = e.toString();
      // If we already wrapped a clear auth error, keep it.
      if (msg.contains('already exists') ||
          msg.contains('Unable to create account') ||
          msg.contains('Please login')) {
        throw Exception(cleanErrorMessage(msg));
      }
      throw Exception('Error signing up: ${cleanErrorMessage(msg)}');
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
      if (_client.auth.currentSession != null) {
        try {
          await _client.auth.refreshSession().timeout(const Duration(seconds: 10));
        } catch (_) {}
      }

      final user = _client.auth.currentUser;
      if (user == null) return null;

      return await ensureUserProfile(user);
    } on AuthException catch (e) {
      debugPrint('Supabase signIn AuthException: ${e.message} (statusCode: ${e.statusCode})');
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error signing in: ${cleanErrorMessage(e.toString())}');
    }
  }



  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
  }

  Future<void> deleteOwnAccount() async {
    try {
      await _client.rpc('delete_own_account');
      await signOut();
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
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
      if (response['deleted_at'] != null) {
        throw Exception('This account has been deleted.');
      }
      if (response['suspended_at'] != null) {
        final reason = (response['suspended_reason'] as String?)?.trim();
        throw Exception(
          reason != null && reason.isNotEmpty
              ? 'Your account is suspended: $reason'
              : 'Your account has been suspended. Contact support.',
        );
      }
      return UserModel.fromUserMap(Map<String, dynamic>.from(response));
    } catch (e) {
      if (e is Exception && e.toString().contains('deleted')) rethrow;
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

  Future<UserModel> updateCollaborationProfile({
    required String userId,
    required bool collaborationEnabled,
    required String collaborationHeadline,
    required String bio,
    required String availability,
    String? experience,
    required List<String> skills,
  }) async {
    try {
      await _client.from(AppConstants.collectionUsers).update({
        'collaboration_enabled': collaborationEnabled,
        'collaboration_headline': collaborationHeadline,
        'bio': bio,
        'availability': availability,
        'experience': experience,
        'skills': skills,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Error updating collaboration profile: $e');
    }

    final user = await getUserById(userId);
    if (user == null) {
      throw Exception('Could not reload profile after save');
    }
    return user;
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
        emailRedirectTo: emailRedirectUrl,
      );
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message));
    } catch (e) {
      throw Exception('Failed to resend email: ${e.toString()}');
    }
  }

  /// Re-check email verification state (refreshes current session).
  Future<bool> refreshAndCheckVerified() async {
    if (_client.auth.currentSession == null) return false;
    try {
      await _client.auth.refreshSession();
    } catch (_) {}
    return isEmailVerified;
  }
}
