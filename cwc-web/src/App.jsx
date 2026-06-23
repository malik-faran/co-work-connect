import { useEffect } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './context/AuthContext'
import Layout from './components/Layout'
import ProtectedRoute from './components/ProtectedRoute'
import { Loading } from './components/common'

import Landing from './pages/Landing'
import RoleSelection from './pages/auth/RoleSelection'
import Login from './pages/auth/Login'
import Signup from './pages/auth/Signup'
import ForgotPassword from './pages/auth/ForgotPassword'
import VerifyEmail from './pages/auth/VerifyEmail'

import Home from './pages/user/Home'
import WorkspaceDetail from './pages/user/WorkspaceDetail'
import BookingHistory from './pages/user/BookingHistory'
import Payment from './pages/user/Payment'
import BookingConfirmation from './pages/user/BookingConfirmation'
import PaymentHistory from './pages/user/PaymentHistory'

import Collaborations from './pages/collab/Collaborations'
import CollabCreate from './pages/collab/CollabCreate'
import CollabDetail from './pages/collab/CollabDetail'
import CollabProject from './pages/collab/CollabProject'
import CollabJoin from './pages/collab/CollabJoin'

import ChatList from './pages/chat/ChatList'
import ChatRoom from './pages/chat/ChatRoom'
import Notifications from './pages/Notifications'
import Sos from './pages/Sos'

import Profile from './pages/profile/Profile'
import CollaborationProfile from './pages/profile/CollaborationProfile'
import PortfolioEditor from './pages/profile/PortfolioEditor'
import PublicProfile from './pages/profile/PublicProfile'

import OwnerDashboard from './pages/owner/OwnerDashboard'
import AddWorkspace from './pages/owner/AddWorkspace'
import WorkspaceManagement from './pages/owner/WorkspaceManagement'
import OwnerBookings from './pages/owner/OwnerBookings'
import OwnerAnalytics from './pages/owner/OwnerAnalytics'
import PaymentAccounts from './pages/owner/PaymentAccounts'
import OwnerReceipts from './pages/owner/OwnerReceipts'

export default function App() {
  const { loading, isAuthed, isOwner } = useAuth()

  useEffect(() => {
    if (window.AOS) window.AOS.init({ once: true, duration: 600, offset: 40 })
  }, [])

  if (loading) return <Loading full message="Starting CWL..." />

  const homeRedirect = isAuthed ? (isOwner ? '/owner' : '/home') : '/welcome'

  return (
    <Routes>
      {/* Public */}
      <Route path="/welcome" element={isAuthed ? <Navigate to={homeRedirect} /> : <Landing />} />
      <Route path="/get-started" element={isAuthed ? <Navigate to={homeRedirect} /> : <RoleSelection />} />
      <Route path="/login" element={isAuthed ? <Navigate to={homeRedirect} /> : <Login />} />
      <Route path="/signup" element={isAuthed ? <Navigate to={homeRedirect} /> : <Signup />} />
      <Route path="/forgot-password" element={<ForgotPassword />} />
      <Route path="/verify-email" element={<VerifyEmail />} />

      {/* Authenticated shell */}
      <Route element={<ProtectedRoute><Layout /></ProtectedRoute>}>
        <Route path="/home" element={<Home />} />
        <Route path="/workspace/:id" element={<WorkspaceDetail />} />
        <Route path="/bookings" element={<BookingHistory />} />
        <Route path="/booking/:id/confirmation" element={<BookingConfirmation />} />
        <Route path="/payment/:bookingId" element={<Payment />} />
        <Route path="/payments" element={<PaymentHistory />} />

        <Route path="/collaborations" element={<Collaborations />} />
        <Route path="/collaborations/create" element={<CollabCreate />} />
        <Route path="/collaborations/:id" element={<CollabDetail />} />
        <Route path="/collaborations/:id/edit" element={<CollabCreate />} />
        <Route path="/project/:id" element={<CollabProject />} />
        <Route path="/join" element={<CollabJoin />} />
        <Route path="/join/:code" element={<CollabJoin />} />

        <Route path="/chats" element={<ChatList />} />
        <Route path="/chats/:id" element={<ChatRoom />} />
        <Route path="/notifications" element={<Notifications />} />
        <Route path="/sos" element={<Sos />} />

        <Route path="/profile" element={<Profile />} />
        <Route path="/collaboration-profile" element={<CollaborationProfile />} />
        <Route path="/portfolio" element={<PortfolioEditor />} />
        <Route path="/u/:id" element={<PublicProfile />} />

        {/* Owner */}
        <Route path="/owner" element={<ProtectedRoute ownerOnly><OwnerDashboard /></ProtectedRoute>} />
        <Route path="/owner/workspace/new" element={<ProtectedRoute ownerOnly><AddWorkspace /></ProtectedRoute>} />
        <Route path="/owner/workspace/:id/edit" element={<ProtectedRoute ownerOnly><AddWorkspace /></ProtectedRoute>} />
        <Route path="/owner/workspace/:id" element={<ProtectedRoute ownerOnly><WorkspaceManagement /></ProtectedRoute>} />
        <Route path="/owner/bookings" element={<ProtectedRoute ownerOnly><OwnerBookings /></ProtectedRoute>} />
        <Route path="/owner/analytics" element={<ProtectedRoute ownerOnly><OwnerAnalytics /></ProtectedRoute>} />
        <Route path="/owner/payment-accounts" element={<ProtectedRoute ownerOnly><PaymentAccounts /></ProtectedRoute>} />
        <Route path="/owner/receipts" element={<ProtectedRoute ownerOnly><OwnerReceipts /></ProtectedRoute>} />
      </Route>

      <Route path="/" element={<Navigate to={homeRedirect} replace />} />
      <Route path="*" element={<Navigate to={homeRedirect} replace />} />
    </Routes>
  )
}
