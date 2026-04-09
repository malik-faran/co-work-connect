import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Bell, RefreshCw, Search, Trash2, CheckCircle } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const Notifications = () => {
  const [notifications, setNotifications] = useState([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [filter, setFilter] = useState('all') // all, read, unread
  const [deletingId, setDeletingId] = useState(null)

  useEffect(() => {
    fetchNotifications()
  }, [filter])

  const fetchNotifications = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('notifications')
        .select(`
          *,
          users(name, email)
        `)
        .order('created_at', { ascending: false })

      if (filter === 'read') {
        query = query.eq('is_read', true)
      } else if (filter === 'unread') {
        query = query.eq('is_read', false)
      }

      const { data, error } = await query

      if (error) throw error
      setNotifications(data || [])
    } catch (error) {
      console.error('Error fetching notifications:', error)
      showError('Failed to load notifications: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteNotification = async (notifId) => {
    if (!confirm('Are you sure you want to delete this notification?')) {
      return
    }

    try {
      setDeletingId(notifId)
      const { error } = await supabase
        .from('notifications')
        .delete()
        .eq('id', notifId)

      if (error) throw error

      showSuccess('Notification deleted successfully')
      fetchNotifications()
    } catch (error) {
      console.error('Error deleting notification:', error)
      showError('Failed to delete notification: ' + error.message)
    } finally {
      setDeletingId(null)
    }
  }

  const handleMarkAsRead = async (notifId) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ 
          is_read: true,
          read_at: new Date().toISOString()
        })
        .eq('id', notifId)

      if (error) throw error

      fetchNotifications()
    } catch (error) {
      console.error('Error marking as read:', error)
      showError('Failed to update notification: ' + error.message)
    }
  }

  const getTypeColor = (type) => {
    switch (type) {
      case 'registration_approved': return '#10b981'
      case 'registration_rejected': return '#ef4444'
      case 'collaboration_response': return '#3b82f6'
      case 'chat_message': return '#8b5cf6'
      case 'booking_confirmed': return '#10b981'
      case 'booking_cancelled': return '#ef4444'
      default: return '#6b7280'
    }
  }

  const filteredNotifications = notifications.filter(notif => {
    if (!searchQuery) return true
    const query = searchQuery.toLowerCase()
    return (
      notif.title?.toLowerCase().includes(query) ||
      notif.message?.toLowerCase().includes(query) ||
      notif.users?.name?.toLowerCase().includes(query) ||
      notif.type?.toLowerCase().includes(query)
    )
  })

  if (loading) {
    return <Loading message="Loading notifications..." />
  }

  return (
    <div className="fade-in">
      {/* Header */}
      <div style={{ 
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '32px',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
        border: '1px solid rgba(255, 255, 255, 0.2)',
        marginBottom: '32px',
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        flexWrap: 'wrap',
        gap: '20px'
      }}>
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
            Notifications
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Monitor and manage all system notifications
          </p>
        </div>
        
        <div style={{ 
          display: 'flex', 
          gap: '12px',
          alignItems: 'center'
        }}>
          <button
            onClick={fetchNotifications}
            style={{
              padding: '12px 20px',
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white',
              border: 'none',
              borderRadius: '12px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              boxShadow: '0 4px 12px rgba(99, 102, 241, 0.3)',
              transition: 'all 0.3s'
            }}
            onMouseEnter={(e) => {
              e.target.style.transform = 'translateY(-2px)'
              e.target.style.boxShadow = '0 6px 16px rgba(99, 102, 241, 0.4)'
            }}
            onMouseLeave={(e) => {
              e.target.style.transform = 'translateY(0)'
              e.target.style.boxShadow = '0 4px 12px rgba(99, 102, 241, 0.3)'
            }}
          >
            <RefreshCw size={18} />
            Refresh
          </button>
        </div>
      </div>

      {/* Filters */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '24px',
        borderRadius: '16px',
        marginBottom: '24px',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
        border: '1px solid rgba(255, 255, 255, 0.2)',
        display: 'flex',
        gap: '16px',
        flexWrap: 'wrap',
        alignItems: 'center'
      }}>
        {/* Search */}
        <div style={{ position: 'relative', flex: '1', minWidth: '250px' }}>
          <Search 
            size={18} 
            style={{
              position: 'absolute',
              left: '12px',
              top: '50%',
              transform: 'translateY(-50%)',
              color: '#94a3b8'
            }}
          />
          <input
            type="text"
            placeholder="Search by title, message, user, or type..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{
              width: '100%',
              padding: '10px 12px 10px 40px',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              fontSize: '14px',
              outline: 'none',
              transition: 'border-color 0.2s'
            }}
            onFocus={(e) => e.target.style.borderColor = '#3b82f6'}
            onBlur={(e) => e.target.style.borderColor = '#e2e8f0'}
          />
        </div>

        {/* Read/Unread Filter */}
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          style={{
            padding: '10px 16px',
            border: '1px solid #e2e8f0',
            borderRadius: '8px',
            fontSize: '14px',
            backgroundColor: 'white',
            cursor: 'pointer',
            outline: 'none',
            minWidth: '150px',
            transition: 'border-color 0.2s'
          }}
          onFocus={(e) => e.target.style.borderColor = '#3b82f6'}
          onBlur={(e) => e.target.style.borderColor = '#e2e8f0'}
        >
          <option value="all">All Notifications</option>
          <option value="unread">Unread</option>
          <option value="read">Read</option>
        </select>

        {/* Count */}
        <div style={{
          padding: '8px 16px',
          backgroundColor: '#f1f5f9',
          borderRadius: '8px',
          fontSize: '14px',
          color: '#475569',
          fontWeight: '500'
        }}>
          {filteredNotifications.length} {filteredNotifications.length === 1 ? 'notification' : 'notifications'}
        </div>
      </div>

      {/* Notifications List */}
      {filteredNotifications.length === 0 ? (
        <EmptyState
          icon={Bell}
          title={searchQuery ? "No notifications found" : "No notifications yet"}
          message={searchQuery ? "Try adjusting your search or filter" : "Notifications will appear here"}
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {filteredNotifications.map((notif) => (
            <div
              key={notif.id}
              style={{
                background: notif.is_read 
                  ? 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)'
                  : 'linear-gradient(135deg, rgba(99, 102, 241, 0.05) 0%, rgba(139, 92, 246, 0.05) 100%)',
                backdropFilter: 'blur(10px)',
                padding: '24px',
                borderRadius: '16px',
                boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
                border: `2px solid ${notif.is_read ? 'rgba(255, 255, 255, 0.2)' : getTypeColor(notif.type)}40`,
                borderLeft: `4px solid ${getTypeColor(notif.type)}`,
                transition: 'all 0.3s',
                opacity: notif.is_read ? 0.8 : 1
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)'
                e.currentTarget.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.12)'
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)'
                e.currentTarget.style.boxShadow = '0 4px 20px rgba(0, 0, 0, 0.08)'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', gap: '20px' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px', flexWrap: 'wrap' }}>
                    <h3 style={{ 
                      fontSize: '18px', 
                      fontWeight: notif.is_read ? '500' : '700', 
                      color: '#1e293b' 
                    }}>
                      {notif.title}
                    </h3>
                    {!notif.is_read && (
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        fontSize: '10px',
                        fontWeight: '700',
                        backgroundColor: '#ef4444',
                        color: 'white',
                        textTransform: 'uppercase',
                        letterSpacing: '0.5px'
                      }}>
                        New
                      </span>
                    )}
                    <span style={{
                      padding: '4px 10px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: '600',
                      backgroundColor: getTypeColor(notif.type) + '20',
                      color: getTypeColor(notif.type),
                      textTransform: 'capitalize'
                    }}>
                      {notif.type?.replaceAll('_', ' ')}
                    </span>
                  </div>

                  <p style={{ 
                    color: '#64748b', 
                    marginBottom: '12px',
                    fontSize: '14px',
                    lineHeight: '1.6'
                  }}>
                    {notif.message}
                  </p>

                  <div style={{ 
                    fontSize: '12px', 
                    color: '#94a3b8',
                    paddingTop: '12px',
                    borderTop: '1px solid #f1f5f9',
                    display: 'flex',
                    gap: '16px',
                    flexWrap: 'wrap'
                  }}>
                    <span>User: <strong>{notif.users?.name || 'System'}</strong></span>
                    <span>•</span>
                    <span>{format(new Date(notif.created_at), 'MMM dd, yyyy • hh:mm a')}</span>
                    {notif.read_at && (
                      <>
                        <span>•</span>
                        <span>Read: {format(new Date(notif.read_at), 'MMM dd, yyyy • hh:mm a')}</span>
                      </>
                    )}
                  </div>
                </div>

                <div style={{ 
                  display: 'flex', 
                  gap: '8px',
                  flexShrink: 0,
                  flexDirection: 'column'
                }}>
                  {!notif.is_read && (
                    <button
                      onClick={() => handleMarkAsRead(notif.id)}
                      style={{
                        padding: '8px 16px',
                        background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                        color: 'white',
                        border: 'none',
                        borderRadius: '8px',
                        cursor: 'pointer',
                        fontSize: '12px',
                        fontWeight: '600',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '6px',
                        transition: 'all 0.3s',
                        whiteSpace: 'nowrap'
                      }}
                    >
                      <CheckCircle size={14} />
                      Mark Read
                    </button>
                  )}
                  <button
                    onClick={() => handleDeleteNotification(notif.id)}
                    disabled={deletingId === notif.id}
                    style={{
                      padding: '8px 16px',
                      background: deletingId === notif.id 
                        ? 'linear-gradient(135deg, #94a3b8 0%, #64748b 100%)' 
                        : 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '8px',
                      cursor: deletingId === notif.id ? 'not-allowed' : 'pointer',
                      fontSize: '12px',
                      fontWeight: '600',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      transition: 'all 0.3s',
                      whiteSpace: 'nowrap'
                    }}
                  >
                    <Trash2 size={14} />
                    {deletingId === notif.id ? 'Deleting...' : 'Delete'}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default Notifications
