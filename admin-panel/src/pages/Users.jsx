import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Trash2, RefreshCw, Search, Users as UsersIcon } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const Users = () => {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [deletingId, setDeletingId] = useState(null)

  useEffect(() => {
    fetchUsers()
  }, [filter])

  const fetchUsers = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('users')
        .select('*')
        .order('created_at', { ascending: false })

      if (filter !== 'all') {
        if (filter === 'pending') {
          query = query.eq('admin_approved', false)
        } else {
          query = query.eq('role', filter)
        }
      }

      const { data, error } = await query

      if (error) throw error
      setUsers(data || [])
    } catch (error) {
      console.error('Error fetching users:', error)
      showError('Failed to load users: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleApproveUser = async (userId, userName) => {
    try {
      // Update user approval status
      const { error: updateError } = await supabase
        .from('users')
        .update({ admin_approved: true })
        .eq('id', userId)

      if (updateError) throw updateError

      // Create notification
      await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          title: 'Registration Approved',
          message: 'Your registration has been approved. You can now login to your account.',
          type: 'registration_approved',
          is_read: false,
          created_at: new Date().toISOString()
        })

      showSuccess(`User "${userName}" approved successfully`)
      fetchUsers()
    } catch (error) {
      console.error('Error approving user:', error)
      showError('Failed to approve user: ' + error.message)
    }
  }

  const handleRejectUser = async (userId, userName) => {
    const reason = prompt('Please provide a reason for rejection (optional):')
    
    try {
      // Update user approval status
      const { error: updateError } = await supabase
        .from('users')
        .update({ admin_approved: false })
        .eq('id', userId)

      if (updateError) throw updateError

      // Create notification
      await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          title: 'Registration Rejected',
          message: reason || 'Your registration has been rejected. Please contact support for more information.',
          type: 'registration_rejected',
          is_read: false,
          created_at: new Date().toISOString(),
          metadata: reason ? { reason } : null
        })

      showSuccess(`User "${userName}" rejected`)
      fetchUsers()
    } catch (error) {
      console.error('Error rejecting user:', error)
      showError('Failed to reject user: ' + error.message)
    }
  }

  const handleDeleteUser = async (userId, userName) => {
    if (!confirm(`Are you sure you want to delete user "${userName}"?\n\nThis action cannot be undone and will also delete:\n- All their workspaces\n- All their bookings`)) {
      return
    }

    try {
      setDeletingId(userId)
      
      // First, delete related bookings
      await supabase
        .from('bookings')
        .delete()
        .eq('user_id', userId)

      // Then, delete related workspaces (if owner)
      await supabase
        .from('workspaces')
        .delete()
        .eq('owner_id', userId)

      // Finally, delete the user from database
      const { error } = await supabase
        .from('users')
        .delete()
        .eq('id', userId)

      if (error) throw error

      // Note: Supabase Auth user deletion requires admin API key
      // This should be handled server-side for security
      // For now, we only delete from the users table
      // The auth user will remain but won't be able to access the app
      // since their profile is deleted

      showSuccess(`User "${userName}" deleted successfully`)
      fetchUsers()
    } catch (error) {
      console.error('Error deleting user:', error)
      showError('Failed to delete user: ' + error.message)
    } finally {
      setDeletingId(null)
    }
  }

  const filteredUsers = users.filter(user => {
    if (!searchQuery) return true
    const query = searchQuery.toLowerCase()
    return (
      user.name?.toLowerCase().includes(query) ||
      user.email?.toLowerCase().includes(query) ||
      user.phone?.toLowerCase().includes(query)
    )
  })

  if (loading) {
    return <Loading message="Loading users..." />
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
            Users Management
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Manage all users and owners in the system
          </p>
        </div>
        
        <div style={{ 
          display: 'flex', 
          gap: '12px',
          alignItems: 'center'
        }}>
          <button
            onClick={fetchUsers}
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
            placeholder="Search by name, email, or phone..."
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

        {/* Role Filter */}
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
          <option value="all">All Users</option>
          <option value="pending">Pending Approval</option>
          <option value="user">Regular Users</option>
          <option value="owner">Owners</option>
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
          {filteredUsers.length} {filteredUsers.length === 1 ? 'user' : 'users'}
        </div>
      </div>

      {/* Users Table */}
      {filteredUsers.length === 0 ? (
        <EmptyState
          icon={UsersIcon}
          title={searchQuery ? "No users found" : "No users yet"}
          message={searchQuery ? "Try adjusting your search or filter" : "Users will appear here once they register"}
        />
      ) : (
        <div style={{
          background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
          backdropFilter: 'blur(10px)',
          borderRadius: '20px',
          overflow: 'hidden',
          boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
          border: '1px solid rgba(255, 255, 255, 0.2)'
        }}>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ 
                  background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                  borderBottom: 'none'
                }}>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Name</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Email</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Phone</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Role</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>CNIC</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Status</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Joined</th>
                  <th style={{ padding: '20px 16px', textAlign: 'center', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user, index) => (
                  <tr 
                    key={user.id} 
                    style={{ 
                      borderBottom: index < filteredUsers.length - 1 ? '1px solid rgba(0, 0, 0, 0.05)' : 'none',
                      transition: 'all 0.3s',
                      background: index % 2 === 0 ? 'rgba(255, 255, 255, 0.5)' : 'rgba(255, 255, 255, 0.3)'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = 'linear-gradient(135deg, rgba(102, 126, 234, 0.1) 0%, rgba(118, 75, 162, 0.1) 100%)'
                      e.currentTarget.style.transform = 'scale(1.01)'
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = index % 2 === 0 ? 'rgba(255, 255, 255, 0.5)' : 'rgba(255, 255, 255, 0.3)'
                      e.currentTarget.style.transform = 'scale(1)'
                    }}
                  >
                    <td style={{ padding: '16px', fontSize: '14px', color: '#1e293b', fontWeight: '500' }}>
                      {user.name}
                    </td>
                    <td style={{ padding: '16px', fontSize: '14px', color: '#64748b' }}>
                      {user.email}
                    </td>
                    <td style={{ padding: '16px', fontSize: '14px', color: '#64748b' }}>
                      {user.phone}
                    </td>
                    <td style={{ padding: '16px' }}>
                      <span style={{
                        padding: '8px 16px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: '700',
                        background: user.role === 'owner' 
                          ? 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)' 
                          : 'linear-gradient(135deg, #64748b 0%, #475569 100%)',
                        color: 'white',
                        display: 'inline-block',
                        boxShadow: '0 2px 8px rgba(0, 0, 0, 0.15)',
                        textTransform: 'uppercase',
                        letterSpacing: '0.5px'
                      }}>
                        {user.role === 'owner' ? '👤 Owner' : '👤 User'}
                      </span>
                    </td>
                    <td style={{ padding: '16px', fontSize: '14px', color: '#64748b' }}>
                      {user.cnic_image_url ? (
                        <a 
                          href={user.cnic_image_url} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          style={{
                            color: '#3b82f6',
                            textDecoration: 'none',
                            fontWeight: '500',
                            cursor: 'pointer'
                          }}
                          onMouseEnter={(e) => e.target.style.textDecoration = 'underline'}
                          onMouseLeave={(e) => e.target.style.textDecoration = 'none'}
                        >
                          View CNIC
                        </a>
                      ) : (
                        <span style={{ color: '#94a3b8' }}>Not uploaded</span>
                      )}
                    </td>
                    <td style={{ padding: '16px' }}>
                      <span style={{
                        padding: '8px 16px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: '600',
                        backgroundColor: user.admin_approved === false 
                          ? '#fef3c7' 
                          : user.admin_approved === true 
                          ? '#d1fae5' 
                          : '#e0e7ff',
                        color: user.admin_approved === false 
                          ? '#92400e' 
                          : user.admin_approved === true 
                          ? '#065f46' 
                          : '#3730a3'
                      }}>
                        {user.admin_approved === false 
                          ? 'Pending' 
                          : user.admin_approved === true 
                          ? 'Approved' 
                          : 'N/A'}
                      </span>
                    </td>
                    <td style={{ padding: '16px', fontSize: '14px', color: '#64748b' }}>
                      {format(new Date(user.created_at), 'MMM dd, yyyy')}
                    </td>
                    <td style={{ padding: '16px', textAlign: 'center' }}>
                      <div style={{ display: 'flex', gap: '8px', justifyContent: 'center', flexWrap: 'wrap' }}>
                        {user.admin_approved === false && (
                          <>
                            <button
                              onClick={() => handleApproveUser(user.id, user.name)}
                              style={{
                                padding: '10px 16px',
                                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                                color: 'white',
                                border: 'none',
                                borderRadius: '10px',
                                cursor: 'pointer',
                                fontSize: '13px',
                                fontWeight: '600',
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '8px',
                                transition: 'all 0.3s',
                                boxShadow: '0 4px 12px rgba(16, 185, 129, 0.3)'
                              }}
                              onMouseEnter={(e) => {
                                e.target.style.transform = 'translateY(-2px)'
                                e.target.style.boxShadow = '0 6px 16px rgba(16, 185, 129, 0.4)'
                              }}
                              onMouseLeave={(e) => {
                                e.target.style.transform = 'translateY(0)'
                                e.target.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.3)'
                              }}
                            >
                              ✓ Approve
                            </button>
                            <button
                              onClick={() => handleRejectUser(user.id, user.name)}
                              style={{
                                padding: '10px 16px',
                                background: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                                color: 'white',
                                border: 'none',
                                borderRadius: '10px',
                                cursor: 'pointer',
                                fontSize: '13px',
                                fontWeight: '600',
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '8px',
                                transition: 'all 0.3s',
                                boxShadow: '0 4px 12px rgba(239, 68, 68, 0.3)'
                              }}
                              onMouseEnter={(e) => {
                                e.target.style.transform = 'translateY(-2px)'
                                e.target.style.boxShadow = '0 6px 16px rgba(239, 68, 68, 0.4)'
                              }}
                              onMouseLeave={(e) => {
                                e.target.style.transform = 'translateY(0)'
                                e.target.style.boxShadow = '0 4px 12px rgba(239, 68, 68, 0.3)'
                              }}
                            >
                              ✗ Reject
                            </button>
                          </>
                        )}
                        <button
                          onClick={() => handleDeleteUser(user.id, user.name)}
                          disabled={deletingId === user.id}
                          style={{
                            padding: '10px 16px',
                            background: deletingId === user.id 
                              ? 'linear-gradient(135deg, #94a3b8 0%, #64748b 100%)' 
                              : 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                            color: 'white',
                            border: 'none',
                            borderRadius: '10px',
                            cursor: deletingId === user.id ? 'not-allowed' : 'pointer',
                            fontSize: '13px',
                            fontWeight: '600',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '8px',
                            transition: 'all 0.3s',
                            boxShadow: deletingId === user.id ? 'none' : '0 4px 12px rgba(239, 68, 68, 0.3)'
                          }}
                          onMouseEnter={(e) => {
                            if (deletingId !== user.id) {
                              e.target.style.transform = 'translateY(-2px)'
                              e.target.style.boxShadow = '0 6px 16px rgba(239, 68, 68, 0.4)'
                            }
                          }}
                          onMouseLeave={(e) => {
                            if (deletingId !== user.id) {
                              e.target.style.transform = 'translateY(0)'
                              e.target.style.boxShadow = '0 4px 12px rgba(239, 68, 68, 0.3)'
                            }
                          }}
                        >
                          <Trash2 size={16} />
                          {deletingId === user.id ? 'Deleting...' : 'Delete'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}

export default Users

