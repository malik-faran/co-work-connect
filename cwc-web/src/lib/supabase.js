import { createClient } from '@supabase/supabase-js'

// Same Supabase project as the Flutter app.
const supabaseUrl =
  import.meta.env.VITE_SUPABASE_URL || 'https://wlnzjfhlsqxnwnyildys.supabase.co'

const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsbnpqZmhsc3F4bndueWlsZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3Mjk4NzMsImV4cCI6MjA3OTMwNTg3M30.zX5JeMAFyhh0WFM07Gi_ClWiYP8ya9-Gq6ZPLM_Pj1c'

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})

// Storage bucket names (must match the Flutter app's StorageService).
export const BUCKETS = {
  profiles: 'profiles',
  workspaces: 'workspaces',
  chatImages: 'chat_images',
  projectCovers: 'project_covers',
  collaborationFiles: 'collaboration_files',
  paymentReceipts: 'payment_receipts',
}
