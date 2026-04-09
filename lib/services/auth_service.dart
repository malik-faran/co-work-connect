import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/error_handler.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  
  Future<UserModel?> signUp({
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
    try {
      final trimmedEmail = email.trim();

      final response = await _client.auth.signUp(
        email: trimmedEmail,
        password: password,
        emailRedirectTo: null,
        data: {
          'role': role,
          'name': name,
          'phone': phone,
          'city': city,
          'business_name': businessName,
          'business_address': businessAddress,
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
        ownerApproved: role == AppConstants.roleOwner ? null : null,
        cnicImageUrl: cnicImageUrl,
        adminApproved: false, // Requires admin approval
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
        userData.removeWhere((key, value) => value == null && key != 'owner_approved' && key != 'admin_approved');
        if (role == AppConstants.roleOwner) {
          userData['owner_approved'] = null;
        }
        // Ensure admin_approved is set to false for new registrations
        userData['admin_approved'] = false;
        
        await _client.from(AppConstants.collectionUsers).insert(userData);
      } catch (dbError) {
        final errorMsg = dbError.toString();
        String detailedError;
        
        if (errorMsg.contains('owner_approved') || errorMsg.contains('column') || errorMsg.contains('does not exist')) {
          detailedError = 'Database setup error: Please add owner_approved column to users table. Error: ${formatDatabaseError(errorMsg)}';
        } else if (errorMsg.contains('duplicate') || errorMsg.contains('already exists')) {
          try {
            final existingUser = await getUserById(user.id);
            if (existingUser != null) {
              return existingUser;
            }
          } catch (_) {}
          detailedError = 'Account already exists. Please try logging in.';
        } else {
          detailedError = formatDatabaseError(errorMsg);
        }
        
        throw Exception(detailedError);
      }

      return userModel;
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message ?? 'An error occurred during signup'));
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

      final response = await _client.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return null;
      }

      final userModel = await getUserById(user.id);
      
      // Check if user is approved by admin
      if (userModel != null && userModel.adminApproved == false) {
        throw Exception('Your account is pending admin approval. Please wait for approval before logging in.');
      }

      return userModel;
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message ?? 'An error occurred during signin'));
    } catch (e) {
      throw Exception('Error signing in: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
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

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final email = currentUser.email;
      if (email == null) {
        throw Exception('User email not found');
      }

      await _client.auth.signInWithPassword(
        email: email,
        password: oldPassword,
      );

      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return true;
    } on AuthException catch (e) {
      throw Exception(formatAuthError(e.message ?? 'Failed to change password'));
    } catch (e) {
      throw Exception('Error changing password: ${e.toString()}');
    }
  }
}
