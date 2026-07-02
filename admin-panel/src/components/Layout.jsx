import { useState, useEffect } from 'react'
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { getMenuItems, isAdmin } from '../lib/permissions'
import { 
  LayoutDashboard, 
  UserCheck, 
  Users, 
  Building2, 
  Calendar,
  LogOut,
  Menu,
  X,
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
}

const Layout = ({ user, setUser }) => {
  const location = useLocation()
  const navigate = useNavigate()
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [isMobile, setIsMobile] = useState(window.innerWidth < 768)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [pendingOwners, setPendingOwners] = useState(0)
  const [pendingWorkspaces, setPendingWorkspaces] = useState(0)
  const [pendingPayments, setPendingPayments] = useState(0)
  const [pendingRefunds, setPendingRefunds] = useState(0)
  const [pendingReports, setPendingReports] = useState(0)
  const [pendingPayouts, setPendingPayouts] = useState(0)

  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth < 768
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
        
        if (!error && data) {
          setPendingOwners(data.length)
        }

        const { data: wsData, error: wsError } = await supabase
          .from('workspaces')
          .select('id')
          .is('workspace_approved', null)

        if (!wsError && wsData) {
          setPendingWorkspaces(wsData.length)
        }

        let payData = null
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
        if (!payRes.error && payRes.data) {
          payData = payRes.data
        }

        if (payData) {
          setPendingPayments(payData.length)
        }

        const refundRes = await supabase
          .from('refund_requests')
          .select('id')
          .eq('status', 'pending')

        if (!refundRes.error && refundRes.data) {
          setPendingRefunds(refundRes.data.length)
        }

        const reportRes = await supabase
          .from('user_reports')
          .select('id')
          .eq('status', 'pending')

        if (!reportRes.error && reportRes.data) {
          setPendingReports(reportRes.data.length)
        }

        const payoutRes = await supabase
          .from('owner_payout_requests')
          .select('id')
          .eq('status', 'pending')

        if (!payoutRes.error && payoutRes.data) {
          setPendingPayouts(payoutRes.data.length)
        }
      } catch (error) {
        console.error('Error fetching pending owner requests count:', error)
      }
    }
    fetchPendingCounts()
    // Fetch every 15 seconds to keep sidebar status active
    const interval = setInterval(fetchPendingCounts, 15000)
    return () => clearInterval(interval)
  }, [location.pathname, user])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    setUser(null)
    navigate('/login')
  }

  const menuItems = getMenuItems(user?.role || '').map((item) => ({
    ...item,
    icon: ICON_MAP[item.icon] || LayoutDashboard,
  }))

  const handleNavClick = (e) => {
    if (!user) {
      e.preventDefault()
      handleLogout()
      return
    }
    if (isMobile) setMobileMenuOpen(false)
  }

  const sidebarWidth = isMobile ? '280px' : sidebarOpen ? '280px' : '80px'

  const sidebarContent = (
    <>
      <div style={{ 
        padding: '24px 20px', 
        borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
        background: 'linear-gradient(135deg, rgba(99, 102, 241, 0.2) 0%, rgba(139, 92, 246, 0.2) 100%)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          {(sidebarOpen || isMobile) && (
            <div>
              <h1 style={{ 
                fontSize: '24px', 
                fontWeight: 'bold',
                background: 'linear-gradient(135deg, #ffffff 0%, #e0e7ff 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text'
              }}>
                CWC {isAdmin(user?.role) ? 'Admin' : 'Moderator'}
              </h1>
              <p style={{ 
                fontSize: '12px', 
                color: 'rgba(255, 255, 255, 0.7)',
                marginTop: '4px'
              }}>
                {isAdmin(user?.role) ? 'Management Panel' : 'Digital Assistant Panel'}
              </p>
            </div>
          )}
          <button
            onClick={() => isMobile ? setMobileMenuOpen(false) : setSidebarOpen(!sidebarOpen)}
            style={{
              background: 'rgba(255, 255, 255, 0.1)',
              border: 'none',
              color: 'white',
              cursor: 'pointer',
              padding: '10px',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'all 0.2s',
              width: '40px',
              height: '40px'
            }}
          >
            {(sidebarOpen || isMobile) ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>

      <nav style={{ padding: '16px 12px', flex: 1, overflowY: 'auto' }}>
        {menuItems.map((item) => {
          const Icon = item.icon
          const isActive = location.pathname === item.path
          const isOwnerRequests = item.path === '/owner-requests'
          const isWorkspaceRequests = item.path === '/workspace-requests'
          const isPaymentVerification = item.path === '/payment-verification'
          const isWalletRefunds = item.path === '/wallet-refunds'
          const badgeCount =
            (item.badge === 'owners' && pendingOwners) ||
            (item.badge === 'workspaces' && pendingWorkspaces) ||
            (item.badge === 'payments' && pendingPayments) ||
            (item.badge === 'refunds' && pendingRefunds) ||
            (item.badge === 'reports' && pendingReports) ||
            (item.badge === 'payouts' && pendingPayouts) ||
            0
          return (
            <Link
              key={item.path}
              to={item.path}
              onClick={handleNavClick}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '14px 16px',
                marginBottom: '6px',
                borderRadius: '12px',
                textDecoration: 'none',
                color: isActive ? 'white' : 'rgba(255, 255, 255, 0.8)',
                background: isActive 
                  ? 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)' 
                  : 'transparent',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                fontWeight: isActive ? '600' : '500',
                boxShadow: isActive ? '0 4px 12px rgba(99, 102, 241, 0.3)' : 'none',
                transform: isActive ? 'translateX(4px)' : 'translateX(0)',
                position: 'relative'
              }}
            >
              <Icon 
                size={22} 
                style={{ 
                  marginRight: (sidebarOpen || isMobile) ? '14px' : '0', 
                  minWidth: '22px',
                  filter: isActive ? 'drop-shadow(0 2px 4px rgba(0,0,0,0.2))' : 'none'
                }} 
              />
              {(sidebarOpen || isMobile) && (
                <span style={{ 
                  fontSize: '14px',
                  letterSpacing: '0.3px',
                  flex: 1
                }}>
                  {item.label}
                </span>
              )}
              {badgeCount > 0 && (
                <span style={{
                  background: isPaymentVerification
                    ? 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)'
                    : isWalletRefunds
                    ? 'linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%)'
                    : isOwnerRequests
                    ? 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)'
                    : 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)',
                  color: 'white',
                  borderRadius: '10px',
                  padding: '2px 8px',
                  fontSize: '11px',
                  fontWeight: '700',
                  boxShadow: '0 2px 8px rgba(0, 0, 0, 0.2)',
                  marginLeft: (sidebarOpen || isMobile) ? '8px' : '0',
                  position: (sidebarOpen || isMobile) ? 'static' : 'absolute',
                  top: (sidebarOpen || isMobile) ? 'auto' : '6px',
                  right: (sidebarOpen || isMobile) ? 'auto' : '6px'
                }}>
                  {badgeCount}
                </span>
              )}
            </Link>
          )
        })}
      </nav>

      <div style={{ 
        padding: '20px', 
        borderTop: '1px solid rgba(255, 255, 255, 0.1)', 
        background: 'rgba(0, 0, 0, 0.2)'
      }}>
        {(sidebarOpen || isMobile) && (
          <div style={{ 
            marginBottom: '16px', 
            padding: '12px',
            background: 'rgba(255, 255, 255, 0.1)',
            borderRadius: '10px',
            backdropFilter: 'blur(10px)'
          }}>
            <div style={{ fontSize: '11px', color: 'rgba(255, 255, 255, 0.6)', marginBottom: '6px', textTransform: 'uppercase', letterSpacing: '1px' }}>
              Logged in as
            </div>
            <div style={{ fontSize: '13px', fontWeight: '600', color: 'white', wordBreak: 'break-all' }}>
              {user?.email || 'Admin'}
            </div>
          </div>
        )}
        <button
          onClick={handleLogout}
          style={{
            width: '100%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '12px 16px',
            borderRadius: '10px',
            border: 'none',
            background: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
            color: 'white',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '600',
            boxShadow: '0 4px 12px rgba(239, 68, 68, 0.3)',
            transition: 'all 0.3s'
          }}
        >
          <LogOut size={18} style={{ marginRight: (sidebarOpen || isMobile) ? '8px' : '0', minWidth: '18px' }} />
          {(sidebarOpen || isMobile) && 'Logout'}
        </button>
      </div>
    </>
  )

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      {/* Mobile overlay */}
      {isMobile && mobileMenuOpen && (
        <div
          onClick={() => setMobileMenuOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            zIndex: 999,
            transition: 'opacity 0.3s',
          }}
        />
      )}

      {/* Sidebar */}
      <aside style={{
        width: sidebarWidth,
        background: 'linear-gradient(180deg, #1e293b 0%, #0f172a 100%)',
        color: 'white',
        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        position: 'fixed',
        height: '100vh',
        display: 'flex',
        flexDirection: 'column',
        zIndex: 1000,
        boxShadow: '4px 0 20px rgba(0, 0, 0, 0.1)',
        borderRight: '1px solid rgba(255, 255, 255, 0.1)',
        ...(isMobile ? {
          transform: mobileMenuOpen ? 'translateX(0)' : 'translateX(-100%)',
        } : {})
      }}>
        {sidebarContent}
      </aside>

      {/* Mobile top bar */}
      {isMobile && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          height: '60px',
          background: 'linear-gradient(180deg, #1e293b 0%, #0f172a 100%)',
          display: 'flex',
          alignItems: 'center',
          padding: '0 16px',
          zIndex: 998,
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
        }}>
          <button
            onClick={() => setMobileMenuOpen(true)}
            style={{
              background: 'rgba(255,255,255,0.1)',
              border: 'none',
              color: 'white',
              cursor: 'pointer',
              padding: '8px',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <Menu size={24} />
          </button>
          <h1 style={{
            fontSize: '18px',
            fontWeight: 'bold',
            color: 'white',
            marginLeft: '12px',
          }}>
            CWC Admin
          </h1>
        </div>
      )}

      {/* Main Content */}
      <main style={{
        marginLeft: isMobile ? 0 : (sidebarOpen ? '280px' : '80px'),
        flex: 1,
        transition: 'margin-left 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        padding: isMobile ? '76px 12px 16px 12px' : '32px',
        minHeight: '100vh',
        background: 'transparent',
        width: isMobile ? '100%' : 'auto',
        overflow: 'hidden',
      }}>
        <div style={{
          maxWidth: '1400px',
          margin: '0 auto',
          animation: 'fadeIn 0.4s ease-out'
        }}>
          <Outlet />
        </div>
      </main>
    </div>
  )
}

export default Layout
