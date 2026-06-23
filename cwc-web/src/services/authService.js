import { supabase } from '../lib/supabase'

export const authService = {
  async signUp({ name, email, password, role = 'user', phone, businessName, businessAddress }) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          name,
          role,
          phone: phone || '',
          business_name: businessName || null,
          business_address: businessAddress || null,
        },
      },
    })
    if (error) throw error
    // Ensure a public.users row exists (trigger usually handles this).
    const userId = data.user?.id
    if (userId) {
      await supabase
        .from('users')
        .upsert(
          {
            id: userId,
            email,
            name,
            role,
            phone: phone || '',
            business_name: businessName || null,
            business_address: businessAddress || null,
          },
          { onConflict: 'id', ignoreDuplicates: true }
        )
    }
    return data
  },

  async signIn({ email, password }) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    if (!data.user?.email_confirmed_at) {
      await supabase.auth.signOut()
      throw new Error('Please verify your email before logging in.')
    }
    return data
  },

  async resendVerification(email) {
    const { error } = await supabase.auth.resend({ type: 'signup', email })
    if (error) throw error
  },

  async checkVerified() {
    const { data } = await supabase.auth.refreshSession()
    return !!data.session?.user?.email_confirmed_at
  },

  async forgotPassword(email) {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: window.location.origin + '/login',
    })
    if (error) throw error
  },
}
