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

  /// Upload chat image. Path: chat_images/{chatRoomId}/{userId}/{filename}
  Future<String> uploadChatImage({
    required String chatRoomId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to send images');
    }

    const maxBytes = 5 * 1024 * 1024; // 5 MB
    if (bytes.length > maxBytes) {
      throw Exception('Image must be smaller than 5 MB');
    }

    final ext = _imageExtension(fileName);
    final safeName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final filePath = '$chatRoomId/${user.id}/$safeName';

    await _supabase.storage
        .from('chat_images')
        .uploadBinary(
          filePath,
          bytes,
        )
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception('Image upload timed out'),
        );

    return _supabase.storage.from('chat_images').getPublicUrl(filePath);
  }

  static String _imageExtension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static bool isAllowedChatImage(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  /// Upload a project cover image. Path: {collaborationId}/{filename}
  Future<String> uploadProjectCover({
    required String collaborationId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw Exception('Cover image must be smaller than 5 MB');
    }
    final ext = _imageExtension(fileName);
    final safeName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final filePath = '$collaborationId/$safeName';

    await _supabase.storage
        .from('project_covers')
        .uploadBinary(filePath, bytes)
        .timeout(const Duration(seconds: 45),
            onTimeout: () => throw Exception('Cover upload timed out'));

    return _supabase.storage.from('project_covers').getPublicUrl(filePath);
  }

  /// Upload a shared collaboration file.
  /// Path: collaboration_files/{collaborationId}/{userId}/{filename}
  Future<String> uploadCollaborationFile({
    required String collaborationId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to upload files');
    }
    const maxBytes = 15 * 1024 * 1024; // 15 MB
    if (bytes.length > maxBytes) {
      throw Exception('File must be smaller than 15 MB');
    }
    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
    final filePath = '$collaborationId/${user.id}/$safeName';

    await _supabase.storage
        .from('collaboration_files')
        .uploadBinary(filePath, bytes)
        .timeout(const Duration(seconds: 60),
            onTimeout: () => throw Exception('File upload timed out'));

    return _supabase.storage.from('collaboration_files').getPublicUrl(filePath);
  }

  static bool isAllowedResume(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx');
  }

  /// Upload user resume/CV. Path: collaboration_files/resume_{userId}/{userId}/{filename}
  Future<String> uploadResume({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!isAllowedResume(fileName)) {
      throw Exception('Resume must be PDF, DOC, or DOCX');
    }
    const maxBytes = 10 * 1024 * 1024; // 10 MB
    if (bytes.length > maxBytes) {
      throw Exception('Resume must be smaller than 10 MB');
    }
    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
    final filePath = 'resume_$userId/$userId/$safeName';

    await _supabase.storage
        .from('collaboration_files')
        .uploadBinary(filePath, bytes)
        .timeout(const Duration(seconds: 60),
            onTimeout: () => throw Exception('Resume upload timed out'));

    return _supabase.storage.from('collaboration_files').getPublicUrl(filePath);
  }

  /// Upload payment receipt. Path: payment_receipts/{userId}/{bookingId}/file
  Future<String> uploadPaymentReceipt({
    required String userId,
    required String bookingId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw Exception('Receipt image must be smaller than 5 MB');
    }

    final ext = _imageExtension(fileName);
    final safeName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final filePath = '$userId/$bookingId/$safeName';

    await _supabase.storage
        .from('payment_receipts')
        .uploadBinary(filePath, bytes);

    return _supabase.storage.from('payment_receipts').getPublicUrl(filePath);
  }
}
