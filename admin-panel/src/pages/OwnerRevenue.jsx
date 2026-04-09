import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { DollarSign, Building2, TrendingUp, RefreshCw } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showError } from '../utils/toast'

const OwnerRevenue = () => {
  const [ownerRevenues, setOwnerRevenues] = useState([])
  const [loading, setLoading] = useState(true)
  const [sortBy, setSortBy] = useState('revenue') // 'revenue' or 'name'

  useEffect(() => {
    fetchOwnerRevenues()
  }, [sortBy])

  const fetchOwnerRevenues = async () => {
    try {
      setLoading(true)
      
      // Get all owners
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

      // Get all workspaces for these owners
      const ownerIds = owners.map(o => o.id)
      const { data: workspaces, error: workspacesError } = await supabase
        .from('workspaces')
        .select('id, owner_id, name')
        .in('owner_id', ownerIds)

      if (workspacesError) throw workspacesError

      // Create a map of owner_id to workspace_ids
      const ownerWorkspaceMap = {}
      workspaces?.forEach(ws => {
        if (!ownerWorkspaceMap[ws.owner_id]) {
          ownerWorkspaceMap[ws.owner_id] = []
        }
        ownerWorkspaceMap[ws.owner_id].push(ws.id)
      })

      // Calculate revenue for each owner
      const revenues = await Promise.all(
        owners.map(async (owner) => {
          const workspaceIds = ownerWorkspaceMap[owner.id] || []
          
          if (workspaceIds.length === 0) {
            return {
              ownerId: owner.id,
              ownerName: owner.name,
              ownerEmail: owner.email,
              workspaceCount: 0,
              totalRevenue: 0,
              bookingCount: 0
            }
          }

          // Get all bookings for this owner's workspaces
          const { data: bookings, error: bookingsError } = await supabase
            .from('bookings')
            .select('total_price, status')
            .in('workspace_id', workspaceIds)
            .in('status', ['confirmed', 'completed'])

          if (bookingsError) throw bookingsError

          const totalRevenue = bookings?.reduce((sum, booking) => {
            return sum + (parseFloat(booking.total_price) || 0)
          }, 0) || 0

          const bookingCount = bookings?.length || 0

          return {
            ownerId: owner.id,
            ownerName: owner.name,
            ownerEmail: owner.email,
            workspaceCount: workspaceIds.length,
            totalRevenue: totalRevenue,
            bookingCount: bookingCount
          }
        })
      )

      // Sort by revenue or name
      revenues.sort((a, b) => {
        if (sortBy === 'revenue') {
          return b.totalRevenue - a.totalRevenue
        } else {
          return a.ownerName.localeCompare(b.ownerName)
        }
      })

      setOwnerRevenues(revenues)
    } catch (error) {
      console.error('Error fetching owner revenues:', error)
      showError('Failed to load owner revenues: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return <Loading message="Loading owner revenues..." />
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
            Owner Revenue Report
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            View revenue breakdown by owner
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
                  Total Revenue
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
                Average Revenue
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

