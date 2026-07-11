import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { useState, useEffect, useRef } from 'react'
import Login from './pages/Login'
import Landing from './pages/Landing'
import Dashboard from './pages/Dashboard'
import OwnerRequests from './pages/OwnerRequests'
import Users from './pages/Users'
import Workspaces from './pages/Workspaces'
import WorkspaceRequests from './pages/WorkspaceRequests'
import Bookings from './pages/Bookings'
import Reviews from './pages/Reviews'
import Collaborations from './pages/Collaborations'
import Notifications from './pages/Notifications'
import ChatMonitoring from './pages/ChatMonitoring'
import Payments from './pages/Payments'
import OwnerRevenue from './pages/OwnerRevenue'
import Moderators from './pages/Moderators'
import ModeratorActivity from './pages/ModeratorActivity'
import PaymentVerification from './pages/PaymentVerification'
import WalletTopUpVerification from './pages/WalletTopUpVerification'
import WalletRefunds from './pages/WalletRefunds'
import WalletExplorer from './pages/WalletExplorer'
import StaffInbox from './pages/StaffInbox'
import CollaborationHub from './pages/CollaborationHub'
import Reports from './pages/Reports'
import OwnerPayouts from './pages/OwnerPayouts'
import PlatformAccounts from './pages/PlatformAccounts'
import AppRelease from './pages/AppRelease'
import Layout from './components/Layout'
import ProtectedRoute from './components/ProtectedRoute'
import Loading from './components/Loading'
import { supabase, fetchStaffProfileWithTimeout } from './lib/supabase'

function App() {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const loginInProgress = useRef(false)

  useEffect(() => {
    let mounted = true

    const loadSession = async (session) => {
      if (!session?.user) {
        if (mounted) setUser(null)
        return
      }
      try {
        const profile = await fetchStaffProfileWithTimeout(session.user.id)
        if (mounted) {
          setUser({
            id: session.user.id,
            email: session.user.email,
            role: profile.role,
            name: profile.name,
          })
        }
      } catch {
        supabase.auth.signOut().catch(() => {})
        if (mounted) setUser(null)
      }
    }

    const safetyTimer = setTimeout(() => {
      if (mounted) setLoading(false)
    }, 8000)

    supabase.auth
      .getSession()
      .then(({ data: { session } }) => loadSession(session))
      .catch(() => {
        if (mounted) setUser(null)
      })
      .finally(() => {
        clearTimeout(safetyTimer)
        if (mounted) setLoading(false)
      })

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (!mounted) return
        // Login page handles SIGNED_IN itself — avoid double fetch + signOut race
        if (event === 'SIGNED_IN' && loginInProgress.current) return
        if (event === 'INITIAL_SESSION') return
        if (event === 'SIGNED_OUT') {
          setUser(null)
          return
        }
        await loadSession(session)
      }
    )

    return () => {
      mounted = false
      clearTimeout(safetyTimer)
      subscription.unsubscribe()
    }
  }, [])

  const handleLoginSuccess = (staffUser) => {
    loginInProgress.current = false
    setUser(staffUser)
  }

  const handleLoginStart = () => {
    loginInProgress.current = true
  }

  const handleLoginEnd = () => {
    loginInProgress.current = false
  }

  if (loading) {
    return <Loading message="Loading staff panel..." />
  }

  const guard = (element) => (
    <ProtectedRoute user={user}>{element}</ProtectedRoute>
  )

  return (
    <Router>
      <Routes>
        <Route path="/" element={<Landing user={user} />} />

        <Route
          path="/login"
          element={
            user ? (
              <Navigate to="/dashboard" replace />
            ) : (
              <Login
                onLoginStart={handleLoginStart}
                onLoginSuccess={handleLoginSuccess}
                onLoginEnd={handleLoginEnd}
              />
            )
          }
        />

        <Route
          element={
            user ? (
              <Layout user={user} setUser={setUser} />
            ) : (
              <Navigate to="/login" replace />
            )
          }
        >
          <Route path="dashboard" element={guard(<Dashboard />)} />
          <Route path="staff-inbox" element={guard(<StaffInbox user={user} />)} />
          <Route path="owner-requests" element={guard(<OwnerRequests />)} />
          <Route path="workspace-requests" element={guard(<WorkspaceRequests />)} />
          <Route path="users" element={guard(<Users user={user} />)} />
          <Route path="workspaces" element={guard(<Workspaces />)} />
          <Route path="bookings" element={guard(<Bookings />)} />
          <Route path="reviews" element={guard(<Reviews />)} />
          <Route path="collaborations" element={guard(<Collaborations />)} />
          <Route path="notifications" element={guard(<Notifications />)} />
          <Route path="chat-monitoring" element={guard(<ChatMonitoring />)} />
          <Route path="payments" element={guard(<Payments />)} />
          <Route path="owner-revenue" element={guard(<OwnerRevenue />)} />
          <Route path="moderators" element={guard(<Moderators user={user} />)} />
          <Route path="moderator-activity" element={guard(<ModeratorActivity user={user} />)} />
          <Route path="payment-verification" element={guard(<PaymentVerification />)} />
          <Route path="wallet-topup-verification" element={guard(<WalletTopUpVerification />)} />
          <Route path="wallet-refunds" element={guard(<WalletRefunds />)} />
          <Route path="wallet-explorer" element={guard(<WalletExplorer />)} />
          <Route path="owner-payouts" element={guard(<OwnerPayouts />)} />
          <Route path="reports" element={guard(<Reports />)} />
          <Route path="collaboration-hub" element={guard(<CollaborationHub />)} />
          <Route path="platform-accounts" element={guard(<PlatformAccounts user={user} />)} />
          <Route path="app-release" element={guard(<AppRelease user={user} />)} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Router>
  )
}

export default App
