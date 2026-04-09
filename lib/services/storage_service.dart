import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cwc/services/supabase_service.dart';

class StorageService {
  final _supabase = SupabaseService.client;

  Future<String> uploadWorkspaceImage({
    required String workspaceId,
    required XFile file,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to upload images');
    }
    
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
    final filePath = 'workspaces/$workspaceId/$fileName';
    Uint8List data = await file.readAsBytes();
    
    int retries = 0;
    const maxRetries = 2;
    
    while (retries <= maxRetries) {
      try {
        await _supabase.storage
            .from('workspaces')
            .uploadBinary(
              filePath,
              data,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Upload timeout after 30 seconds');
              },
            );
        
        final url = _supabase.storage
            .from('workspaces')
            .getPublicUrl(filePath);
        
        return url;
      } catch (e) {
        retries++;
        if (retries > maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * retries));
      }
    }
    
    throw Exception('Upload failed after retries');
  }

  Future<List<String>> uploadWorkspaceImages({
    required String workspaceId,
    required List<XFile> files,
  }) async {
    final uploadFutures = files.asMap().entries.map((entry) async {
      final file = entry.value;
      try {
        return await uploadWorkspaceImage(
          workspaceId: workspaceId,
          file: file,
        );
      } catch (e) {
        rethrow;
      }
    }).toList();
    
    return await Future.wait(uploadFutures);
  }

  /// Upload CNIC image for user registration (mobile)
  /// Accepts XFile which works on both web and mobile
  Future<String> uploadCNICImage(XFile cnicFile, String identifier) async {
    try {
      final safeIdentifier = identifier
          .replaceAll('@', '_at_')
          .replaceAll('.', '_')
          .replaceAll('/', '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${safeIdentifier}_cnic.jpg';
      final filePath = 'cnic/$fileName';
      
      final bytes = await cnicFile.readAsBytes();
      
      await _supabase.storage
          .from('cnic')
          .uploadBinary(
            filePath,
            bytes,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout after 30 seconds');
            },
          );
      
      final url = _supabase.storage
          .from('cnic')
          .getPublicUrl(filePath);
      
      return url;
    } catch (e) {
      throw Exception('Failed to upload CNIC image: ${e.toString()}');
    }
  }

  Future<String> uploadProfileImage(XFile imageFile, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'profiles/$userId/$fileName';

      final bytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from('profiles')
          .uploadBinary(
            filePath,
            bytes,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout after 30 seconds');
            },
          );

      final url = _supabase.storage
          .from('profiles')
          .getPublicUrl(filePath);

      return url;
    } catch (e) {
      throw Exception('Failed to upload profile image: ${e.toString()}');
    }
  }

  /// Upload CNIC image bytes for user registration (web)
  Future<String> uploadCNICImageBytes(Uint8List imageBytes, String identifier) async {
    try {
      final safeIdentifier = identifier
          .replaceAll('@', '_at_')
          .replaceAll('.', '_')
          .replaceAll('/', '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${safeIdentifier}_cnic.jpg';
      final filePath = 'cnic/$fileName';
      
      await _supabase.storage
          .from('cnic')
          .uploadBinary(
            filePath,
            imageBytes,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout after 30 seconds');
            },
          );
      
      final url = _supabase.storage
          .from('cnic')
          .getPublicUrl(filePath);
      
      return url;
    } catch (e) {
      throw Exception('Failed to upload CNIC image: ${e.toString()}');
    }
  }
}
