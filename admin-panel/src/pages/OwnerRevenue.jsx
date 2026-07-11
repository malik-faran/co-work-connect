import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { DollarSign, Building2, TrendingUp, RefreshCw, Percent } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showError } from '../utils/toast'

const OwnerRevenue = () => {
  const [ownerRevenues, setOwnerRevenues] = useState([])
  const [platformStats, setPlatformStats] = useState({
    platformRevenue: 0,
    transactionVolume: 0,
    bookingFees: 0,
    collabFees: 0,
    bookingGmv: 0,
    collabGmv: 0,
    feePercent: 5,
  })
  const [loading, setLoading] = useState(true)
  const [sortBy, setSortBy] = useState('revenue') // 'revenue' or 'name'

  useEffect(() => {
    fetchOwnerRevenues()
  }, [sortBy])

  const fetchOwnerRevenues = async () => {
    try {
      setLoading(true)

      const { data: feeSetting } = await supabase
        .from('platform_settings')
        .select('value')
        .eq('key', 'platform_fee_percent')
        .maybeSingle()
      const feePercent = parseFloat(feeSetting?.value) || 5

      const { data: completedPayments, error: payErr } = await supabase
        .from('payments')
        .select('id, amount, platform_fee_amount, owner_earning_amount, booking_id')
        .eq('status', 'completed')
        .eq('owner_earning_credited', true)

      if (payErr) throw payErr

      const { data: collabPayments, error: collabErr } = await supabase
        .from('collaboration_payments')
        .select('amount, platform_fee_amount')
        .eq('status', 'released')

      if (collabErr) throw collabErr

      const bookingGmv = (completedPayments || []).reduce((s, p) => s + (parseFloat(p.amount) || 0), 0)
      const bookingFees = (completedPayments || []).reduce((s, p) => s + (parseFloat(p.platform_fee_amount) || 0), 0)
      const collabGmv = (collabPayments || []).reduce((s, p) => s + (parseFloat(p.amount) || 0), 0)
      const collabFees = (collabPayments || []).reduce((s, p) => s + (parseFloat(p.platform_fee_amount) || 0), 0)

      setPlatformStats({
        platformRevenue: bookingFees + collabFees,
        transactionVolume: bookingGmv + collabGmv,
        bookingFees,
        collabFees,
        bookingGmv,
        collabGmv,
        feePercent,
      })

      const { data: owners, error: ownersError } = await supabase
        .from('users')
        .select('id, name, email')
        .eq('role', 'owner')
        .eq('owner_approved', true)

      if (ownersError) throw ownersError

      if (!owners || owners.length === 0) {
        setOwnerRevenues([])
        setLoading(false)
        return
      }

      const bookingIds = [...new Set((completedPayments || []).map((p) => p.booking_id).filter(Boolean))]
      let bookingOwnerMap = {}

      if (bookingIds.length) {
        const { data: bookings, error: bookingsError } = await supabase
          .from('bookings')
          .select('id, workspace_id')
          .in('id', bookingIds)

        if (bookingsError) throw bookingsError

        const workspaceIds = [...new Set((bookings || []).map((b) => b.workspace_id).filter(Boolean))]
        const { data: workspaces, error: wsError } = workspaceIds.length
          ? await supabase.from('workspaces').select('id, owner_id, name').in('id', workspaceIds)
          : { data: [], error: null }

        if (wsError) throw wsError

        const wsMap = Object.fromEntries((workspaces || []).map((w) => [w.id, w]))
        bookingOwnerMap = Object.fromEntries(
          (bookings || []).map((b) => [b.id, wsMap[b.workspace_id]?.owner_id])
        )
      }

      const ownerEarnings = {}
      const ownerBookingCounts = {}
      const ownerWorkspaceIds = {}

      for (const p of completedPayments || []) {
        const ownerId = bookingOwnerMap[p.booking_id]
        if (!ownerId) continue
        ownerEarnings[ownerId] = (ownerEarnings[ownerId] || 0) + (parseFloat(p.owner_earning_amount) || 0)
        ownerBookingCounts[ownerId] = (ownerBookingCounts[ownerId] || 0) + 1
      }

      const { data: workspaces, error: workspacesError } = await supabase
        .from('workspaces')
        .select('id, owner_id, name')
        .in('owner_id', owners.map((o) => o.id))

      if (workspacesError) throw workspacesError

      workspaces?.forEach((ws) => {
        if (!ownerWorkspaceIds[ws.owner_id]) ownerWorkspaceIds[ws.owner_id] = []
        ownerWorkspaceIds[ws.owner_id].push(ws.id)
      })

      const revenues = owners.map((owner) => ({
        ownerId: owner.id,
        ownerName: owner.name,
        ownerEmail: owner.email,
        workspaceCount: ownerWorkspaceIds[owner.id]?.length || 0,
        totalRevenue: ownerEarnings[owner.id] || 0,
        bookingCount: ownerBookingCounts[owner.id] || 0,
      }))

      revenues.sort((a, b) => {
        if (sortBy === 'revenue') return b.totalRevenue - a.totalRevenue
        return a.ownerName.localeCompare(b.ownerName)
      })

      setOwnerRevenues(revenues)
    } catch (error) {
      console.error('Error fetching platform revenue:', error)
      showError('Failed to load platform revenue: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return <Loading message="Loading platform revenue..." />
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
            Platform Revenue
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Platform fee ({platformStats.feePercent}%) is separate from gross transaction volume. Top-ups have no fee.
          </p>
        </div>
        
        <div style={{ 
          display: 'flex', 
          gap: '12px',
          alignItems: 'center'
        }}>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            style={{
              padding: '12px 20px',
              border: '1px solid #e2e8f0',
              borderRadius: '12px',
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
            <option value="revenue">Sort by Revenue</option>
            <option value="name">Sort by Name</option>
          </select>
          
          <button
            onClick={fetchOwnerRevenues}
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

      {/* Platform summary — fee vs volume */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '16px',
        marginBottom: '28px',
      }}>
        {[
          { label: 'Platform Revenue', value: platformStats.platformRevenue, icon: Percent, color: '#10b981', sub: `${platformStats.feePercent}% fee collected` },
          { label: 'Transaction Volume', value: platformStats.transactionVolume, icon: TrendingUp, color: '#3b82f6', sub: 'Gross paid (bookings + collab)' },
          { label: 'Booking Fees', value: platformStats.bookingFees, icon: DollarSign, color: '#8b5cf6', sub: `GMV PKR ${platformStats.bookingGmv.toLocaleString()}` },
          { label: 'Collaboration Fees', value: platformStats.collabFees, icon: DollarSign, color: '#f59e0b', sub: `GMV PKR ${platformStats.collabGmv.toLocaleString()}` },
        ].map((card) => (
          <div key={card.label} style={{
            background: 'white',
            padding: '20px',
            borderRadius: '16px',
            border: '1px solid #e2e8f0',
            boxShadow: '0 2px 12px rgba(0,0,0,0.04)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <card.icon size={20} color={card.color} />
              <span style={{ fontSize: 13, color: '#64748b', fontWeight: 600 }}>{card.label}</span>
            </div>
            <div style={{ fontSize: 26, fontWeight: 800, color: '#1e293b' }}>
              PKR {card.value.toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
            <div style={{ fontSize: 12, color: '#94a3b8', marginTop: 6 }}>{card.sub}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 16, color: '#1e293b' }}>
        Owner wallet credits (after {platformStats.feePercent}% fee)
      </h2>

      {/* Revenue Cards */}
      {ownerRevenues.length === 0 ? (
        <EmptyState
          icon={DollarSign}
          title="No owner revenue data"
          message="Revenue data will appear here once owners have confirmed bookings"
        />
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(min(350px, 100%), 1fr))',
          gap: '24px',
          marginBottom: '32px'
        }}>
          {ownerRevenues.map((owner) => (
            <div
              key={owner.ownerId}
              className="card-hover"
              style={{
                background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
                backdropFilter: 'blur(10px)',
                padding: '28px',
                borderRadius: '20px',
                boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                position: 'relative',
                overflow: 'hidden',
                transition: 'all 0.3s'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-6px) scale(1.02)'
                e.currentTarget.style.boxShadow = '0 12px 40px rgba(0, 0, 0, 0.15)'
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0) scale(1)'
                e.currentTarget.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.1)'
              }}
            >
              {/* Gradient Accent */}
              <div style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                height: '4px',
                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                borderRadius: '20px 20px 0 0'
              }} />
              
              <div style={{ marginBottom: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
                  <div style={{
                    width: '48px',
                    height: '48px',
                    borderRadius: '12px',
                    background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: '0 4px 12px rgba(16, 185, 129, 0.3)'
                  }}>
                    <Building2 size={24} color="white" />
                  </div>
                  <div style={{ flex: 1 }}>
                    <h3 style={{
                      fontSize: '18px',
                      fontWeight: '700',
                      color: '#1e293b',
                      marginBottom: '4px'
                    }}>
                      {owner.ownerName}
                    </h3>
                    <p style={{
                      fontSize: '13px',
                      color: '#64748b'
                    }}>
                      {owner.ownerEmail}
                    </p>
                  </div>
                </div>
              </div>

              <div style={{
                padding: '16px',
                background: 'rgba(16, 185, 129, 0.05)',
                borderRadius: '12px',
                marginBottom: '16px'
              }}>
                <div style={{
                  fontSize: '32px',
                  fontWeight: '800',
                  background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                  marginBottom: '8px'
                }}>
                  PKR {owner.totalRevenue.toLocaleString()}
                </div>
                <div style={{
                  fontSize: '12px',
                  color: '#64748b',
                  textTransform: 'uppercase',
                  letterSpacing: '1px',
                  fontWeight: '600'
                }}>
                  Net Credited
                </div>
              </div>

              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                gap: '12px',
                fontSize: '13px'
              }}>
                <div style={{
                  flex: 1,
                  padding: '12px',
                  background: 'rgba(99, 102, 241, 0.05)',
                  borderRadius: '10px',
                  textAlign: 'center'
                }}>
                  <div style={{
                    fontSize: '20px',
                    fontWeight: '700',
                    color: '#6366f1',
                    marginBottom: '4px'
                  }}>
                    {owner.workspaceCount}
                  </div>
                  <div style={{
                    fontSize: '11px',
                    color: '#64748b',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px'
                  }}>
                    Workspaces
                  </div>
                </div>
                <div style={{
                  flex: 1,
                  padding: '12px',
                  background: 'rgba(139, 92, 246, 0.05)',
                  borderRadius: '10px',
                  textAlign: 'center'
                }}>
                  <div style={{
                    fontSize: '20px',
                    fontWeight: '700',
                    color: '#8b5cf6',
                    marginBottom: '4px'
                  }}>
                    {owner.bookingCount}
                  </div>
                  <div style={{
                    fontSize: '11px',
                    color: '#64748b',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px'
                  }}>
                    Bookings
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Summary Card */}
      {ownerRevenues.length > 0 && (
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
            <TrendingUp size={28} color="#10b981" />
            Summary
          </h2>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: '20px'
          }}>
            <div>
              <div style={{
                fontSize: '14px',
                color: '#64748b',
                marginBottom: '8px',
                textTransform: 'uppercase',
                letterSpacing: '1px',
                fontWeight: '600'
              }}>
                Total Owners
              </div>
              <div style={{
                fontSize: '32px',
                fontWeight: '800',
                color: '#1e293b'
              }}>
                {ownerRevenues.length}
              </div>
            </div>
            <div>
              <div style={{
                fontSize: '14px',
                color: '#64748b',
                marginBottom: '8px',
                textTransform: 'uppercase',
                letterSpacing: '1px',
                fontWeight: '600'
              }}>
                Total Owner Credits
              </div>
              <div style={{
                fontSize: '32px',
                fontWeight: '800',
                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text'
              }}>
                PKR {ownerRevenues.reduce((sum, o) => sum + o.totalRevenue, 0).toLocaleString()}
              </div>
            </div>
            <div>
              <div style={{
                fontSize: '14px',
                color: '#64748b',
                marginBottom: '8px',
                textTransform: 'uppercase',
                letterSpacing: '1px',
                fontWeight: '600'
              }}>
                Average Owner Credit
              </div>
              <div style={{
                fontSize: '32px',
                fontWeight: '800',
                color: '#1e293b'
              }}>
                PKR {ownerRevenues.length > 0 
                  ? Math.round(ownerRevenues.reduce((sum, o) => sum + o.totalRevenue, 0) / ownerRevenues.length).toLocaleString()
                  : '0'}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default OwnerRevenue

