import { createClient } from '@supabase/supabase-js'
import { isStaff } from './permissions'

const supabaseUrl =
  import.meta.env.VITE_SUPABASE_URL ||
  'https://wlnzjfhlsqxnwnyildys.supabase.co'

const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsbnpqZmhsc3F4bndueWlsZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3Mjk4NzMsImV4cCI6MjA3OTMwNTg3M30.zX5JeMAFyhh0WFM07Gi_ClWiYP8ya9-Gq6ZPLM_Pj1c'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

function withTimeout(promise, ms, message) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(message)), ms)
    ),
  ])
}

/** Verify session user is admin or moderator (staff) */
export async function fetchStaffProfile(userId) {
  const query = async (columns) => {
    return supabase.from('users').select(columns).eq('id', userId).single()
  }

  let { data, error } = await query('id, email, name, role, moderator_active')

  if (error?.message?.includes('moderator_active')) {
    const fallback = await query('id, email, name, role')
    data = fallback.data
    error = fallback.error
  }

  if (error?.code === 'PGRST116') {
    throw new Error(
      'Account found in Auth but no profile in database. Run: UPDATE users SET role = \'admin\' WHERE email = your@email.com'
    )
  }

  if (error) throw error

  if (!data) {
    throw new Error('User profile not found.')
  }

  if (!isStaff(data.role)) {
    throw new Error(
      `Access denied. This account has role "${data.role}". Only admin or moderator can use this panel.`
    )
  }

  if (data.role === 'moderator' && data.moderator_active === false) {
    throw new Error('Your moderator account has been deactivated. Contact admin.')
  }

  return data
}

export async function fetchStaffProfileWithTimeout(userId, ms = 12000) {
  return withTimeout(
    fetchStaffProfile(userId),
    ms,
    'Profile check timed out. Check Supabase connection or users table.'
  )
}

/** @deprecated use fetchStaffProfile */
export async function fetchAdminProfile(userId) {
  return fetchStaffProfile(userId)
}
