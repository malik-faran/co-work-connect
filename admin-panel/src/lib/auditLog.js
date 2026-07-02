import { supabase } from './supabase'

/** Record a staff action in the audit log (owner approve, workspace approve, etc.) */
export async function recordStaffAction({
  action,
  entityType,
  entityId,
  summary,
  details = {},
}) {
  const { error } = await supabase.rpc('record_staff_action', {
    p_action: action,
    p_entity_type: entityType,
    p_entity_id: entityId || null,
    p_summary: summary,
    p_details: details,
  })
  if (error) {
    console.warn('Audit log failed:', error.message)
  }
}

/** Create moderator account via Edge Function (admin only) */
export async function createModeratorAccount({ name, email, password, phone }) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) throw new Error('Not logged in')

  const { data, error } = await supabase.functions.invoke('create-moderator', {
    body: { name, email, password, phone },
    headers: { Authorization: `Bearer ${session.access_token}` },
  })

  if (error) throw error
  if (data?.error) throw new Error(data.error)
  return data
}
