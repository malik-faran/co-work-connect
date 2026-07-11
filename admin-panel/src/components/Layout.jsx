import { useState, useEffect } from 'react'
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { getMenuSections, getPageMeta, isAdmin } from '../lib/permissions'
import {
  LayoutDashboard,
  UserCheck,
  Users,
  Building2,
  Calendar,
  LogOut,
  Menu,
  PanelLeftClose,
  PanelLeft,
  DollarSign,
  Star,
  MessageSquare,
  Bell,
  Users as UsersIcon,
  FileCheck,
  CreditCard,
  ClipboardCheck,
  Wallet,
  Shield,
  Landmark,
  History,
  Flag,
  Banknote,
  Inbox,
  Briefcase,
  Search,
  Smartphone,
} from 'lucide-react'

const ICON_MAP = {
  LayoutDashboard,
  UserCheck,
  Users,
  Building2,
  Calendar,
  DollarSign,
  Star,
  MessageSquare,
  Bell,
  UsersIcon,
  FileCheck,
  CreditCard,
  ClipboardCheck,
  Wallet,
  Shield,
  Landmark,
  History,
  Flag,
  Banknote,
  Inbox,
  Briefcase,
  Search,
  Smartphone,
}

const Layout = ({ user, setUser }) => {
  const location = useLocation()
  const navigate = useNavigate()
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [isMobile, setIsMobile] = useState(window.innerWidth < 900)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [pendingOwners, setPendingOwners] = useState(0)
  const [pendingWorkspaces, setPendingWorkspaces] = useState(0)
  const [pendingPayments, setPendingPayments] = useState(0)
  const [pendingTopUps, setPendingTopUps] = useState(0)
  const [pendingRefunds, setPendingRefunds] = useState(0)
  const [pendingReports, setPendingReports] = useState(0)
  const [pendingPayouts, setPendingPayouts] = useState(0)
  const [unreadInbox, setUnreadInbox] = useState(0)
  const [heldCollabPayments, setHeldCollabPayments] = useState(0)

  const pageMeta = getPageMeta(location.pathname)
  const menuSections = getMenuSections(user?.role || '').map((section) => ({
    ...section,
    items: section.items.map((item) => ({
      ...item,
      icon: ICON_MAP[item.icon] || LayoutDashboard,
    })),
  }))

  const badgeMap = {
    owners: pendingOwners,
    workspaces: pendingWorkspaces,
    payments: pendingPayments,
    topups: pendingTopUps,
    refunds: pendingRefunds,
    reports: pendingReports,
    payouts: pendingPayouts,
    inbox: unreadInbox,
    collabHeld: heldCollabPayments,
  }

  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth < 900
      setIsMobile(mobile)
      if (mobile) {
        setSidebarOpen(false)
        setMobileMenuOpen(false)
      } else {
        setSidebarOpen(true)
      }
    }
    window.addEventListener('resize', handleResize)
    handleResize()
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  useEffect(() => {
    if (!user) return
    const fetchPendingCounts = async () => {
      try {
        const { data, error } = await supabase
          .from('users')
          .select('id')
          .eq('role', 'owner')
          .is('owner_approved', null)

        if (!error && data) setPendingOwners(data.length)

        const { data: wsData, error: wsError } = await supabase
          .from('workspaces')
          .select('id')
          .is('workspace_approved', null)

        if (!wsError && wsData) setPendingWorkspaces(wsData.length)

        let payRes = await supabase
          .from('payments')
          .select('id')
          .eq('receipt_status', 'awaiting_verification')
          .eq('payee_type', 'platform')

        if (payRes.error?.message?.includes('payee_type')) {
          payRes = await supabase
            .from('payments')
            .select('id')
            .eq('receipt_status', 'awaiting_verification')
        }
        if (!payRes.error && payRes.data) setPendingPayments(payRes.data.length)

        const topUpRes = await supabase
          .from('wallet_topup_requests')
          .select('id')
          .eq('status', 'pending')
        if (!topUpRes.error && topUpRes.data) setPendingTopUps(topUpRes.data.length)

        const refundRes = await supabase
          .from('refund_requests')
          .select('id')
          .eq('status', 'pending')
        if (!refundRes.error && refundRes.data) setPendingRefunds(refundRes.data.length)

        const reportRes = await supabase
          .from('user_reports')
          .select('id')
          .eq('status', 'pending')
        if (!reportRes.error && reportRes.data) setPendingReports(reportRes.data.length)

        const payoutRes = await supabase
          .from('owner_payout_requests')
          .select('id')
          .eq('status', 'pending')
        if (!payoutRes.error && payoutRes.data) setPendingPayouts(payoutRes.data.length)

        const inboxRes = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false)
        if (!inboxRes.error && inboxRes.data) setUnreadInbox(inboxRes.data.length)

        const collabRes = await supabase
          .from('collaboration_payments')
          .select('id')
          .eq('status', 'held')
        if (!collabRes.error && collabRes.data) setHeldCollabPayments(collabRes.data.length)
      } catch (error) {
        console.error('Error fetching pending counts:', error)
      }
    }
    fetchPendingCounts()
    const interval = setInterval(fetchPendingCounts, 15000)
    return () => clearInterval(interval)
  }, [location.pathname, user])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    setUser(null)
    navigate('/login')
  }

  const handleNavClick = (e) => {
    if (!user) {
      e.preventDefault()
      handleLogout()
      return
    }
    if (isMobile) setMobileMenuOpen(false)
  }

  const initials = (user?.name || user?.email || 'S')
    .split(' ')
    .map((p) => p[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()

  return (
    <div className="app-shell">
      {isMobile && mobileMenuOpen && (
        <div
          className="modal-backdrop"
          style={{ zIndex: 999 }}
          onClick={() => setMobileMenuOpen(false)}
          role="presentation"
        />
      )}

      <aside
        className={`app-sidebar ${!sidebarOpen && !isMobile ? 'is-collapsed' : ''} ${isMobile && mobileMenuOpen ? 'is-mobile-open' : ''}`}
        style={isMobile ? { transform: mobileMenuOpen ? 'translateX(0)' : 'translateX(-100%)' } : undefined}
      >
        <div className="app-sidebar__brand">
          <h1>CWC {isAdmin(user?.role) ? 'Admin' : 'Moderator'}</h1>
          {(sidebarOpen || isMobile) && (
            <p>{isAdmin(user?.role) ? 'Management Console' : 'Digital Assistant Console'}</p>
          )}
        </div>

        <nav className="app-sidebar__nav">
          {menuSections.map((section) => (
            <div key={section.id} className="nav-section">
              {(sidebarOpen || isMobile) && (
                <div className="nav-section__label">{section.label}</div>
              )}
              {section.items.map((item) => {
                const Icon = item.icon
                const isActive = location.pathname === item.path
                const badgeCount = badgeMap[item.badge] || 0
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    onClick={handleNavClick}
                    className={`nav-link ${isActive ? 'is-active' : ''}`}
                    title={!sidebarOpen && !isMobile ? item.label : undefined}
                  >
                    <Icon size={20} />
                    {(sidebarOpen || isMobile) && <span>{item.label}</span>}
                    {badgeCount > 0 && (
                      <span className="nav-link__badge">{badgeCount}</span>
                    )}
                  </Link>
                )
              })}
            </div>
          ))}
        </nav>

        <div className="app-sidebar__footer">
          {(sidebarOpen || isMobile) && (
            <div className="user-chip">
              <div className="user-chip__avatar">{initials}</div>
              <div className="user-chip__meta">
                <div className="user-chip__name">{user?.name || user?.email}</div>
                <div className="user-chip__role">{user?.role}</div>
              </div>
            </div>
          )}
          <button type="button" className="btn btn--danger btn--md" style={{ width: '100%' }} onClick={handleLogout}>
            <LogOut size={16} />
            {(sidebarOpen || isMobile) && 'Sign out'}
          </button>
        </div>
      </aside>

      <div className={`app-main ${!sidebarOpen && !isMobile ? 'is-collapsed' : ''}`}>
        <header className="app-topbar">
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <button
              type="button"
              className="icon-btn"
              onClick={() => (isMobile ? setMobileMenuOpen(true) : setSidebarOpen(!sidebarOpen))}
              aria-label="Toggle sidebar"
            >
              {isMobile ? <Menu size={18} /> : sidebarOpen ? <PanelLeftClose size={18} /> : <PanelLeft size={18} />}
            </button>
            <div>
              <div className="app-topbar__title">{pageMeta.title}</div>
              <div className="app-topbar__crumb">CWC Panel / {pageMeta.crumb}</div>
            </div>
          </div>
          <span className="badge badge--primary" style={{ textTransform: 'capitalize' }}>
            {user?.role}
          </span>
        </header>

        <main className="app-content legacy-admin">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

export default Layout
