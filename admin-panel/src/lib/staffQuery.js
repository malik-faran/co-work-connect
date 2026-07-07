import { supabase } from './supabase'

/** True when Supabase reports a missing table / schema cache issue. */
export function isSchemaError(err, tableHint = '') {
  const msg = err?.message || String(err || '')
  return (
    err?.code === '42P01' ||
    err?.code === 'PGRST205' ||
    msg.includes('does not exist') ||
    msg.includes('schema cache') ||
    (tableHint && msg.includes(tableHint))
  )
}

/** Plain select (no embed) — avoids FK hint / relationship errors in admin panel. */
export async function fetchPlain(table, { filter, order } = {}) {
  let query = supabase.from(table).select('*')
  if (filter) query = filter(query)
  if (order) query = query.order(order.column, { ascending: order.ascending ?? false })
  const { data, error } = await query
  if (error) throw error
  return data || []
}

/** Attach users rows by id column (default user_id → user). */
export async function hydrateUserField(rows, {
  idKey = 'user_id',
  targetKey = 'user',
  columns = 'id, name, email, phone',
} = {}) {
  if (!rows?.length) return rows || []
  const ids = [...new Set(rows.map((r) => r[idKey]).filter(Boolean))]
  if (!ids.length) return rows

  const { data: users, error } = await supabase.from('users').select(columns).in('id', ids)
  if (error) throw error

  const map = Object.fromEntries((users || []).map((u) => [u.id, u]))
  return rows.map((r) => ({ ...r, [targetKey]: map[r[idKey]] || null }))
}

export async function hydrateUsersByIds(ids, columns = 'id, name, email') {
  const unique = [...new Set(ids.filter(Boolean))]
  if (!unique.length) return {}
  const { data, error } = await supabase.from('users').select(columns).in('id', unique)
  if (error) throw error
  return Object.fromEntries((data || []).map((u) => [u.id, u]))
}

export function roomDisplayLabel(room, userMap = {}) {
  if (room?.room_type === 'group') {
    return room.name || 'Group chat'
  }
  const u1 = room.user1_name || userMap[room.user1_id]?.name || 'User'
  const u2 = room.user2_name || userMap[room.user2_id]?.name || 'User'
  return `${u1} ↔ ${u2}`
}
