import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/supabase_service.dart';

/// Collaboration Hub Service
/// Roles, applications, members, milestones, files, activity, invites,
/// portfolio + the project lifecycle (publish / launch / complete).
class CollaborationHubService {
  final _supabase = SupabaseService.client;
  final _uuid = const Uuid();
  final _notifications = NotificationService();
  final _chat = ChatService();

  // ----------------------------------------------------------------- ROLES
  Future<List<CollaborationRole>> getRoles(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_roles')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('sort_order');
    return rows.map((r) => CollaborationRole.fromMap(r)).toList();
  }

  Future<void> addRole(CollaborationRole role) async {
    final data = role.toMap()..removeWhere((k, v) => v == null);
    await _supabase.from('collaboration_roles').insert(data);
  }

  Future<void> deleteRole(String roleId) async {
    await _supabase.from('collaboration_roles').delete().eq('id', roleId);
  }

  // ---------------------------------------------------------- APPLICATIONS
  Future<List<CollaborationApplication>> getApplications(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_applications')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('created_at', ascending: false);
    return rows.map((r) => CollaborationApplication.fromMap(r)).toList();
  }

  Future<List<CollaborationApplication>> getUserApplications(String userId) async {
    final rows = await _supabase
        .from('collaboration_applications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => CollaborationApplication.fromMap(r)).toList();
  }

  Future<bool> hasApplied(String collaborationId, String userId) async {
    final row = await _supabase
        .from('collaboration_applications')
        .select('id')
        .eq('collaboration_id', collaborationId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> apply(CollaborationApplication application, String ownerId, String projectTitle) async {
    final data = application.toMap()..removeWhere((k, v) => v == null);
    await _supabase.from('collaboration_applications').insert(data);
    await _notify(
      ownerId,
      'New application',
      '${application.userName} applied for ${application.roleTitle ?? 'your project'} on "$projectTitle"',
      'collaboration_application',
      {'collaboration_id': application.collaborationId},
    );
  }

  Future<void> setApplicationStatus(
    CollaborationApplication app, {
    required String status,
    String? rejectReason,
    required String projectTitle,
  }) async {
    await _supabase.from('collaboration_applications').update({
      'status': status,
      if (rejectReason != null) 'reject_reason': rejectReason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', app.id);

    if (status == 'shortlisted') {
      await _notify(app.userId, 'You were shortlisted',
          'You have been shortlisted for "$projectTitle"', 'collaboration_shortlisted',
          {'collaboration_id': app.collaborationId});
    } else if (status == 'rejected') {
      await _notify(app.userId, 'Application update',
          'Your application for "$projectTitle" was not selected.', 'collaboration_rejected',
          {'collaboration_id': app.collaborationId});
    }
  }

  // --------------------------------------------------------------- MEMBERS
  Future<List<CollaborationMember>> getMembers(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_members')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('joined_at');
    return rows.map((r) => CollaborationMember.fromMap(r)).toList();
  }

  Future<bool> isMember(String collaborationId, String userId) async {
    final row = await _supabase
        .from('collaboration_members')
        .select('id')
        .eq('collaboration_id', collaborationId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<List<CollaborationModel>> getUserTeams(String userId) async {
    final memberRows = await _supabase
        .from('collaboration_members')
        .select('collaboration_id')
        .eq('user_id', userId);
    final ids = memberRows
        .map((m) => m['collaboration_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];
    final rows = await _supabase
        .from('collaborations')
        .select()
        .inFilter('id', ids)
        .order('updated_at', ascending: false);
    return rows.map((r) => CollaborationModel.fromCollaborationMap(r)).toList();
  }

  Future<void> _addMember({
    required String collaborationId,
    required String userId,
    required String userName,
    String? userImage,
    String role = 'member',
    String? roleTitle,
    String joinedVia = 'discover',
  }) async {
    final member = CollaborationMember(
      id: _uuid.v4(),
      collaborationId: collaborationId,
      userId: userId,
      userName: userName,
      userProfileImage: userImage,
      role: role,
      roleTitle: roleTitle,
      joinedVia: joinedVia,
      joinedAt: DateTime.now(),
    );
    final data = member.toMap()..removeWhere((k, v) => v == null);
    await _supabase
        .from('collaboration_members')
        .upsert(data, onConflict: 'collaboration_id,user_id');
  }

  Future<void> removeMember(String collaborationId, String userId) async {
    await _supabase
        .from('collaboration_members')
        .delete()
        .eq('collaboration_id', collaborationId)
        .eq('user_id', userId);
  }

  // ------------------------------------------------------------ MILESTONES
  Future<List<CollaborationMilestone>> getMilestones(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_milestones')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('sort_order');
    return rows.map((r) => CollaborationMilestone.fromMap(r)).toList();
  }

  Future<void> addMilestone(CollaborationMilestone milestone) async {
    final data = milestone.toMap()..removeWhere((k, v) => v == null);
    await _supabase.from('collaboration_milestones').insert(data);
  }

  Future<void> toggleMilestone(CollaborationMilestone milestone, String userId, String userName) async {
    final done = !milestone.isDone;
    await _supabase.from('collaboration_milestones').update({
      'status': done ? 'done' : 'pending',
      'completed_by': done ? userId : null,
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    }).eq('id', milestone.id);
    if (done) {
      await logActivity(milestone.collaborationId, userId, userName,
          'milestone_done', milestone.title);
    }
  }

  Future<void> deleteMilestone(String id) async {
    await _supabase.from('collaboration_milestones').delete().eq('id', id);
  }

  Future<void> notifyOverdueMilestones(String collaborationId) async {
    await _supabase.rpc('notify_overdue_milestones', params: {
      'p_collaboration_id': collaborationId,
    });
  }

  // ----------------------------------------------------------------- FILES
  Future<List<CollaborationFile>> getFiles(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_files')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('created_at', ascending: false);
    return rows.map((r) => CollaborationFile.fromMap(r)).toList();
  }

  Future<void> addFile(CollaborationFile file, String userName) async {
    final data = file.toMap()..removeWhere((k, v) => v == null);
    await _supabase.from('collaboration_files').insert(data);
    if (file.uploadedBy != null) {
      await logActivity(file.collaborationId, file.uploadedBy!, userName,
          'file_uploaded', file.fileName);
    }
  }

  Future<void> deleteFile(String id) async {
    await _supabase.from('collaboration_files').delete().eq('id', id);
  }

  // -------------------------------------------------------------- ACTIVITY
  Future<List<CollaborationActivity>> getActivity(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_activity')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((r) => CollaborationActivity.fromMap(r)).toList();
  }

  Future<void> logActivity(
      String collaborationId, String actorId, String actorName, String action, String? detail) async {
    try {
      final activity = CollaborationActivity(
        id: _uuid.v4(),
        collaborationId: collaborationId,
        actorId: actorId,
        actorName: actorName,
        action: action,
        detail: detail,
        createdAt: DateTime.now(),
      );
      final data = activity.toMap()..removeWhere((k, v) => v == null);
      await _supabase.from('collaboration_activity').insert(data);
    } catch (e) {
      debugPrint('logActivity failed: $e');
    }
  }

  // --------------------------------------------------------------- INVITES
  /// Invitations expire after this duration (shown as expired in notifications).
  static const Duration inviteValidity = Duration(hours: 48);

  bool isInviteExpired(
    CollaborationInvite invite, {
    String? projectStatus,
  }) {
    if (invite.status != 'pending') return false;
    if (DateTime.now().difference(invite.createdAt) > inviteValidity) {
      return true;
    }
    if (projectStatus == 'completed' ||
        projectStatus == 'cancelled' ||
        projectStatus == 'draft') {
      return true;
    }
    return false;
  }

  Future<Map<String, String>> getCollaborationStatuses(
    Set<String> collaborationIds,
  ) async {
    if (collaborationIds.isEmpty) return {};
    final rows = await _supabase
        .from('collaborations')
        .select('id, status')
        .inFilter('id', collaborationIds.toList());
    return {
      for (final row in rows)
        row['id'] as String: row['status'] as String? ?? 'recruiting',
    };
  }

  Future<List<CollaborationInvite>> getUserInvites(String userId) async {
    final rows = await _supabase
        .from('collaboration_invites')
        .select()
        .eq('invited_user', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map((r) => CollaborationInvite.fromMap(r)).toList();
  }

  Future<CollaborationInvite?> getInviteById(String inviteId) async {
    final row = await _supabase
        .from('collaboration_invites')
        .select()
        .eq('id', inviteId)
        .maybeSingle();
    if (row == null) return null;
    return CollaborationInvite.fromMap(row);
  }

  /// Invites the owner has sent for a project (owner-only via RLS invited_by).
  Future<List<CollaborationInvite>> getSentInvites(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_invites')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('created_at', ascending: false);
    return rows.map((r) => CollaborationInvite.fromMap(r)).toList();
  }

  Future<CollaborationInvite?> getPendingInviteForProject(
      String collaborationId, String userId) async {
    final row = await _supabase
        .from('collaboration_invites')
        .select()
        .eq('collaboration_id', collaborationId)
        .eq('invited_user', userId)
        .eq('status', 'pending')
        .maybeSingle();
    if (row == null) return null;
    return CollaborationInvite.fromMap(row);
  }

  /// Latest invite for a user on a project (any status).
  Future<CollaborationInvite?> getInviteForUserOnProject(
    String collaborationId,
    String userId,
  ) async {
    final rows = await _supabase
        .from('collaboration_invites')
        .select()
        .eq('collaboration_id', collaborationId)
        .eq('invited_user', userId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return CollaborationInvite.fromMap(rows.first);
  }

  /// All invites received by a user (pending, accepted, declined).
  Future<List<CollaborationInvite>> getAllUserInvites(String userId) async {
    final rows = await _supabase
        .from('collaboration_invites')
        .select()
        .eq('invited_user', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => CollaborationInvite.fromMap(r)).toList();
  }

  Future<void> sendInvite(CollaborationInvite invite) async {
    final data = invite.toMap()..removeWhere((k, v) => v == null);
    await _supabase
        .from('collaboration_invites')
        .upsert(data, onConflict: 'collaboration_id,invited_user');
    await _notify(
      invite.invitedUser,
      'Project invitation',
      '${invite.invitedByName ?? 'Someone'} invited you to "${invite.collaborationTitle ?? 'a project'}"',
      'collaboration_invite',
      {
        'collaboration_id': invite.collaborationId,
        'invite_id': invite.id,
      },
    );
  }

  Future<void> respondToInvite(CollaborationInvite invite, bool accept) async {
    await _supabase.from('collaboration_invites').update({
      'status': accept ? 'accepted' : 'declined',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', invite.id);
  }

  /// Accept an invite end-to-end: marks invite accepted and either joins the
  /// active project or adds the user to the recruiting roster (auto-accepted
  /// application) so the owner sees them ready for launch.
  Future<void> acceptInvite({
    required CollaborationInvite invite,
    required String userId,
    required String userName,
    required String userEmail,
    String? userImage,
    List<String> userSkills = const [],
  }) async {
    final project = await _supabase
        .from('collaborations')
        .select()
        .eq('id', invite.collaborationId)
        .maybeSingle();
    if (project == null) {
      throw Exception('This project no longer exists');
    }
    final model = CollaborationModel.fromCollaborationMap(project);

    if (invite.status != 'pending') {
      throw Exception('This invitation is no longer available');
    }
    if (isInviteExpired(invite, projectStatus: model.status)) {
      throw Exception('This invitation has expired');
    }
    if (!model.isActive && !model.isRecruiting) {
      throw Exception('This project is no longer accepting members');
    }

    await respondToInvite(invite, true);

    if (model.isActive) {
      await joinActiveProject(
        collaboration: model,
        userId: userId,
        userName: userName,
        userImage: userImage,
        roleTitle: invite.roleTitle,
        joinedVia: 'invite',
      );
    } else if (model.isRecruiting) {
      await _supabase.from('collaboration_applications').upsert({
        'id': _uuid.v4(),
        'collaboration_id': invite.collaborationId,
        if (invite.roleId != null) 'role_id': invite.roleId,
        if (invite.roleTitle != null) 'role_title': invite.roleTitle,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        if (userImage != null) 'user_profile_image': userImage,
        'user_skills': userSkills,
        'pitch_message': 'Accepted invitation from ${invite.invitedByName ?? 'the owner'}.',
        'status': 'accepted',
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'collaboration_id,user_id');
      await _notify(model.userId, 'Invite accepted',
          '$userName accepted your invite to "${model.title}"', 'collaboration_application',
          {'collaboration_id': model.id});
    }
  }

  // -------------------------------------------------------------- PORTFOLIO
  Future<List<PortfolioItem>> getPortfolio(String userId) async {
    final rows = await _supabase
        .from('user_portfolio_items')
        .select()
        .eq('user_id', userId)
        .order('sort_order');
    return rows.map((r) => PortfolioItem.fromMap(r)).toList();
  }

  Future<void> savePortfolioItem(PortfolioItem item) async {
    final data = item.toMap()..removeWhere((k, v) => v == null);
    await _supabase.from('user_portfolio_items').upsert(data);
  }

  Future<void> deletePortfolioItem(String id) async {
    await _supabase.from('user_portfolio_items').delete().eq('id', id);
  }

  // -------------------------------------------------- OPEN TO COLLABORATE
  Future<List<Map<String, dynamic>>> getOpenTeammates({String? excludeUserId}) async {
    var query = _supabase
        .from('users')
        .select()
        .eq('collaboration_enabled', true)
        .eq('role', 'user');
    final rows = await query.order('updated_at', ascending: false).limit(100);
    final list = List<Map<String, dynamic>>.from(rows);
    if (excludeUserId != null) {
      list.removeWhere((u) => u['id'] == excludeUserId);
    }
    return list;
  }

  // ---------------------------------------------------------- INVITE LINK
  Future<CollaborationModel?> getByInviteCode(String code) async {
    final result = await _supabase
        .from('collaborations')
        .select()
        .eq('invite_code', code.toUpperCase().trim())
        .maybeSingle();
    if (result == null) return null;
    return CollaborationModel.fromCollaborationMap(result);
  }

  /// Resolve a pasted invite link or raw code into a project.
  Future<CollaborationModel?> resolveInvite(String input) async {
    final trimmed = input.trim();
    final code = trimmed.contains('/')
        ? trimmed.split('/').last
        : trimmed;
    if (code.isEmpty) return null;
    return getByInviteCode(code);
  }

  Future<void> recordLinkJoin(String collaborationId, String userId) async {
    try {
      await _supabase.from('collaboration_link_joins').insert({
        'id': _uuid.v4(),
        'collaboration_id': collaborationId,
        'user_id': userId,
        'joined_via': 'link',
      });
    } catch (_) {}
  }

  // ------------------------------------------------------------- LIFECYCLE
  /// Owner launches the project: recruiting -> active.
  /// Builds the team, opens the group chat, seeds activity, notifies members.
  Future<void> launchProject({
    required CollaborationModel collaboration,
    required List<CollaborationApplication> acceptedApplications,
  }) async {
    final ownerId = collaboration.userId;

    // 1) Owner becomes a team member.
    await _addMember(
      collaborationId: collaboration.id,
      userId: ownerId,
      userName: collaboration.userName,
      userImage: collaboration.userProfileImage,
      role: 'owner',
      roleTitle: 'Project Lead',
      joinedVia: 'owner',
    );

    // 2) Accepted applicants become members + applications marked accepted.
    final groupMembers = <Map<String, String?>>[
      {'id': ownerId, 'name': collaboration.userName, 'image': collaboration.userProfileImage},
    ];
    for (final app in acceptedApplications) {
      await _addMember(
        collaborationId: collaboration.id,
        userId: app.userId,
        userName: app.userName,
        userImage: app.userProfileImage,
        roleTitle: app.roleTitle,
        joinedVia: app.status == 'shortlisted' ? 'discover' : 'discover',
      );
      await _supabase.from('collaboration_applications').update({
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', app.id);
      groupMembers.add({'id': app.userId, 'name': app.userName, 'image': app.userProfileImage});
    }

    // 3) Group chat room with all members.
    await _chat.createGroupChatRoom(
      collaborationId: collaboration.id,
      ownerId: ownerId,
      name: collaboration.title,
      members: groupMembers,
    );

    // 4) Status -> active.
    await _supabase.from('collaborations').update({
      'status': 'active',
      'launched_at': DateTime.now().toIso8601String(),
      'recruiting_closed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', collaboration.id);

    // 5) Activity + notifications.
    await logActivity(collaboration.id, ownerId, collaboration.userName, 'launched', collaboration.title);
    for (final app in acceptedApplications) {
      await _notify(
        app.userId,
        'Project started!',
        '"${collaboration.title}" has started. Open the Project Room to begin.',
        'collaboration_launched',
        {'collaboration_id': collaboration.id},
      );
    }
  }

  /// Add a member to an already-active project (e.g. accepted later, link join).
  Future<void> joinActiveProject({
    required CollaborationModel collaboration,
    required String userId,
    required String userName,
    String? userImage,
    String? roleTitle,
    String joinedVia = 'discover',
  }) async {
    await _addMember(
      collaborationId: collaboration.id,
      userId: userId,
      userName: userName,
      userImage: userImage,
      roleTitle: roleTitle,
      joinedVia: joinedVia,
    );
    final room = await _chat.getGroupRoomForCollaboration(collaboration.id);
    if (room != null) {
      await _chat.addGroupMember(
        chatRoomId: room.id,
        userId: userId,
        userName: userName,
        userProfileImage: userImage,
      );
    }
    await logActivity(collaboration.id, userId, userName, 'joined',
        joinedVia == 'link' ? 'joined via invite link' : 'joined the team');
    if (collaboration.userId != userId) {
      await _notify(collaboration.userId, 'New teammate',
          '$userName joined "${collaboration.title}"', 'collaboration_launched',
          {'collaboration_id': collaboration.id});
    }
  }

  Future<void> completeProject(CollaborationModel collaboration, String actorName) async {
    await _supabase.from('collaborations').update({
      'status': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', collaboration.id);
    await logActivity(collaboration.id, collaboration.userId, actorName, 'completed', collaboration.title);
    final members = await getMembers(collaboration.id);
    for (final m in members) {
      if (m.userId == collaboration.userId) continue;
      await _notify(m.userId, 'Project completed',
          '"${collaboration.title}" has been marked completed. Great work!',
          'collaboration_completed', {'collaboration_id': collaboration.id});
    }
  }

  Future<void> updateMeetingLink(String collaborationId, String? link) async {
    await _supabase.from('collaborations').update({
      'meeting_link': link,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', collaborationId);
  }

  Future<void> setInviteLinkEnabled(String collaborationId, bool enabled) async {
    await _supabase.from('collaborations').update({
      'invite_link_enabled': enabled,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', collaborationId);
  }

  Future<String?> regenerateInviteCode(String collaborationId) async {
    final code = _randomCode();
    await _supabase.from('collaborations').update({
      'invite_code': code,
      'invite_code_rotated_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', collaborationId);
    return code;
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    var seed = now;
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(chars[seed % chars.length]);
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------- HELPER
  Future<void> _notify(String userId, String title, String message, String type,
      Map<String, dynamic> metadata) async {
    try {
      await _notifications.createNotification(NotificationModel(
        id: _uuid.v4(),
        userId: userId,
        title: title,
        message: message,
        type: type,
        createdAt: DateTime.now(),
        metadata: metadata,
      ));
    } catch (e) {
      debugPrint('notify failed: $e');
    }
  }
}
