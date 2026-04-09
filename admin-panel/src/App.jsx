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

function App() {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Check if user is already logged in
    const savedUser = localStorage.getItem('admin_user')
    if (savedUser) {
      try {
        const user = JSON.parse(savedUser)
        setUser(user)
      } catch (e) {
        localStorage.removeItem('admin_user')
        setUser(null)
      }
    }
    setLoading(false)
  }, [])

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

