import { supabase } from '../lib/supabase'
import { uuid } from '../lib/helpers'
import { notificationService } from './notificationService'

const preview = (type, msg) =>
  type === 'image' ? '📷 Photo' : type === 'file' ? '📎 File' : msg

export const chatService = {
  async getUserChatRooms(userId) {
    // Direct rooms where the user is a participant.
    const { data: direct, error } = await supabase
      .from('chat_rooms')
      .select('*')
      .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
      .order('last_message_at', { ascending: false, nullsFirst: false })
    if (error) throw error

    // Group rooms where the user is a member.
    const { data: memberships } = await supabase
      .from('chat_room_members')
      .select('chat_room_id')
      .eq('user_id', userId)
    const groupIds = (memberships || []).map((m) => m.chat_room_id)
    let groups = []
    if (groupIds.length) {
      const { data: g } = await supabase
        .from('chat_rooms')
        .select('*')
        .in('id', groupIds)
      groups = g || []
    }
    const all = [...(direct || []), ...groups]
    const map = {}
    for (const r of all) map[r.id] = r
    return Object.values(map).sort(
      (a, b) =>
        new Date(b.last_message_at || b.created_at) -
        new Date(a.last_message_at || a.created_at)
    )
  },

  async getOrCreateDirectRoom({ user1Id, user2Id, workspaceId, collaborationId }) {
    const { data: existing } = await supabase
      .from('chat_rooms')
      .select('*')
      .or(
        `and(user1_id.eq.${user1Id},user2_id.eq.${user2Id}),and(user1_id.eq.${user2Id},user2_id.eq.${user1Id})`
      )
      .limit(1)
      .maybeSingle()
    if (existing) return existing

    const { data: users } = await supabase
      .from('users')
      .select('id, name, profile_image_url')
      .in('id', [user1Id, user2Id])
    const u1 = users?.find((u) => u.id === user1Id)
    const u2 = users?.find((u) => u.id === user2Id)

    const { data, error } = await supabase
      .from('chat_rooms')
      .insert({
        id: uuid(),
        user1_id: user1Id,
        user2_id: user2Id,
        user1_name: u1?.name,
        user2_name: u2?.name,
        user1_profile_image: u1?.profile_image_url,
        user2_profile_image: u2?.profile_image_url,
        room_type: 'direct',
        workspace_id: workspaceId || null,
        collaboration_id: collaborationId || null,
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getMessages(roomId, limit = 100) {
    const { data, error } = await supabase
      .from('messages')
      .select('*')
      .eq('chat_room_id', roomId)
      .order('created_at', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data || []).reverse()
  },

  async getRoom(roomId) {
    const { data, error } = await supabase
      .from('chat_rooms')
      .select('*')
      .eq('id', roomId)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async sendMessage({ room, senderId, senderName, senderImage, message, type = 'text', imageUrl }) {
    const text = type === 'image' ? '📷 Photo' : message
    const { data, error } = await supabase
      .from('messages')
      .insert({
        id: uuid(),
        chat_room_id: room.id,
        sender_id: senderId,
        sender_name: senderName,
        sender_profile_image: senderImage || null,
        message: text,
        message_type: type,
        image_url: imageUrl || null,
        is_read: false,
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error

    const isGroup = room.room_type === 'group'
    const roomUpdate = {
      last_message: isGroup
        ? `${(senderName || '').split(' ')[0]}: ${preview(type, message)}`
        : preview(type, message),
      last_message_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }
    if (!isGroup) {
      if (room.user1_id === senderId) roomUpdate.unread_count2 = (room.unread_count2 || 0) + 1
      else roomUpdate.unread_count1 = (room.unread_count1 || 0) + 1
    }
    await supabase.from('chat_rooms').update(roomUpdate).eq('id', room.id)

    // notify receiver(s)
    try {
      if (isGroup) {
        const { data: members } = await supabase
          .from('chat_room_members')
          .select('user_id')
          .eq('chat_room_id', room.id)
        for (const m of members || []) {
          if (m.user_id !== senderId) {
            await notificationService.create({
              userId: m.user_id,
              title: room.name || 'New message',
              message: `${(senderName || '').split(' ')[0]}: ${preview(type, message)}`,
              type: 'chat_message',
              metadata: { chat_room_id: room.id, sender_name: senderName },
            })
          }
        }
      } else {
        const receiver = room.user1_id === senderId ? room.user2_id : room.user1_id
        await notificationService.create({
          userId: receiver,
          title: senderName || 'New message',
          message: preview(type, message),
          type: 'chat_message',
          metadata: { chat_room_id: room.id, sender_name: senderName },
        })
      }
    } catch (e) {
      /* ignore */
    }
    return data
  },

  async markRead(roomId, userId) {
    await supabase
      .from('messages')
      .update({ is_read: true })
      .eq('chat_room_id', roomId)
      .neq('sender_id', userId)
      .eq('is_read', false)
    const room = await this.getRoom(roomId)
    if (room && room.room_type !== 'group') {
      const patch =
        room.user1_id === userId ? { unread_count1: 0 } : { unread_count2: 0 }
      await supabase.from('chat_rooms').update(patch).eq('id', roomId)
    }
  },

  subscribeMessages(roomId, onInsert) {
    const channel = supabase
      .channel(`msgs-${roomId}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'messages', filter: `chat_room_id=eq.${roomId}` },
        onInsert
      )
      .subscribe()
    return () => supabase.removeChannel(channel)
  },

  subscribeRooms(userId, onChange) {
    const channel = supabase
      .channel(`rooms-${userId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'chat_rooms' }, onChange)
      .subscribe()
    return () => supabase.removeChannel(channel)
  },

  // group room for a collaboration
  async getGroupRoom(collaborationId) {
    const { data } = await supabase
      .from('chat_rooms')
      .select('*')
      .eq('collaboration_id', collaborationId)
      .eq('room_type', 'group')
      .maybeSingle()
    return data
  },
}
