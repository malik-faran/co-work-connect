import 'package:flutter/foundation.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:uuid/uuid.dart';

/// Collaboration Service
/// Handles all collaboration-related database operations
class CollaborationService {
  final _supabase = SupabaseService.client;

  /// Create a new collaboration request
  Future<String> createCollaboration(CollaborationModel collaboration) async {
    try {
      final collaborationData = collaboration.toCollaborationMap();
      collaborationData.removeWhere((key, value) => value == null);

      await _supabase
          .from('collaborations')
          .insert(collaborationData);

      return collaboration.id;
    } catch (e) {
      throw Exception('Failed to create collaboration: ${e.toString()}');
    }
  }

  /// Get all open collaboration requests visible in Discover.
  Future<List<CollaborationModel>> getAllCollaborations({
    String? collaborationType,
    String? projectType,
    List<String>? skillsFilter,
  }) async {
    try {
      List<dynamic> rows;
      try {
        rows = await _supabase.rpc('get_discover_collaborations');
      } catch (rpcError) {
        debugPrint('get_discover_collaborations RPC unavailable, falling back: $rpcError');
        var query = _supabase
            .from('collaborations')
            .select()
            .eq('status', 'recruiting');

        if (collaborationType != null) {
          query = query.eq('collaboration_type', collaborationType);
        }
        if (projectType != null) {
          query = query.eq('project_type', projectType);
        }

        rows = await query.order('created_at', ascending: false);
      }

      List<CollaborationModel> collaborations = rows
          .map((c) => CollaborationModel.fromCollaborationMap(
                Map<String, dynamic>.from(c as Map),
              ))
          .where((c) => c.visibility != 'invite_only' && !c.isInactive)
          .toList();

      if (collaborationType != null) {
        collaborations = collaborations
            .where((c) => c.collaborationType == collaborationType)
            .toList();
      }
      if (projectType != null) {
        collaborations = collaborations
            .where((c) => c.projectType == projectType)
            .toList();
      }

      if (skillsFilter != null && skillsFilter.isNotEmpty) {
        collaborations = collaborations.where((collab) {
          return skillsFilter.any((skill) =>
              collab.requiredSkills.any((reqSkill) =>
                  reqSkill.toLowerCase().contains(skill.toLowerCase())));
        }).toList();
      }

      return collaborations;
    } catch (e) {
      throw Exception('Failed to fetch collaborations: ${e.toString()}');
    }
  }

  /// Get collaborations by user ID
  Future<List<CollaborationModel>> getUserCollaborations(String userId) async {
    try {
      final rows = await _supabase
          .from('collaborations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return rows
          .map((c) => CollaborationModel.fromCollaborationMap(c))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user collaborations: ${e.toString()}');
    }
  }

  /// Get collaboration by ID
  Future<CollaborationModel?> getCollaborationById(String id) async {
    try {
      final result = await _supabase
          .from('collaborations')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (result == null) return null;
      return CollaborationModel.fromCollaborationMap(result);
    } catch (e) {
      throw Exception('Failed to fetch collaboration: ${e.toString()}');
    }
  }

  /// Update collaboration
  Future<void> updateCollaboration(CollaborationModel collaboration) async {
    try {
      final updateData = collaboration
          .copyCollaboration(updatedAt: DateTime.now())
          .toCollaborationMap();
      updateData.removeWhere((key, value) => value == null);

      await _supabase
          .from('collaborations')
          .update(updateData)
          .eq('id', collaboration.id);
    } catch (e) {
      throw Exception('Failed to update collaboration: ${e.toString()}');
    }
  }

  /// Toggle a recruiting post between visible (recruiting) and hidden (inactive).
  Future<void> setProjectListingActive(String collaborationId, bool active) async {
    try {
      await _supabase.from('collaborations').update({
        'status': active ? 'recruiting' : 'inactive',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', collaborationId);
    } catch (e) {
      throw Exception('Failed to update project visibility: ${e.toString()}');
    }
  }

  /// Delete collaboration
  Future<void> deleteCollaboration(String id) async {
    try {
      await _supabase.from('collaborations').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete collaboration: ${e.toString()}');
    }
  }

  /// Add response to collaboration
  Future<String> addResponse(CollaborationResponseModel response) async {
    try {
      final responseData = response.toResponseMap();
      responseData.removeWhere((key, value) => value == null);

      await _supabase
          .from('collaboration_responses')
          .insert(responseData);

      // Update collaboration to add user to responses list
      final collaboration = await getCollaborationById(response.collaborationId);
      if (collaboration != null) {
        final updatedResponses = List<String>.from(collaboration.responses);
        if (!updatedResponses.contains(response.userId)) {
          updatedResponses.add(response.userId);
        }
        await updateCollaboration(
          collaboration.copyCollaboration(responses: updatedResponses),
        );

        try {
          final notificationService = NotificationService();
          await notificationService.sendCollaborationResponseNotification(
            ownerUserId: collaboration.userId,
            responderName: response.userName,
            collaborationTitle: collaboration.title,
            collaborationId: collaboration.id,
          );
        } catch (e) {
          debugPrint('Collaboration response notification failed: $e');
        }
      }

      return response.id;
    } catch (e) {
      throw Exception('Failed to add response: ${e.toString()}');
    }
  }

  /// Get response count for a collaboration
  Future<int> getResponseCount(String collaborationId) async {
    try {
      final rows = await _supabase
          .from('collaboration_responses')
          .select('id')
          .eq('collaboration_id', collaborationId);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  /// Get response counts for multiple collaborations in one go
  Future<Map<String, int>> getResponseCounts(List<String> collaborationIds) async {
    if (collaborationIds.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('collaboration_responses')
          .select('collaboration_id')
          .inFilter('collaboration_id', collaborationIds);

      final counts = <String, int>{};
      for (final row in rows) {
        final cId = row['collaboration_id'] as String?;
        if (cId != null) {
          counts[cId] = (counts[cId] ?? 0) + 1;
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  /// Get responses for a collaboration
  Future<List<CollaborationResponseModel>> getCollaborationResponses(
      String collaborationId) async {
    try {
      final rows = await _supabase
          .from('collaboration_responses')
          .select()
          .eq('collaboration_id', collaborationId)
          .order('created_at', ascending: false);

      return rows
          .map((r) => CollaborationResponseModel.fromResponseMap(r))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch responses: ${e.toString()}');
    }
  }

  /// Accept a collaboration response
  Future<void> acceptResponse(
      String collaborationId, String responseId, String userId) async {
    try {
      // Get collaboration first to get title
      final collaboration = await getCollaborationById(collaborationId);
      if (collaboration == null) {
        throw Exception('Collaboration not found');
      }

      // Update response status
      await _supabase
          .from('collaboration_responses')
          .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', responseId);

      // Update collaboration
      await updateCollaboration(
        collaboration.copyCollaboration(
          status: 'in_progress',
          acceptedUserId: userId,
        ),
      );

      try {
        final notificationService = NotificationService();
        await notificationService.createNotification(
          NotificationModel(
            id: const Uuid().v4(),
            userId: userId,
            title: 'Collaboration Accepted!',
            message: 'Your response to "${collaboration.title}" has been accepted! Start collaborating now.',
            type: 'collaboration_accepted',
            createdAt: DateTime.now(),
            metadata: {
              'collaboration_id': collaborationId,
              'response_id': responseId,
            },
          ),
        );
      } catch (e) {
        debugPrint('Accept notification failed: $e');
      }
    } catch (e) {
      throw Exception('Failed to accept response: ${e.toString()}');
    }
  }

  /// Reject a collaboration response
  Future<void> rejectResponse(
      String collaborationId, String responseId, String userId) async {
    try {
      final collaboration = await getCollaborationById(collaborationId);
      if (collaboration == null) {
        throw Exception('Collaboration not found');
      }

      await _supabase
          .from('collaboration_responses')
          .update({'status': 'rejected', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', responseId);

      try {
        final notificationService = NotificationService();
        await notificationService.createNotification(
          NotificationModel(
            id: const Uuid().v4(),
            userId: userId,
            title: 'Collaboration Response Declined',
            message: 'Your response to "${collaboration.title}" was not accepted. Keep exploring other collaborations!',
            type: 'collaboration_rejected',
            createdAt: DateTime.now(),
            metadata: {
              'collaboration_id': collaborationId,
              'response_id': responseId,
            },
          ),
        );
      } catch (e) {
        debugPrint('Reject notification failed: $e');
      }
    } catch (e) {
      throw Exception('Failed to reject response: ${e.toString()}');
    }
  }

  /// Get stream of collaborations for real-time updates
  Stream<List<CollaborationModel>> getCollaborationsStream() {
    return _supabase
        .from('collaborations')
        .stream(primaryKey: ['id'])
        .eq('status', 'recruiting')
        .order('created_at', ascending: false)
        .map((data) => data
            .map((c) => CollaborationModel.fromCollaborationMap(c))
            .toList());
  }

  /// Publish a draft project (draft -> recruiting).
  Future<void> publishCollaboration(String collaborationId) async {
    await _supabase.from('collaborations').update({
      'status': 'recruiting',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', collaborationId);
  }

  /// Cancel a project.
  Future<void> cancelCollaboration(String collaborationId) async {
    await _supabase.from('collaborations').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', collaborationId);
  }
}
