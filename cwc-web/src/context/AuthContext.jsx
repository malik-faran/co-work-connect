import { createContext, useContext, useEffect, useState, useCallback } from 'react'
import { supabase } from '../lib/supabase'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null)
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)

  const loadProfile = useCallback(async (userId) => {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .maybeSingle()
    if (error) {
      console.error('loadProfile error', error)
      return null
    }
    setProfile(data)
    return data
  }, [])

  const refreshProfile = useCallback(async () => {
    if (session?.user?.id) return loadProfile(session.user.id)
    return null
  }, [session, loadProfile])

  useEffect(() => {
    let mounted = true

    const init = async () => {
      const { data } = await supabase.auth.getSession()
      if (!mounted) return
      const s = data.session
      setSession(s)
      if (s?.user?.id && s.user.email_confirmed_at) {
        await loadProfile(s.user.id)
      }
      setLoading(false)
    }
    init()

    const { data: sub } = supabase.auth.onAuthStateChange(async (_e, s) => {
      if (!mounted) return
      setSession(s)
      if (s?.user?.id && s.user.email_confirmed_at) {
        await loadProfile(s.user.id)
      } else {
        setProfile(null)
      }
    })

    return () => {
      mounted = false
      sub.subscription.unsubscribe()
    }
  }, [loadProfile])

  const signOut = useCallback(async () => {
    await supabase.auth.signOut()
    setProfile(null)
    setSession(null)
  }, [])

  const value = {
    session,
    user: session?.user || null,
    profile,
    userId: session?.user?.id || null,
    isOwner: profile?.role === 'owner',
    isAuthed: !!session?.user && !!session?.user?.email_confirmed_at,
    loading,
    loadProfile,
    refreshProfile,
    setProfile,
    signOut,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => useContext(AuthContext)
