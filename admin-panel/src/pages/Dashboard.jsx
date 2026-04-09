import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { Users, Building2, Calendar, UserCheck, Star, MessageSquare, TrendingUp, DollarSign } from 'lucide-react'
import Loading from '../components/Loading'

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalOwners: 0,
    totalWorkspaces: 0,
    totalBookings: 0,
    pendingRequests: 0,
    totalReviews: 0,
    totalCollaborations: 0,
    totalNotifications: 0,
    totalChatRooms: 0,
    totalRevenue: 0,
    pendingApprovals: 0,
    averageRating: 'N/A'
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchStats()
  }, [])

  const fetchStats = async () => {
    try {
      // Total users
      const { count: userCount } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true })
        .eq('role', 'user')

      // Total owners
      const { count: ownerCount } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true })
        .eq('role', 'owner')

      // Pending approvals (admin_approved = false or null)
      const { data: pendingApprovalsData } = await supabase
        .from('users')
        .select('id')
        .eq('admin_approved', false)

      // Pending owner requests
      const { data: pendingData } = await supabase
        .from('users')
        .select('id')
        .eq('role', 'owner')
        .is('owner_approved', null)

      // Total workspaces
      const { count: workspaceCount } = await supabase
        .from('workspaces')
        .select('*', { count: 'exact', head: true })

      // Total bookings
      const { count: bookingCount } = await supabase
        .from('bookings')
        .select('*', { count: 'exact', head: true })

      // Total reviews
      const { count: reviewCount } = await supabase
        .from('reviews')
        .select('*', { count: 'exact', head: true })

      // Total collaborations
      const { count: collabCount } = await supabase
        .from('collaborations')
        .select('*', { count: 'exact', head: true })

      // Total notifications
      const { count: notifCount } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })

      // Total chat rooms
      const { count: chatCount } = await supabase
        .from('chat_rooms')
        .select('*', { count: 'exact', head: true })

      // Total revenue (from confirmed/completed bookings)
      const { data: bookingsData } = await supabase
        .from('bookings')
        .select('total_price')
        .in('status', ['confirmed', 'completed'])

      const totalRevenue = bookingsData?.reduce((sum, booking) => {
        return sum + (parseFloat(booking.total_price) || 0)
      }, 0) || 0

      const { data: reviewsData } = await supabase
        .from('reviews')
        .select('rating')

      const avgRating = reviewsData?.length > 0
        ? (reviewsData.reduce((sum, r) => sum + (r.rating || 0), 0) / reviewsData.length).toFixed(1)
        : 'N/A'

      setStats({
        totalUsers: userCount || 0,
        totalOwners: ownerCount || 0,
        totalWorkspaces: workspaceCount || 0,
        totalBookings: bookingCount || 0,
        pendingRequests: pendingData?.length || 0,
        totalReviews: reviewCount || 0,
        totalCollaborations: collabCount || 0,
        totalNotifications: notifCount || 0,
        totalChatRooms: chatCount || 0,
        totalRevenue: totalRevenue,
        pendingApprovals: pendingApprovalsData?.length || 0,
        averageRating: avgRating
      })
    } catch (error) {
      console.error('Error fetching stats:', error)
    } finally {
      setLoading(false)
    }
  }

  const statCards = [
    { 
      label: 'Total Users', 
      value: stats.totalUsers, 
      icon: Users, 
      bgColor: '#eff6ff',
      iconColor: '#3b82f6',
      textColor: '#1e40af',
      link: '/users'
    },
    { 
      label: 'Total Owners', 
      value: stats.totalOwners, 
      icon: Building2, 
      bgColor: '#f0fdf4',
      iconColor: '#10b981',
      textColor: '#166534',
      link: '/users?filter=owner'
    },
    { 
      label: 'Total Workspaces', 
      value: stats.totalWorkspaces, 
      icon: Building2, 
      bgColor: '#fffbeb',
      iconColor: '#f59e0b',
      textColor: '#92400e',
      link: '/workspaces'
    },
    { 
      label: 'Total Bookings', 
      value: stats.totalBookings, 
      icon: Calendar, 
      bgColor: '#faf5ff',
      iconColor: '#8b5cf6',
      textColor: '#6b21a8',
      link: '/bookings'
    },
    { 
      label: 'Pending Approvals', 
      value: stats.pendingApprovals, 
      icon: UserCheck, 
      bgColor: '#fef2f2',
      iconColor: '#ef4444',
      textColor: '#991b1b',
      link: '/owner-requests'
    },
    { 
      label: 'Total Reviews', 
      value: stats.totalReviews, 
      icon: Star, 
      bgColor: '#fef3c7',
      iconColor: '#f59e0b',
      textColor: '#92400e',
      link: '/reviews'
    },
    { 
      label: 'Collaborations', 
      value: stats.totalCollaborations, 
      icon: Users, 
      bgColor: '#e0e7ff',
      iconColor: '#6366f1',
      textColor: '#3730a3',
      link: '/collaborations'
    },
    { 
      label: 'Chat Rooms', 
      value: stats.totalChatRooms, 
      icon: MessageSquare, 
      bgColor: '#f3e8ff',
      iconColor: '#8b5cf6',
      textColor: '#6b21a8',
      link: '/chat-monitoring'
    },
    { 
      label: 'Total Revenue', 
      value: `PKR ${stats.totalRevenue.toFixed(0)}`, 
      icon: DollarSign, 
      bgColor: '#d1fae5',
      iconColor: '#10b981',
      textColor: '#065f46',
      link: '/owner-revenue'
    },
  ]

  if (loading) {
    return <Loading message="Loading dashboard..." />
  }

  return (
    <div className="fade-in">
      {/* Enhanced Header */}
      <div style={{ 
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '32px',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
        border: '1px solid rgba(255, 255, 255, 0.2)',
        marginBottom: '32px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '20px' }}>
          <div>
            <h1 style={{ 
              fontSize: 'clamp(24px, 5vw, 42px)', 
              fontWeight: '800',
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              backgroundClip: 'text',
              marginBottom: '12px',
              letterSpacing: '-0.5px'
            }}>
              Dashboard
            </h1>
            <p style={{ 
              color: '#64748b', 
              fontSize: '16px',
              fontWeight: '500'
            }}>
              Complete overview of your coworking space platform
            </p>
          </div>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            padding: '12px 20px',
            background: 'linear-gradient(135deg, rgba(16, 185, 129, 0.1) 0%, rgba(5, 150, 105, 0.1) 100%)',
            borderRadius: '12px',
            border: '1px solid rgba(16, 185, 129, 0.2)'
          }}>
            <TrendingUp size={24} color="#10b981" />
            <div>
              <div style={{ fontSize: '11px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '1px' }}>
                Total Revenue
              </div>
              <div style={{ 
                fontSize: '24px', 
                fontWeight: '800',
                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text'
              }}>
                PKR {stats.totalRevenue.toFixed(0)}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Enhanced Stats Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(min(280px, 100%), 1fr))',
        gap: '24px',
        marginBottom: '32px'
      }}>
        {statCards.map((card, index) => {
          const Icon = card.icon
          return (
            <Link
              key={index}
              to={card.link}
              style={{
                textDecoration: 'none',
                display: 'block'
              }}
            >
              <div
                style={{
                  background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
                  backdropFilter: 'blur(10px)',
                  padding: '28px',
                  borderRadius: '16px',
                  boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
                  border: '1px solid rgba(255, 255, 255, 0.2)',
                  transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                  position: 'relative',
                  overflow: 'hidden',
                  cursor: 'pointer'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-6px) scale(1.02)'
                  e.currentTarget.style.boxShadow = '0 12px 40px rgba(0, 0, 0, 0.15)'
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0) scale(1)'
                  e.currentTarget.style.boxShadow = '0 4px 20px rgba(0, 0, 0, 0.08)'
                }}
              >
                {/* Gradient Accent */}
                <div style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  height: '4px',
                  background: `linear-gradient(135deg, ${card.iconColor} 0%, ${card.iconColor}dd 100%)`,
                  borderRadius: '16px 16px 0 0'
                }} />
                
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
                  <div style={{ flex: 1 }}>
                    <p style={{ 
                      fontSize: '13px', 
                      color: '#6b7280', 
                      marginBottom: '12px',
                      fontWeight: '600',
                      textTransform: 'uppercase',
                      letterSpacing: '0.5px'
                    }}>
                      {card.label}
                    </p>
                    <p style={{ 
                      fontSize: 'clamp(24px, 4vw, 36px)', 
                      fontWeight: '800', 
                      background: `linear-gradient(135deg, ${card.textColor} 0%, ${card.textColor}dd 100%)`,
                      WebkitBackgroundClip: 'text',
                      WebkitTextFillColor: 'transparent',
                      backgroundClip: 'text',
                      lineHeight: '1.2',
                      margin: 0
                    }}>
                      {typeof card.value === 'string' ? card.value : card.value.toLocaleString()}
                    </p>
                  </div>
                  <div style={{
                    width: '56px',
                    height: '56px',
                    borderRadius: '14px',
                    background: `linear-gradient(135deg, ${card.bgColor} 0%, ${card.bgColor}dd 100%)`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                    boxShadow: `0 4px 12px ${card.iconColor}30`
                  }}>
                    <Icon size={28} color={card.iconColor} strokeWidth={2} />
                  </div>
                </div>
              </div>
            </Link>
          )
        })}
      </div>

      {/* Quick Actions */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '32px',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
        border: '1px solid rgba(255, 255, 255, 0.2)'
      }}>
        <h2 style={{
          fontSize: '24px',
          fontWeight: '700',
          color: '#1e293b',
          marginBottom: '20px',
          display: 'flex',
          alignItems: 'center',
          gap: '12px'
        }}>
          <TrendingUp size={28} color="#6366f1" />
          Platform Statistics
        </h2>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(min(200px, 100%), 1fr))',
          gap: '20px'
        }}>
          <div style={{ padding: '16px', background: '#f8fafc', borderRadius: '12px' }}>
            <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
              Active Users
            </div>
            <div style={{ fontSize: '28px', fontWeight: '800', color: '#1e293b' }}>
              {stats.totalUsers + stats.totalOwners}
            </div>
          </div>
          <div style={{ padding: '16px', background: '#f8fafc', borderRadius: '12px' }}>
            <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
              Unread Notifications
            </div>
            <div style={{ fontSize: '28px', fontWeight: '800', color: '#1e293b' }}>
              {stats.totalNotifications}
            </div>
          </div>
          <div style={{ padding: '16px', background: '#f8fafc', borderRadius: '12px' }}>
            <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
              Active Collaborations
            </div>
            <div style={{ fontSize: '28px', fontWeight: '800', color: '#1e293b' }}>
              {stats.totalCollaborations}
            </div>
          </div>
          <div style={{ padding: '16px', background: '#f8fafc', borderRadius: '12px' }}>
            <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
              Average Rating
            </div>
            <div style={{ fontSize: '28px', fontWeight: '800', color: '#1e293b' }}>
              {stats.averageRating}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Dashboard

