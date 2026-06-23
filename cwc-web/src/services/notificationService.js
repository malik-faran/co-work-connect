import { supabase } from '../lib/supabase'
import { uuid } from '../lib/helpers'

export const notificationService = {
  async getForUser(userId) {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async unreadCount(userId) {
    const { count, error } = await supabase
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('is_read', false)
    if (error) throw error
    return count || 0
  },

  async create({ userId, title, message, type, metadata }) {
    try {
      await supabase.from('notifications').insert({
        id: uuid(),
        user_id: userId,
        title,
        message,
        type,
        is_read: false,
        metadata: metadata || null,
        created_at: new Date().toISOString(),
      })
    } catch (e) {
      console.warn('notification create failed', e)
    }
  },

  async markRead(id) {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('id', id)
    if (error) throw error
  },

  async markAllRead(userId) {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('is_read', false)
    if (error) throw error
  },

  subscribe(userId, onChange) {
    const channel = supabase
      .channel(`notif-${userId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
        onChange
      )
      .subscribe()
    return () => supabase.removeChannel(channel)
  },
}
