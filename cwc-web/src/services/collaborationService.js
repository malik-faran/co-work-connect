import { supabase } from '../lib/supabase'
import { uuid } from '../lib/helpers'
import { notificationService } from './notificationService'
import { chatService } from './chatService'

async function notify(userId, title, message, type, metadata) {
  await notificationService.create({ userId, title, message, type, metadata })
}

export const collaborationService = {
  // ----- Discover -----
  async getDiscover(currentUserId) {
    const { data, error } = await supabase
      .from('collaborations')
      .select('*')
      .in('status', ['recruiting', 'open'])
      .order('created_at', { ascending: false })
    if (error) throw error
    return (data || [])
      .filter((c) => c.visibility !== 'invite_only')
      .filter((c) => c.user_id !== currentUserId)
  },

  async getMyPosts(userId) {
    const { data, error } = await supabase
      .from('collaborations')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async getMyTeams(userId) {
    const { data: members } = await supabase
      .from('collaboration_members')
      .select('collaboration_id')
      .eq('user_id', userId)
    const ids = (members || []).map((m) => m.collaboration_id)
    if (!ids.length) return []
    const { data } = await supabase
      .from('collaborations')
      .select('*')
      .in('id', ids)
      .order('created_at', { ascending: false })
    return data || []
  },

  async getMyApplications(userId) {
    const { data, error } = await supabase
      .from('collaboration_applications')
      .select('*, collaborations(*)')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  // ----- Single project -----
  async getById(id) {
    const { data, error } = await supabase
      .from('collaborations')
      .select('*')
      .eq('id', id)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async getRoles(collaborationId) {
    const { data } = await supabase
      .from('collaboration_roles')
      .select('*')
      .eq('collaboration_id', collaborationId)
      .order('sort_order', { ascending: true })
    return data || []
  },

  async getMembers(collaborationId) {
    const { data } = await supabase
      .from('collaboration_members')
      .select('*')
      .eq('collaboration_id', collaborationId)
      .order('joined_at', { ascending: true })
    return data || []
  },

  async getApplications(collaborationId) {
    const { data } = await supabase
      .from('collaboration_applications')
      .select('*')
      .eq('collaboration_id', collaborationId)
      .order('created_at', { ascending: false })
    return data || []
  },

  async hasApplied(collaborationId, userId) {
    const { data } = await supabase
      .from('collaboration_applications')
      .select('id, status')
      .eq('collaboration_id', collaborationId)
      .eq('user_id', userId)
      .maybeSingle()
    return data
  },

  async isMember(collaborationId, userId) {
    const { data } = await supabase
      .from('collaboration_members')
      .select('id, role')
      .eq('collaboration_id', collaborationId)
      .eq('user_id', userId)
      .maybeSingle()
    return data
  },

  // ----- Create -----
  async createProject({ owner, title, description, projectType, budget, timeline, visibility, coverImageUrl, roles }) {
    const id = uuid()
    const requiredSkills = [...new Set((roles || []).flatMap((r) => r.skills || []))]
    const { data, error } = await supabase
      .from('collaborations')
      .insert({
        id,
        user_id: owner.id,
        user_name: owner.name,
        user_email: owner.email,
        user_profile_image: owner.profile_image_url || null,
        title,
        description,
        required_skills: requiredSkills,
        collaboration_type: 'need_help',
        project_mode: 'team_project',
        project_type: projectType,
        budget: budget || null,
        timeline: timeline || null,
        status: 'recruiting',
        visibility: visibility || 'public',
        cover_image_url: coverImageUrl || null,
        invite_link_enabled: true,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error

    if (roles?.length) {
      const roleRows = roles.map((r, i) => ({
        id: uuid(),
        collaboration_id: id,
        title: r.title,
        required_skills: r.skills || [],
        sort_order: i,
        created_at: new Date().toISOString(),
      }))
      await supabase.from('collaboration_roles').insert(roleRows)
    }
    return data
  },

  async updateProject(id, fields) {
    const { data, error } = await supabase
      .from('collaborations')
      .update({ ...fields, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async deleteProject(id) {
    const { error } = await supabase.from('collaborations').delete().eq('id', id)
    if (error) throw error
  },

  // ----- Apply -----
  async apply({ project, role, user, pitch, availability, proposedRate }) {
    const { data, error } = await supabase
      .from('collaboration_applications')
      .insert({
        id: uuid(),
        collaboration_id: project.id,
        role_id: role?.id || null,
        role_title: role?.title || null,
        user_id: user.id,
        user_name: user.name,
        user_email: user.email,
        user_profile_image: user.profile_image_url || null,
        user_skills: user.skills || [],
        pitch_message: pitch,
        availability: availability || null,
        proposed_rate: proposedRate || null,
        status: 'pending',
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error
    await notify(
      project.user_id,
      'New Application',
      `${user.name} applied to "${project.title}"`,
      'collaboration_application',
      { collaboration_id: project.id }
    )
    return data
  },

  async setApplicationStatus(application, status, reason) {
    const patch = { status, updated_at: new Date().toISOString() }
    if (status === 'rejected') patch.reject_reason = reason || null
    const { error } = await supabase
      .from('collaboration_applications')
      .update(patch)
      .eq('id', application.id)
    if (error) throw error
    if (status === 'shortlisted') {
      await notify(application.user_id, 'Shortlisted', 'You were shortlisted for a project.', 'collaboration_shortlisted', { collaboration_id: application.collaboration_id })
    } else if (status === 'rejected') {
      await notify(application.user_id, 'Application Update', 'Your application was not selected.', 'collaboration_rejected', { collaboration_id: application.collaboration_id })
    }
  },

  // ----- Launch -----
  async launch(project, owner) {
    const apps = await this.getApplications(project.id)
    const accepted = apps.filter((a) => a.status === 'accepted')

    // owner as member
    const memberRows = [
      {
        id: uuid(),
        collaboration_id: project.id,
        user_id: owner.id,
        user_name: owner.name,
        user_profile_image: owner.profile_image_url || null,
        role: 'owner',
        role_title: 'Project Lead',
        joined_via: 'owner',
        joined_at: new Date().toISOString(),
      },
      ...accepted.map((a) => ({
        id: uuid(),
        collaboration_id: project.id,
        user_id: a.user_id,
        user_name: a.user_name,
        user_profile_image: a.user_profile_image,
        role: 'member',
        role_title: a.role_title,
        joined_via: 'discover',
        joined_at: new Date().toISOString(),
      })),
    ]
    await supabase
      .from('collaboration_members')
      .upsert(memberRows, { onConflict: 'collaboration_id,user_id', ignoreDuplicates: true })

    // group chat room + members
    const { data: room } = await supabase
      .from('chat_rooms')
      .insert({
        id: uuid(),
        user1_id: owner.id,
        room_type: 'group',
        name: project.title,
        collaboration_id: project.id,
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (room) {
      const crm = memberRows.map((m) => ({
        id: uuid(),
        chat_room_id: room.id,
        user_id: m.user_id,
        user_name: m.user_name,
        user_profile_image: m.user_profile_image,
        joined_at: new Date().toISOString(),
      }))
      await supabase
        .from('chat_room_members')
        .upsert(crm, { onConflict: 'chat_room_id,user_id', ignoreDuplicates: true })
    }

    await supabase
      .from('collaborations')
      .update({
        status: 'active',
        launched_at: new Date().toISOString(),
        recruiting_closed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', project.id)

    await this.logActivity(project.id, owner, 'launched', 'Project launched')
    for (const a of accepted) {
      await notify(a.user_id, 'Project Launched', `"${project.title}" has launched. Welcome to the team!`, 'collaboration_launched', { collaboration_id: project.id })
    }
  },

  // ----- Project room data -----
  async getMilestones(collaborationId) {
    const { data } = await supabase
      .from('collaboration_milestones')
      .select('*')
      .eq('collaboration_id', collaborationId)
      .order('sort_order', { ascending: true })
    return data || []
  },

  async addMilestone({ collaborationId, title, description, dueDate, assignedTo, assignedToName, sortOrder }) {
    const { data, error } = await supabase
      .from('collaboration_milestones')
      .insert({
        id: uuid(),
        collaboration_id: collaborationId,
        title,
        description: description || null,
        due_date: dueDate || null,
        assigned_to: assignedTo || null,
        assigned_to_name: assignedToName || null,
        sort_order: sortOrder ?? 0,
        status: 'pending',
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async toggleMilestone(milestone, user) {
    const done = milestone.status !== 'done'
    const { error } = await supabase
      .from('collaboration_milestones')
      .update({
        status: done ? 'done' : 'pending',
        completed_by: done ? user.id : null,
        completed_at: done ? new Date().toISOString() : null,
      })
      .eq('id', milestone.id)
    if (error) throw error
    if (done) await this.logActivity(milestone.collaboration_id, user, 'milestone_done', milestone.title)
  },

  async deleteMilestone(id) {
    await supabase.from('collaboration_milestones').delete().eq('id', id)
  },

  async getFiles(collaborationId) {
    const { data } = await supabase
      .from('collaboration_files')
      .select('*')
      .eq('collaboration_id', collaborationId)
      .order('created_at', { ascending: false })
    return data || []
  },

  async addFile({ collaborationId, user, fileName, fileUrl, fileType, fileSize }) {
    const { data, error } = await supabase
      .from('collaboration_files')
      .insert({
        id: uuid(),
        collaboration_id: collaborationId,
        uploaded_by: user.id,
        uploader_name: user.name,
        file_name: fileName,
        file_url: fileUrl,
        file_type: fileType || null,
        file_size: fileSize || null,
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error
    await this.logActivity(collaborationId, user, 'file_uploaded', fileName)
    return data
  },

  async deleteFile(id) {
    await supabase.from('collaboration_files').delete().eq('id', id)
  },

  async getActivity(collaborationId) {
    const { data } = await supabase
      .from('collaboration_activity')
      .select('*')
      .eq('collaboration_id', collaborationId)
      .order('created_at', { ascending: false })
      .limit(100)
    return data || []
  },

  async logActivity(collaborationId, actor, action, detail) {
    try {
      await supabase.from('collaboration_activity').insert({
        id: uuid(),
        collaboration_id: collaborationId,
        actor_id: actor.id,
        actor_name: actor.name,
        action,
        detail: detail || null,
        created_at: new Date().toISOString(),
      })
    } catch (e) {
      /* ignore */
    }
  },

  async removeMember(collaborationId, userId) {
    await supabase
      .from('collaboration_members')
      .delete()
      .eq('collaboration_id', collaborationId)
      .eq('user_id', userId)
  },

  async markComplete(project, owner) {
    await supabase
      .from('collaborations')
      .update({ status: 'completed', updated_at: new Date().toISOString() })
      .eq('id', project.id)
    await this.logActivity(project.id, owner, 'completed', 'Project completed')
    const members = await this.getMembers(project.id)
    for (const m of members) {
      if (m.user_id !== owner.id) {
        await notify(m.user_id, 'Project Completed', `"${project.title}" is complete.`, 'collaboration_completed', { collaboration_id: project.id })
      }
    }
  },

  // ----- Join active project (link/invite) -----
  async joinActive({ project, user, joinedVia = 'link', roleTitle }) {
    await supabase
      .from('collaboration_members')
      .upsert(
        {
          id: uuid(),
          collaboration_id: project.id,
          user_id: user.id,
          user_name: user.name,
          user_profile_image: user.profile_image_url || null,
          role: 'member',
          role_title: roleTitle || null,
          joined_via: joinedVia,
          joined_at: new Date().toISOString(),
        },
        { onConflict: 'collaboration_id,user_id', ignoreDuplicates: true }
      )
    const room = await chatService.getGroupRoom(project.id)
    if (room) {
      await supabase
        .from('chat_room_members')
        .upsert(
          {
            id: uuid(),
            chat_room_id: room.id,
            user_id: user.id,
            user_name: user.name,
            user_profile_image: user.profile_image_url || null,
            joined_at: new Date().toISOString(),
          },
          { onConflict: 'chat_room_id,user_id', ignoreDuplicates: true }
        )
    }
    await this.logActivity(project.id, user, 'joined', `Joined via ${joinedVia}`)
    await notify(project.user_id, 'New Teammate', `${user.name} joined "${project.title}"`, 'collaboration_launched', { collaboration_id: project.id })
  },

  async getByInviteCode(code) {
    const { data } = await supabase
      .from('collaborations')
      .select('*')
      .eq('invite_code', code.toUpperCase().trim())
      .maybeSingle()
    return data
  },

  // ----- Invites -----
  async sendInvite({ project, role, invitedBy, invitedUser, message }) {
    const { data, error } = await supabase
      .from('collaboration_invites')
      .upsert(
        {
          id: uuid(),
          collaboration_id: project.id,
          collaboration_title: project.title,
          role_id: role?.id || null,
          role_title: role?.title || null,
          invited_by: invitedBy.id,
          invited_by_name: invitedBy.name,
          invited_user: invitedUser,
          message: message || null,
          status: 'pending',
          created_at: new Date().toISOString(),
        },
        { onConflict: 'collaboration_id,invited_user' }
      )
      .select()
      .single()
    if (error) throw error
    await notify(invitedUser, 'Project Invite', `${invitedBy.name} invited you to "${project.title}"`, 'collaboration_invite', { collaboration_id: project.id, invite_id: data.id })
    return data
  },

  async getMyInvites(userId) {
    const { data } = await supabase
      .from('collaboration_invites')
      .select('*')
      .eq('invited_user', userId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
    return data || []
  },

  async respondInvite(invite, accept, user) {
    await supabase
      .from('collaboration_invites')
      .update({ status: accept ? 'accepted' : 'declined', updated_at: new Date().toISOString() })
      .eq('id', invite.id)
    if (!accept) return
    const project = await this.getById(invite.collaboration_id)
    if (!project) return
    if (project.status === 'active') {
      await this.joinActive({ project, user, joinedVia: 'invite', roleTitle: invite.role_title })
    } else if (project.status === 'recruiting') {
      await supabase
        .from('collaboration_applications')
        .upsert(
          {
            id: uuid(),
            collaboration_id: project.id,
            role_id: invite.role_id || null,
            role_title: invite.role_title || null,
            user_id: user.id,
            user_name: user.name,
            user_email: user.email,
            user_profile_image: user.profile_image_url || null,
            user_skills: user.skills || [],
            pitch_message: 'Accepted invite to join the project.',
            status: 'accepted',
            created_at: new Date().toISOString(),
          },
          { onConflict: 'collaboration_id,user_id' }
        )
    }
  },
}
