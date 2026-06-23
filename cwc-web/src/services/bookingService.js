import { supabase } from '../lib/supabase'
import { uuid, isUuid, dateKey } from '../lib/helpers'
import { notificationService } from './notificationService'

export const bookingService = {
  async getUserBookings(userId) {
    const { data, error } = await supabase
      .from('bookings')
      .select('*, workspaces(*)')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async getOwnerBookings(ownerId) {
    const { data: ws, error: e1 } = await supabase
      .from('workspaces')
      .select('id')
      .eq('owner_id', ownerId)
    if (e1) throw e1
    const ids = (ws || []).map((w) => w.id)
    if (!ids.length) return []
    const { data, error } = await supabase
      .from('bookings')
      .select('*, workspaces(*)')
      .in('workspace_id', ids)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  // Check seat availability for a date (returns map of `${slotId}|${category}` -> booked seats)
  async getBookedSeats(workspaceId, bDateKey) {
    const { data, error } = await supabase
      .from('bookings')
      .select('time_slot_id, category_type, seat_count, status')
      .eq('workspace_id', workspaceId)
      .eq('booking_date', bDateKey)
      .or('status.eq.pending,status.eq.confirmed')
    if (error) throw error
    const map = {}
    for (const b of data || []) {
      const key = `${b.time_slot_id || ''}|${b.category_type || ''}`
      map[key] = (map[key] || 0) + (b.seat_count || 1)
    }
    return map
  },

  // Create one or more bookings. Returns array of created rows.
  async createBookings({ workspace, userId, mode, date, category, slots, seatCount, monthCount }) {
    const created = []
    const baseDate = date instanceof Date ? date : new Date(date)
    const bKey = dateKey(baseDate)

    if (mode === 'hourly') {
      for (const slot of slots) {
        const start = new Date(baseDate)
        start.setHours(slot.startHour, 0, 0, 0)
        const dur = slot.endHour - slot.startHour
        const end = new Date(start)
        end.setHours(end.getHours() + dur)
        const row = {
          id: uuid(),
          user_id: userId,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          start_date: start.toISOString(),
          end_date: end.toISOString(),
          number_of_days: 0,
          total_price: category.pricePerHour * dur * seatCount,
          status: 'pending',
          is_hourly_booking: true,
          booking_date: bKey,
          time_slot_label: slot.label,
          category_type: category.type,
          seat_count: seatCount,
          price_per_hour: category.pricePerHour,
          price_per_day: category.pricePerDay,
          duration_hours: dur,
          created_at: new Date().toISOString(),
        }
        if (isUuid(slot.id)) row.time_slot_id = slot.id
        created.push(row)
      }
    } else if (mode === 'monthly') {
      const days = 30 * monthCount
      const start = new Date(baseDate)
      start.setHours(0, 0, 0, 0)
      const end = new Date(start)
      end.setDate(end.getDate() + days)
      created.push({
        id: uuid(),
        user_id: userId,
        workspace_id: workspace.id,
        workspace_name: workspace.name,
        start_date: start.toISOString(),
        end_date: end.toISOString(),
        number_of_days: days,
        total_price: category.pricePerDay * 30 * monthCount,
        status: 'pending',
        is_hourly_booking: false,
        booking_date: bKey,
        category_type: category.type,
        seat_count: 1,
        price_per_hour: category.pricePerHour,
        price_per_day: category.pricePerDay,
        duration_hours: 24 * days,
        created_at: new Date().toISOString(),
      })
    } else {
      // daily
      const start = new Date(baseDate)
      start.setHours(0, 0, 0, 0)
      const end = new Date(baseDate)
      end.setHours(23, 59, 0, 0)
      created.push({
        id: uuid(),
        user_id: userId,
        workspace_id: workspace.id,
        workspace_name: workspace.name,
        start_date: start.toISOString(),
        end_date: end.toISOString(),
        number_of_days: 1,
        total_price: category.pricePerDay,
        status: 'pending',
        is_hourly_booking: false,
        booking_date: bKey,
        category_type: category.type,
        seat_count: 1,
        price_per_hour: category.pricePerHour,
        price_per_day: category.pricePerDay,
        duration_hours: 24,
        created_at: new Date().toISOString(),
      })
    }

    const { data, error } = await supabase.from('bookings').insert(created).select()
    if (error) throw error

    // Notify owner
    try {
      await notificationService.create({
        userId: workspace.owner_id,
        title: 'New Booking',
        message: `A new booking was made for ${workspace.name}`,
        type: 'booking_confirmed',
        metadata: { booking_id: data?.[0]?.id, workspace_name: workspace.name },
      })
    } catch (e) {
      /* ignore */
    }
    return data || []
  },

  async updateStatus(id, status, { userId, workspaceName } = {}) {
    const { data, error } = await supabase
      .from('bookings')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    if (userId && (status === 'confirmed' || status === 'cancelled')) {
      await notificationService.create({
        userId,
        title: status === 'confirmed' ? 'Booking Confirmed' : 'Booking Cancelled',
        message:
          status === 'confirmed'
            ? `Your booking for ${workspaceName || 'a workspace'} was confirmed.`
            : `Your booking for ${workspaceName || 'a workspace'} was cancelled.`,
        type: status === 'confirmed' ? 'booking_confirmed' : 'booking_cancelled',
        metadata: { booking_id: id, workspace_name: workspaceName },
      })
    }
    return data
  },
}
