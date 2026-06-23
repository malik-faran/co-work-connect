import { supabase } from '../lib/supabase'
import { uuid } from '../lib/helpers'

export const reviewService = {
  async getForWorkspace(workspaceId) {
    const { data, error } = await supabase
      .from('reviews')
      .select('*')
      .eq('workspace_id', workspaceId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async hasReviewedBooking(bookingId) {
    const { data, error } = await supabase
      .from('reviews')
      .select('id')
      .eq('booking_id', bookingId)
      .maybeSingle()
    if (error) throw error
    return !!data
  },

  async create({ bookingId, workspaceId, userId, userName, userImage, rating, comment }) {
    const { data, error } = await supabase
      .from('reviews')
      .insert({
        id: uuid(),
        booking_id: bookingId,
        workspace_id: workspaceId,
        user_id: userId,
        user_name: userName,
        user_profile_image: userImage || null,
        rating,
        comment: comment || null,
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error
    return data
  },
}
