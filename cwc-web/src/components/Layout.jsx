import { useEffect, useState } from 'react'
import { Link, NavLink, useNavigate, Outlet } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { notificationService } from '../services/notificationService'
import { Avatar } from './common'

export default function Layout() {
  const { profile, userId, isOwner, signOut } = useAuth()
  const navigate = useNavigate()
  const [unread, setUnread] = useState(0)

  useEffect(() => {
    if (!userId) return
    let active = true
    const load = async () => {
      try {
        const c = await notificationService.unreadCount(userId)
        if (active) setUnread(c)
      } catch {
        /* ignore */
      }
    }
    load()
    const unsub = notificationService.subscribe(userId, load)
    return () => {
      active = false
      unsub()
    }
  }, [userId])

  const handleLogout = async () => {
    await signOut()
    navigate('/login')
  }

  const userLinks = [
    { to: '/home', label: 'Explore', icon: 'bi-compass' },
    { to: '/collaborations', label: 'Collaborate', icon: 'bi-people' },
    { to: '/bookings', label: 'Bookings', icon: 'bi-calendar-check' },
    { to: '/chats', label: 'Messages', icon: 'bi-chat-dots' },
  ]
  const ownerLinks = [
    { to: '/owner', label: 'Dashboard', icon: 'bi-grid' },
    { to: '/owner/bookings', label: 'Bookings', icon: 'bi-calendar-check' },
    { to: '/owner/analytics', label: 'Analytics', icon: 'bi-graph-up' },
    { to: '/chats', label: 'Messages', icon: 'bi-chat-dots' },
  ]
  const links = isOwner ? ownerLinks : userLinks

  return (
    <div className="app-shell">
      <nav className="app-navbar">
        <div className="container-app h-100 d-flex align-items-center justify-content-between py-0">
          <Link to={isOwner ? '/owner' : '/home'} className="d-flex align-items-center gap-2">
            <span className="brand-logo">C</span>
            <span className="fw-bold fs-5 d-none d-sm-inline" style={{ color: 'var(--text-primary)' }}>
              CWL
            </span>
          </Link>

          <div className="d-none d-md-flex align-items-center gap-1">
            {links.map((l) => (
              <NavLink key={l.to} to={l.to} className={({ isActive }) => `nav-pill ${isActive ? 'active' : ''}`}>
                <i className={`bi ${l.icon}`}></i>
                {l.label}
              </NavLink>
            ))}
          </div>

          <div className="d-flex align-items-center gap-2">
            <Link to="/notifications" className="nav-pill position-relative" title="Notifications">
              <i className="bi bi-bell fs-5"></i>
              {unread > 0 && <span className="nav-badge">{unread > 9 ? '9+' : unread}</span>}
            </Link>
            <div className="dropdown">
              <button
                className="btn btn-light d-flex align-items-center gap-2 dropdown-toggle"
                data-bs-toggle="dropdown"
                style={{ borderRadius: 999 }}
              >
                <Avatar src={profile?.profile_image_url} name={profile?.name} size={28} />
                <span className="d-none d-lg-inline fw-semibold" style={{ fontSize: '0.88rem' }}>
                  {profile?.name?.split(' ')[0] || 'Account'}
                </span>
              </button>
              <ul className="dropdown-menu dropdown-menu-end shadow border-0 mt-2" style={{ borderRadius: 14 }}>
                <li className="px-3 py-2">
                  <div className="fw-semibold">{profile?.name}</div>
                  <div className="text-secondary small">{profile?.email}</div>
                  <span className="badge-soft badge-primary-soft mt-1 d-inline-block text-capitalize">
                    {profile?.role}
                  </span>
                </li>
                <li><hr className="dropdown-divider" /></li>
                <li><Link className="dropdown-item py-2" to="/profile"><i className="bi bi-person me-2"></i>My Profile</Link></li>
                <li><Link className="dropdown-item py-2" to="/collaboration-profile"><i className="bi bi-stars me-2"></i>Collaboration Profile</Link></li>
                {isOwner && (
                  <li><Link className="dropdown-item py-2" to="/owner/payment-accounts"><i className="bi bi-bank me-2"></i>Payment Accounts</Link></li>
                )}
                <li><Link className="dropdown-item py-2" to="/payments"><i className="bi bi-receipt me-2"></i>Payment History</Link></li>
                <li><Link className="dropdown-item py-2" to="/sos"><i className="bi bi-shield-exclamation me-2 text-danger"></i>Emergency / SOS</Link></li>
                <li><hr className="dropdown-divider" /></li>
                <li><button className="dropdown-item py-2 text-danger" onClick={handleLogout}><i className="bi bi-box-arrow-right me-2"></i>Logout</button></li>
              </ul>
            </div>
          </div>
        </div>
      </nav>

      <main className="app-main">
        <Outlet />
      </main>

      <nav className="bottom-nav">
        {links.map((l) => (
          <NavLink key={l.to} to={l.to} className={({ isActive }) => (isActive ? 'active' : '')}>
            <i className={`bi ${l.icon} fs-5`}></i>
            <span>{l.label}</span>
          </NavLink>
        ))}
        <NavLink to="/profile" className={({ isActive }) => (isActive ? 'active' : '')}>
          <i className="bi bi-person fs-5"></i>
          <span>Profile</span>
        </NavLink>
      </nav>
    </div>
  )
}
