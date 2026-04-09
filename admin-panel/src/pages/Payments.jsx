import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { CreditCard, RefreshCw, Search, Eye, CheckCircle, XCircle, Clock } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const Payments = () => {
  const [payments, setPayments] = useState([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [filter, setFilter] = useState('all') // all, pending, completed, failed, expired
  const [selectedPayment, setSelectedPayment] = useState(null)

  useEffect(() => {
    fetchPayments()
  }, [filter])

  const fetchPayments = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('payments')
        .select(`
          *,
          bookings(id, workspace_name, total_price, start_date, end_date),
          users(name, email)
        `)
        .order('created_at', { ascending: false })

      if (filter !== 'all') {
        query = query.eq('status', filter)
      }

      const { data, error } = await query

      if (error) throw error
      setPayments(data || [])
    } catch (error) {
      console.error('Error fetching payments:', error)
      showError('Failed to load payments: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const getStatusColor = (status) => {
    switch (status) {
      case 'completed': return '#10b981'
      case 'pending': return '#f59e0b'
      case 'processing': return '#3b82f6'
      case 'failed': return '#ef4444'
      case 'expired': return '#6b7280'
      case 'cancelled': return '#ef4444'
      default: return '#6b7280'
    }
  }

  const getStatusIcon = (status) => {
    switch (status) {
      case 'completed': return CheckCircle
      case 'pending': return Clock
      case 'processing': return Clock
      case 'failed': return XCircle
      case 'expired': return XCircle
      case 'cancelled': return XCircle
      default: return Clock
    }
  }

  const filteredPayments = payments.filter(payment => {
    if (!searchQuery) return true
    const query = searchQuery.toLowerCase()
    return (
      payment.users?.name?.toLowerCase().includes(query) ||
      payment.users?.email?.toLowerCase().includes(query) ||
      payment.bookings?.workspace_name?.toLowerCase().includes(query) ||
      payment.id?.toLowerCase().includes(query)
    )
  })

  // Calculate statistics
  const stats = {
    total: payments.length,
    completed: payments.filter(p => p.status === 'completed').length,
    pending: payments.filter(p => p.status === 'pending').length,
    failed: payments.filter(p => ['failed', 'expired', 'cancelled'].includes(p.status)).length,
    totalRevenue: payments
      .filter(p => p.status === 'completed')
      .reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0)
  }

  if (loading) {
    return <Loading message="Loading payments..." />
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
            Payments
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Monitor and manage all payment transactions
          </p>
        </div>
        
        <div style={{ 
          display: 'flex', 
          gap: '12px',
          alignItems: 'center'
        }}>
          <button
            onClick={fetchPayments}
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

      {/* Statistics Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(min(200px, 100%), 1fr))',
        gap: '20px',
        marginBottom: '32px'
      }}>
        <div style={{
          background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
          padding: '24px',
          borderRadius: '16px',
          boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
          border: '1px solid rgba(255, 255, 255, 0.2)'
        }}>
          <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
            Total Payments
          </div>
          <div style={{ fontSize: '32px', fontWeight: '800', color: '#1e293b' }}>
            {stats.total}
          </div>
        </div>
        <div style={{
          background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
          padding: '24px',
          borderRadius: '16px',
          boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
          border: '1px solid rgba(255, 255, 255, 0.2)'
        }}>
          <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
            Completed
          </div>
          <div style={{ fontSize: '32px', fontWeight: '800', color: '#10b981' }}>
            {stats.completed}
          </div>
        </div>
        <div style={{
          background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
          padding: '24px',
          borderRadius: '16px',
          boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
          border: '1px solid rgba(255, 255, 255, 0.2)'
        }}>
          <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
            Pending
          </div>
          <div style={{ fontSize: '32px', fontWeight: '800', color: '#f59e0b' }}>
            {stats.pending}
          </div>
        </div>
        <div style={{
          background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
          padding: '24px',
          borderRadius: '16px',
          boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
          border: '1px solid rgba(255, 255, 255, 0.2)'
        }}>
          <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '1px' }}>
            Total Revenue
          </div>
          <div style={{ 
            fontSize: '32px', 
            fontWeight: '800',
            background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text'
          }}>
            PKR {stats.totalRevenue.toLocaleString()}
          </div>
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
            placeholder="Search by user, workspace, or payment ID..."
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

        {/* Status Filter */}
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
          <option value="all">All Status</option>
          <option value="pending">Pending</option>
          <option value="processing">Processing</option>
          <option value="completed">Completed</option>
          <option value="failed">Failed</option>
          <option value="expired">Expired</option>
          <option value="cancelled">Cancelled</option>
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
          {filteredPayments.length} {filteredPayments.length === 1 ? 'payment' : 'payments'}
        </div>
      </div>

      {/* Payments Table */}
      {filteredPayments.length === 0 ? (
        <EmptyState
          icon={CreditCard}
          title={searchQuery ? "No payments found" : "No payments yet"}
          message={searchQuery ? "Try adjusting your search or filter" : "Payments will appear here once users make transactions"}
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
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>User</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Workspace</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Amount</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Status</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Method</th>
                  <th style={{ padding: '20px 16px', textAlign: 'left', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Date</th>
                  <th style={{ padding: '20px 16px', textAlign: 'center', fontSize: '12px', fontWeight: '700', color: 'white', textTransform: 'uppercase', letterSpacing: '1px' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredPayments.map((payment, index) => {
                  const StatusIcon = getStatusIcon(payment.status)
                  return (
                    <tr 
                      key={payment.id} 
                      style={{ 
                        borderBottom: index < filteredPayments.length - 1 ? '1px solid rgba(0, 0, 0, 0.05)' : 'none',
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
                        {payment.users?.name || 'N/A'}
                      </td>
                      <td style={{ padding: '16px', fontSize: '14px', color: '#64748b' }}>
                        {payment.bookings?.workspace_name || 'N/A'}
                      </td>
                      <td style={{ padding: '16px', fontSize: '14px', color: '#1e293b', fontWeight: '600' }}>
                        {payment.currency} {parseFloat(payment.amount).toFixed(2)}
                      </td>
                      <td style={{ padding: '16px' }}>
                        <span style={{
                          padding: '6px 12px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: '600',
                          backgroundColor: getStatusColor(payment.status) + '20',
                          color: getStatusColor(payment.status),
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '6px'
                        }}>
                          <StatusIcon size={14} />
                          {payment.status.charAt(0).toUpperCase() + payment.status.slice(1)}
                        </span>
                      </td>
                      <td style={{ padding: '16px', fontSize: '14px', color: '#64748b', textTransform: 'capitalize' }}>
                        {payment.payment_method?.replace('_', ' ') || 'N/A'}
                      </td>
                      <td style={{ padding: '16px', fontSize: '14px', color: '#64748b' }}>
                        {format(new Date(payment.created_at), 'MMM dd, yyyy • hh:mm a')}
                      </td>
                      <td style={{ padding: '16px', textAlign: 'center' }}>
                        <button
                          onClick={() => setSelectedPayment(selectedPayment?.id === payment.id ? null : payment)}
                          style={{
                            padding: '8px 16px',
                            background: 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)',
                            color: 'white',
                            border: 'none',
                            borderRadius: '8px',
                            cursor: 'pointer',
                            fontSize: '12px',
                            fontWeight: '600',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '6px'
                          }}
                        >
                          <Eye size={14} />
                          {selectedPayment?.id === payment.id ? 'Hide' : 'View'}
                        </button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Payment Details Modal */}
      {selectedPayment && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px'
        }}
        onClick={() => setSelectedPayment(null)}
        >
          <div style={{
            background: 'white',
            borderRadius: '20px',
            padding: '32px',
            maxWidth: '600px',
            width: '100%',
            maxHeight: '80vh',
            overflowY: 'auto',
            boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)'
          }}
          onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ fontSize: '24px', fontWeight: '700', color: '#1e293b' }}>Payment Details</h2>
              <button
                onClick={() => setSelectedPayment(null)}
                style={{
                  background: '#f1f5f9',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '8px',
                  cursor: 'pointer'
                }}
              >
                ✕
              </button>
            </div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Payment ID</div>
                <div style={{ fontSize: '14px', fontWeight: '600', color: '#1e293b' }}>{selectedPayment.id}</div>
              </div>
              <div>
                <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Amount</div>
                <div style={{ fontSize: '18px', fontWeight: '700', color: '#1e293b' }}>
                  {selectedPayment.currency} {parseFloat(selectedPayment.amount).toFixed(2)}
                </div>
              </div>
              <div>
                <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Status</div>
                <span style={{
                  padding: '6px 12px',
                  borderRadius: '6px',
                  fontSize: '12px',
                  fontWeight: '600',
                  backgroundColor: getStatusColor(selectedPayment.status) + '20',
                  color: getStatusColor(selectedPayment.status),
                  display: 'inline-block'
                }}>
                  {selectedPayment.status.charAt(0).toUpperCase() + selectedPayment.status.slice(1)}
                </span>
              </div>
              {selectedPayment.failure_reason && (
                <div>
                  <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Failure Reason</div>
                  <div style={{ fontSize: '14px', color: '#ef4444' }}>{selectedPayment.failure_reason}</div>
                </div>
              )}
              {selectedPayment.stripe_payment_intent_id && (
                <div>
                  <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Stripe Payment Intent</div>
                  <div style={{ fontSize: '12px', color: '#1e293b', fontFamily: 'monospace' }}>{selectedPayment.stripe_payment_intent_id}</div>
                </div>
              )}
              <div>
                <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Created At</div>
                <div style={{ fontSize: '14px', color: '#1e293b' }}>
                  {format(new Date(selectedPayment.created_at), 'MMM dd, yyyy • hh:mm a')}
                </div>
              </div>
              {selectedPayment.expires_at && (
                <div>
                  <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Expires At</div>
                  <div style={{ fontSize: '14px', color: '#1e293b' }}>
                    {format(new Date(selectedPayment.expires_at), 'MMM dd, yyyy • hh:mm a')}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default Payments
