import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { Check, X, Mail, Phone, Building, RefreshCw } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const OwnerRequests = () => {
  const [requests, setRequests] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchOwnerRequests()
  }, [])

  const fetchOwnerRequests = async () => {
    try {
      // Fetch owners where owner_approved is null (pending approval)
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('role', 'owner')
        .is('owner_approved', null)
        .order('created_at', { ascending: false })

      if (error) {
        console.error('Supabase error:', error)
        // Check if it's a column missing error
        if (error.message && error.message.includes('column') && error.message.includes('owner_approved')) {
          alert('Database Error: owner_approved column is missing. Please add it to the users table.')
        } else {
          throw error
        }
      }
      setRequests(data || [])
    } catch (error) {
      console.error('Error fetching owner requests:', error)
      showError('Error loading owner requests: ' + (error.message || 'Unknown error'))
    } finally {
      setLoading(false)
    }
  }

  const handleApprove = async (userId, userName) => {
    try {
      const { error } = await supabase
        .from('users')
        .update({ owner_approved: true })
        .eq('id', userId)

      if (error) throw error

      showSuccess(`Owner "${userName}" approved successfully!`)
      fetchOwnerRequests()
    } catch (error) {
      console.error('Error approving owner:', error)
      showError('Error approving owner: ' + error.message)
    }
  }

  const handleReject = async (userId, userName) => {
    if (!confirm(`Are you sure you want to reject "${userName}"'s owner request?\n\nThey will be converted back to a regular user.`)) {
      return
    }

    try {
      const { error } = await supabase
        .from('users')
        .update({ owner_approved: false, role: 'user' })
        .eq('id', userId)

      if (error) throw error

      showSuccess(`Owner request for "${userName}" rejected`)
      fetchOwnerRequests()
    } catch (error) {
      console.error('Error rejecting owner:', error)
      showError('Error rejecting owner: ' + error.message)
    }
  }

  if (loading) {
    return <Loading message="Loading owner requests..." />
  }

  return (
    <div className="fade-in">
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
            Owner Requests
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Review and approve owner registration requests
          </p>
        </div>
        <button
          onClick={fetchOwnerRequests}
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

      {requests.length === 0 ? (
        <EmptyState
          icon={Building}
          title="No pending requests"
          message="All owner requests have been processed"
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {requests.map((request) => (
            <div
              key={request.id}
              className="card-hover"
              style={{
                background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
                backdropFilter: 'blur(10px)',
                padding: '28px',
                borderRadius: '20px',
                boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                position: 'relative',
                overflow: 'hidden'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-6px) scale(1.01)'
                e.currentTarget.style.boxShadow = '0 12px 40px rgba(0, 0, 0, 0.15)'
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0) scale(1)'
                e.currentTarget.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.1)'
              }}
            >
              <div style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                height: '4px',
                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                borderRadius: '20px 20px 0 0'
              }} />
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', gap: '20px' }}>
                <div style={{ flex: 1 }}>
                  <h3 style={{ 
                    fontSize: '20px', 
                    fontWeight: '600', 
                    marginBottom: '16px', 
                    color: '#1e293b' 
                  }}>
                    {request.name}
                  </h3>
                  
                  <div style={{ 
                    display: 'flex', 
                    flexDirection: 'column', 
                    gap: '12px', 
                    marginBottom: '16px' 
                  }}>
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '10px', 
                      color: '#64748b',
                      fontSize: '14px'
                    }}>
                      <Mail size={18} color="#94a3b8" />
                      <span>{request.email}</span>
                    </div>
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '10px', 
                      color: '#64748b',
                      fontSize: '14px'
                    }}>
                      <Phone size={18} color="#94a3b8" />
                      <span>{request.phone}</span>
                    </div>
                    {request.business_name && (
                      <div style={{ 
                        display: 'flex', 
                        alignItems: 'center', 
                        gap: '10px', 
                        color: '#64748b',
                        fontSize: '14px'
                      }}>
                        <Building size={18} color="#94a3b8" />
                        <span style={{ fontWeight: '500' }}>{request.business_name}</span>
                      </div>
                    )}
                    {request.business_address && (
                      <div style={{ 
                        color: '#64748b', 
                        marginLeft: '28px', 
                        fontSize: '13px',
                        fontStyle: 'italic'
                      }}>
                        {request.business_address}
                      </div>
                    )}
                    {request.city && (
                      <div style={{ 
                        color: '#64748b', 
                        marginLeft: '28px', 
                        fontSize: '13px'
                      }}>
                        📍 {request.city}
                      </div>
                    )}
                  </div>

                  <div style={{ 
                    fontSize: '12px', 
                    color: '#94a3b8',
                    paddingTop: '12px',
                    borderTop: '1px solid #f1f5f9'
                  }}>
                    Requested on: {new Date(request.created_at).toLocaleDateString('en-US', { 
                      year: 'numeric', 
                      month: 'long', 
                      day: 'numeric' 
                    })}
                  </div>
                </div>

                <div style={{ 
                  display: 'flex', 
                  gap: '10px',
                  flexShrink: 0
                }}>
                  <button
                    onClick={() => handleApprove(request.id, request.name)}
                    style={{
                      padding: '12px 24px',
                      background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '12px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '10px',
                      fontSize: '14px',
                      fontWeight: '700',
                      transition: 'all 0.3s',
                      boxShadow: '0 4px 12px rgba(16, 185, 129, 0.3)'
                    }}
                    onMouseEnter={(e) => {
                      e.target.style.transform = 'translateY(-2px) scale(1.05)'
                      e.target.style.boxShadow = '0 6px 16px rgba(16, 185, 129, 0.4)'
                    }}
                    onMouseLeave={(e) => {
                      e.target.style.transform = 'translateY(0) scale(1)'
                      e.target.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.3)'
                    }}
                  >
                    <Check size={18} />
                    Approve
                  </button>
                  <button
                    onClick={() => handleReject(request.id, request.name)}
                    style={{
                      padding: '12px 24px',
                      background: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '12px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '10px',
                      fontSize: '14px',
                      fontWeight: '700',
                      transition: 'all 0.3s',
                      boxShadow: '0 4px 12px rgba(239, 68, 68, 0.3)'
                    }}
                    onMouseEnter={(e) => {
                      e.target.style.transform = 'translateY(-2px) scale(1.05)'
                      e.target.style.boxShadow = '0 6px 16px rgba(239, 68, 68, 0.4)'
                    }}
                    onMouseLeave={(e) => {
                      e.target.style.transform = 'translateY(0) scale(1)'
                      e.target.style.boxShadow = '0 4px 12px rgba(239, 68, 68, 0.3)'
                    }}
                  >
                    <X size={18} />
                    Reject
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

export default OwnerRequests

