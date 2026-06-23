import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { useState, useEffect } from 'react'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import OwnerRequests from './pages/OwnerRequests'
import Users from './pages/Users'
import Workspaces from './pages/Workspaces'
import Bookings from './pages/Bookings'
import Reviews from './pages/Reviews'
import Collaborations from './pages/Collaborations'
import Notifications from './pages/Notifications'
import ChatMonitoring from './pages/ChatMonitoring'
import Payments from './pages/Payments'
import OwnerRevenue from './pages/OwnerRevenue'
import Layout from './components/Layout'
import Loading from './components/Loading'
import { supabase, fetchAdminProfile } from './lib/supabase'

function App() {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let mounted = true

    const loadSession = async (session) => {
      if (!session?.user) {
        if (mounted) setUser(null)
        return
      }
      try {
        const profile = await fetchAdminProfile(session.user.id)
        if (mounted) {
          setUser({
            id: session.user.id,
            email: session.user.email,
            role: profile.role,
            name: profile.name,
          })
        }
      } catch {
        await supabase.auth.signOut()
        if (mounted) setUser(null)
      }
    }

    supabase.auth.getSession().then(({ data: { session } }) => {
      loadSession(session).finally(() => {
        if (mounted) setLoading(false)
      })
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (_event, session) => {
        await loadSession(session)
      }
    )

    return () => {
      mounted = false
      subscription.unsubscribe()
    }
  }, [])

  if (loading) {
    return <Loading message="Loading admin panel..." />
  }

  return (
    <Router>
      <Routes>
        <Route
          path="/login"
          element={user ? <Navigate to="/dashboard" /> : <Login setUser={setUser} />}
        />
        <Route
          path="/"
          element={user ? <Layout user={user} setUser={setUser} /> : <Navigate to="/login" />}
        >
          <Route index element={<Navigate to="/dashboard" />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="owner-requests" element={<OwnerRequests />} />
          <Route path="users" element={<Users />} />
          <Route path="workspaces" element={<Workspaces />} />
          <Route path="bookings" element={<Bookings />} />
          <Route path="reviews" element={<Reviews />} />
          <Route path="collaborations" element={<Collaborations />} />
          <Route path="notifications" element={<Notifications />} />
          <Route path="chat-monitoring" element={<ChatMonitoring />} />
          <Route path="payments" element={<Payments />} />
          <Route path="owner-revenue" element={<OwnerRevenue />} />
        </Route>
      </Routes>
    </Router>
  )
}

export default App
