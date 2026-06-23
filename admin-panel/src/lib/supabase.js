import { createClient } from '@supabase/supabase-js'

// Same project as the Flutter app — override via .env in production.
const supabaseUrl =
  import.meta.env.VITE_SUPABASE_URL ||
  'https://wlnzjfhlsqxnwnyildys.supabase.co'

const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsbnpqZmhsc3F4bndueWlsZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3Mjk4NzMsImV4cCI6MjA3OTMwNTg3M30.zX5JeMAFyhh0WFM07Gi_ClWiYP8ya9-Gq6ZPLM_Pj1c'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

/** Verify session user has admin role in public.users */
export async function fetchAdminProfile(userId) {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, name, role')
    .eq('id', userId)
    .single()

  if (error) throw error
  if (data?.role !== 'admin') {
    throw new Error('Access denied. This account is not an admin.')
  }
  return data
}
